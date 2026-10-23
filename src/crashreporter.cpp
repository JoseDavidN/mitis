#include "crashreporter.h"

#include <QClipboard>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QMutex>
#include <QQmlEngine>
#include <QStandardPaths>
#include <QSysInfo>
#include <QUrl>

#include <cstdlib>
#include <cstring>
#include <exception>

#ifdef Q_OS_WIN
#include <windows.h>
#include <dbghelp.h>
#include <csignal>
#else
#include <csignal>
#include <dlfcn.h>
#include <execinfo.h>
#include <fcntl.h>
#include <unistd.h>
#endif

namespace {
// Líneas que marcan una sesión que terminó sin caerse
const char NormalEnd[] = "== Cierre normal ==";
const char SystemEnd[] = "== Fin de la sesión del sistema ==";
const char CrashMark[] = "== Caída";
// El registro deja de crecer (salvo la caída) pasado este tamaño
constexpr qint64 MaxLogBytes = 4 * 1024 * 1024;
// Al copiar un informe largo: el principio (versión, sistema) y el final
constexpr int CopyHeadLines = 40;
constexpr int CopyTailLines = 300;

QMutex g_mutex;
// Ya se escribió una caída: el abort() que sigue a terminate o a una llamada
// virtual pura no repite el informe
volatile sig_atomic_t g_crashed = 0;
qint64 g_written = 0;
QtMessageHandler g_previousHandler = nullptr;

// ── Escritura que vale también dentro de una caída ──────────────────
// Sin memoria dinámica ni bloqueos: el proceso puede estar roto

#ifdef Q_OS_WIN
HANDLE g_log = INVALID_HANDLE_VALUE;
wchar_t g_dumpPath[MAX_PATH] = {};

void writeRaw(const char *data, size_t size)
{
    if (g_log == INVALID_HANDLE_VALUE)
        return;
    DWORD done = 0;
    WriteFile(g_log, data, DWORD(size), &done, nullptr);
}
#else
int g_log = -1;

void writeRaw(const char *data, size_t size)
{
    while (g_log >= 0 && size > 0) {
        const ssize_t done = ::write(g_log, data, size);
        if (done <= 0)
            return;
        data += done;
        size -= size_t(done);
    }
}
#endif

void writeText(const char *text)
{
    writeRaw(text, strlen(text));
}

void writeHex(quintptr value)
{
    char buffer[2 + 2 * sizeof(quintptr)];
    char *end = buffer + sizeof(buffer);
    char *p = end;
    do {
        *--p = "0123456789abcdef"[value & 0xf];
        value >>= 4;
    } while (value);
    *--p = 'x';
    *--p = '0';
    writeRaw(p, size_t(end - p));
}

void writeDec(unsigned value)
{
    char buffer[12];
    char *end = buffer + sizeof(buffer);
    char *p = end;
    do {
        *--p = char('0' + value % 10);
        value /= 10;
    } while (value);
    writeRaw(p, size_t(end - p));
}

// «módulo+0xdesplazamiento (función)»: con los símbolos de la compilación
// (PDB, dSYM o el ejecutable sin recortar) se traduce a archivo y línea
void writeFrame(unsigned index, quintptr address)
{
    writeText("  #");
    writeDec(index);
    writeText("  ");
#ifdef Q_OS_WIN
    HMODULE module = nullptr;
    wchar_t wide[MAX_PATH];
    char name[MAX_PATH * 3];
    if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           reinterpret_cast<LPCWSTR>(address), &module)
        && GetModuleFileNameW(module, wide, MAX_PATH)) {
        const wchar_t *base = wcsrchr(wide, L'\\');
        const int size = WideCharToMultiByte(CP_UTF8, 0, base ? base + 1 : wide, -1, name, int(sizeof(name)), nullptr, nullptr);
        if (size > 1)
            writeRaw(name, size_t(size - 1));
        writeText("+");
        writeHex(address - reinterpret_cast<quintptr>(module));
    } else {
        writeHex(address);
    }
#else
    Dl_info info;
    if (dladdr(reinterpret_cast<void *>(address), &info) && info.dli_fname) {
        const char *base = strrchr(info.dli_fname, '/');
        writeText(base ? base + 1 : info.dli_fname);
        writeText("+");
        writeHex(address - reinterpret_cast<quintptr>(info.dli_fbase));
        if (info.dli_sname) {
            writeText(" (");
            writeText(info.dli_sname);
            writeText(")");
        }
    } else {
        writeHex(address);
    }
#endif
    writeText("\n");
}

void writeStack()
{
    writeText("Pila:\n");
    void *frames[64];
#ifdef Q_OS_WIN
    const unsigned count = CaptureStackBackTrace(0, 64, frames, nullptr);
#else
    const int captured = backtrace(frames, 64);
    const unsigned count = captured > 0 ? unsigned(captured) : 0;
#endif
    for (unsigned i = 0; i < count; ++i)
        writeFrame(i, reinterpret_cast<quintptr>(frames[i]));
}

void writeCrashHeader(const char *reason)
{
    g_crashed = 1;
    writeText("\n");
    writeText(CrashMark);
    writeText(": ");
    writeText(reason);
}

void writeCrashEnd()
{
    writeText("== Fin del informe ==\n");
#ifdef Q_OS_WIN
    FlushFileBuffers(g_log);
#endif
}

// ── Manejadores ──────────────────────────────────────────────────────

void onTerminate()
{
    writeCrashHeader("std::terminate");
    if (std::exception_ptr current = std::current_exception()) {
        try {
            std::rethrow_exception(current);
        } catch (const std::exception &e) {
            writeText(" (excepción: ");
            writeText(e.what());
            writeText(")");
        } catch (...) {
            writeText(" (excepción desconocida)");
        }
    }
    writeText("\n");
    writeStack();
    writeCrashEnd();
    std::abort();
}

#ifdef Q_OS_WIN
const char *exceptionName(DWORD code)
{
    switch (code) {
    case EXCEPTION_ACCESS_VIOLATION: return "acceso a memoria no válida";
    case EXCEPTION_STACK_OVERFLOW: return "desbordamiento de la pila";
    case EXCEPTION_ILLEGAL_INSTRUCTION: return "instrucción no válida";
    case EXCEPTION_INT_DIVIDE_BY_ZERO: return "división entre cero";
    case EXCEPTION_BREAKPOINT: return "punto de ruptura (comprobación interna)";
    case EXCEPTION_IN_PAGE_ERROR: return "error de página";
    case 0xE06D7363: return "excepción de C++ sin capturar";
    default: return "excepción";
    }
}

LONG WINAPI onException(EXCEPTION_POINTERS *pointers)
{
    const EXCEPTION_RECORD *record = pointers->ExceptionRecord;
    writeCrashHeader(exceptionName(record->ExceptionCode));
    writeText(" (");
    writeHex(record->ExceptionCode);
    writeText(")\nEn: ");
    writeFrame(0, reinterpret_cast<quintptr>(record->ExceptionAddress));
    if (record->ExceptionCode == EXCEPTION_ACCESS_VIOLATION && record->NumberParameters >= 2) {
        writeText(record->ExceptionInformation[0] == 0 ? "Leyendo " : "Escribiendo en ");
        writeHex(record->ExceptionInformation[1]);
        writeText("\n");
    }
    writeStack();

    // Minidump (memoria de los hilos): se abre con Visual Studio o WinDbg
    // junto con el PDB de esa compilación
    if (HMODULE dbghelp = LoadLibraryW(L"dbghelp.dll")) {
        using WriteDump = BOOL(WINAPI *)(HANDLE, DWORD, HANDLE, MINIDUMP_TYPE, PMINIDUMP_EXCEPTION_INFORMATION,
                                         PMINIDUMP_USER_STREAM_INFORMATION, PMINIDUMP_CALLBACK_INFORMATION);
        auto writeDump = reinterpret_cast<WriteDump>(GetProcAddress(dbghelp, "MiniDumpWriteDump"));
        HANDLE file = CreateFileW(g_dumpPath, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (writeDump && file != INVALID_HANDLE_VALUE) {
            MINIDUMP_EXCEPTION_INFORMATION info{GetCurrentThreadId(), pointers, FALSE};
            if (writeDump(GetCurrentProcess(), GetCurrentProcessId(), file,
                          MINIDUMP_TYPE(MiniDumpNormal | MiniDumpWithThreadInfo | MiniDumpWithIndirectlyReferencedMemory),
                          &info, nullptr, nullptr))
                writeText("Minidump guardado (.dmp)\n");
        }
        if (file != INVALID_HANDLE_VALUE)
            CloseHandle(file);
    }
    writeCrashEnd();
    // Sigue el tratamiento normal de Windows (cierre e informe de errores)
    return EXCEPTION_CONTINUE_SEARCH;
}

void onAbort(int)
{
    if (g_crashed)
        return;
    writeCrashHeader("abort (comprobación fallida o qFatal)\n");
    writeStack();
    writeCrashEnd();
}

void onPureCall()
{
    writeCrashHeader("llamada a una función virtual pura (objeto ya destruido)\n");
    writeStack();
    writeCrashEnd();
    std::abort();
}

void onInvalidParameter(const wchar_t *, const wchar_t *, const wchar_t *, unsigned, uintptr_t)
{
    writeCrashHeader("parámetro no válido en la biblioteca de C\n");
    writeStack();
    writeCrashEnd();
    std::abort();
}

void installHandlers()
{
    SetUnhandledExceptionFilter(onException);
    signal(SIGABRT, onAbort);
    _set_abort_behavior(0, _WRITE_ABORT_MSG);
    _set_purecall_handler(onPureCall);
    _set_invalid_parameter_handler(onInvalidParameter);
    // Espacio para el manejador si la caída es por desbordar la pila
    ULONG guarantee = 64 * 1024;
    SetThreadStackGuarantee(&guarantee);
}
#else
const char *signalName(int signal)
{
    switch (signal) {
    case SIGSEGV: return "SIGSEGV (acceso a memoria no válida)";
    case SIGBUS: return "SIGBUS (acceso a memoria no válida)";
    case SIGILL: return "SIGILL (instrucción no válida: comprobación interna)";
    case SIGFPE: return "SIGFPE (error aritmético)";
    case SIGABRT: return "SIGABRT (abort: comprobación fallida o qFatal)";
    case SIGTRAP: return "SIGTRAP (comprobación interna)";
    default: return "señal";
    }
}

const int CrashSignals[] = {SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGABRT, SIGTRAP};
// Las que manda el sistema u otro programa para cerrar Mitis: no son caídas
const int CloseSignals[] = {SIGTERM, SIGHUP};

void onCrashSignal(int signal, siginfo_t *info, void *)
{
    if (!g_crashed) {
        writeCrashHeader(signalName(signal));
        if (signal == SIGSEGV || signal == SIGBUS) {
            writeText(" en ");
            writeHex(reinterpret_cast<quintptr>(info->si_addr));
        }
        writeText("\n");
        writeStack();
        writeCrashEnd();
    }
    // Que termine como lo habría hecho sin este manejador
    ::signal(signal, SIG_DFL);
    raise(signal);
}

void onCloseSignal(int signal)
{
    writeText("\n");
    writeText(SystemEnd);
    writeText(signal == SIGTERM ? " (SIGTERM)\n" : " (SIGHUP)\n");
    ::signal(signal, SIG_DFL);
    raise(signal);
}

void installHandlers()
{
    // Pila propia para el manejador: una caída por desbordar la pila no
    // deja sitio en la del hilo
    static char alternateStack[64 * 1024];
    stack_t stack{};
    stack.ss_sp = alternateStack;
    stack.ss_size = sizeof(alternateStack);
    sigaltstack(&stack, nullptr);

    // backtrace() carga su biblioteca la primera vez: mejor ahora que en la caída
    void *warmup[1];
    backtrace(warmup, 1);

    struct sigaction action{};
    action.sa_sigaction = onCrashSignal;
    action.sa_flags = SA_SIGINFO | SA_ONSTACK | SA_RESETHAND;
    sigemptyset(&action.sa_mask);
    for (int signal : CrashSignals)
        sigaction(signal, &action, nullptr);
    for (int signal : CloseSignals)
        ::signal(signal, onCloseSignal);
}
#endif

void messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &message)
{
    {
        QMutexLocker lock(&g_mutex);
        if (g_written < MaxLogBytes) {
            const char *kind = "";
            switch (type) {
            case QtDebugMsg: kind = "depuración"; break;
            case QtInfoMsg: kind = "info"; break;
            case QtWarningMsg: kind = "aviso"; break;
            case QtCriticalMsg: kind = "error"; break;
            case QtFatalMsg: kind = "fatal"; break;
            }
            QByteArray line = QTime::currentTime().toString(QStringLiteral("HH:mm:ss.zzz")).toUtf8()
                              + " [" + kind + "] " + message.toUtf8();
            if (context.category && strcmp(context.category, "default") != 0)
                line += QByteArray(" (") + context.category + ')';
            line += '\n';
            writeRaw(line.constData(), size_t(line.size()));
            g_written += line.size();
            if (g_written >= MaxLogBytes)
                writeText("… registro recortado: demasiados mensajes …\n");
        }
    }
    if (g_previousHandler)
        g_previousHandler(type, context, message);
}

QString reportsFolder()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/informes");
}
}

CrashReporter::CrashReporter(QObject *parent)
    : QObject(parent)
    , m_folder(reportsFolder())
{
}

CrashReporter *CrashReporter::instance()
{
    static CrashReporter reporter;
    return &reporter;
}

CrashReporter *CrashReporter::create(QQmlEngine *, QJSEngine *)
{
    CrashReporter *reporter = instance();
    // Vive toda la app: el motor QML (uno por recarga en --dev) no lo destruye
    QQmlEngine::setObjectOwnership(reporter, QQmlEngine::CppOwnership);
    return reporter;
}

void CrashReporter::install()
{
    QDir().mkpath(m_folder);
    collectPrevious();

    const QString logPath = m_folder + QStringLiteral("/sesion.log");
#ifdef Q_OS_WIN
    g_log = CreateFileW(reinterpret_cast<LPCWSTR>(QDir::toNativeSeparators(logPath).utf16()), GENERIC_WRITE,
                        FILE_SHARE_READ, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    const QString dumpPath = QDir::toNativeSeparators(m_folder + QStringLiteral("/sesion.dmp"));
    if (dumpPath.size() < MAX_PATH)
        wcscpy_s(g_dumpPath, reinterpret_cast<const wchar_t *>(dumpPath.utf16()));
#else
    g_log = ::open(QFile::encodeName(logPath).constData(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
#endif

    const QByteArray header = "Mitis " + QCoreApplication::applicationVersion().toUtf8() + '\n'
                              + "Sistema: " + QSysInfo::prettyProductName().toUtf8() + " ("
                              + QSysInfo::currentCpuArchitecture().toUtf8() + ")\n"
                              + "Qt: " + qVersion() + '\n'
                              + "Inicio: " + QDateTime::currentDateTime().toString(Qt::ISODate).toUtf8() + "\n\n";
    writeRaw(header.constData(), size_t(header.size()));

    g_previousHandler = qInstallMessageHandler(messageHandler);
    std::set_terminate(onTerminate);
    installHandlers();

#ifndef QT_NO_SESSIONMANAGER
    // Al cerrar la sesión del sistema, Mitis puede terminar sin pasar por el
    // final de main(): no es una caída
    connect(qGuiApp, &QGuiApplication::commitDataRequest, this, [] {
        writeText("\n");
        writeText(SystemEnd);
        writeText("\n");
    });
#endif
}

void CrashReporter::finish()
{
    {
        QMutexLocker lock(&g_mutex);
        writeText("\n");
        writeText(NormalEnd);
        writeText("\n");
    }
    qInstallMessageHandler(g_previousHandler);
#ifdef Q_OS_WIN
    if (g_log != INVALID_HANDLE_VALUE)
        CloseHandle(g_log);
    g_log = INVALID_HANDLE_VALUE;
#else
    if (g_log >= 0)
        ::close(g_log);
    g_log = -1;
#endif
}

// El registro de la sesión anterior: sin línea de cierre, pasa a informe
void CrashReporter::collectPrevious()
{
    const QString logPath = m_folder + QStringLiteral("/sesion.log");
    const QString dumpPath = m_folder + QStringLiteral("/sesion.dmp");
    QFile log(logPath);
    if (!log.open(QIODevice::ReadOnly)) {
        QFile::remove(dumpPath);
        return;
    }
    const QByteArray content = log.readAll();
    log.close();
    if (content.contains(NormalEnd) || (content.contains(SystemEnd) && !content.contains(CrashMark))) {
        QFile::remove(logPath);
        QFile::remove(dumpPath);
        return;
    }

    const QDateTime when = QFileInfo(logPath).lastModified();
    const QString base = m_folder + QStringLiteral("/cierre-") + when.toString(QStringLiteral("yyyyMMdd-HHmmss"));
    QFile::remove(base + QStringLiteral(".txt"));
    QFile::rename(logPath, base + QStringLiteral(".txt"));
    if (QFile::exists(dumpPath)) {
        QFile::remove(base + QStringLiteral(".dmp"));
        QFile::rename(dumpPath, base + QStringLiteral(".dmp"));
    }
    m_pending = base + QStringLiteral(".txt");
    prune();
}

void CrashReporter::prune()
{
    const QFileInfoList files = QDir(m_folder).entryInfoList({QStringLiteral("cierre-*.txt")}, QDir::Files, QDir::Name | QDir::Reversed);
    for (int i = MaxReports; i < files.size(); ++i) {
        QFile::remove(files[i].absoluteFilePath());
        QFile::remove(files[i].path() + QLatin1Char('/') + files[i].completeBaseName() + QStringLiteral(".dmp"));
    }
}

QVariantList CrashReporter::reports() const
{
    QVariantList list;
    const QFileInfoList files = QDir(m_folder).entryInfoList({QStringLiteral("cierre-*.txt")}, QDir::Files, QDir::Name | QDir::Reversed);
    for (const QFileInfo &file : files) {
        QFile f(file.absoluteFilePath());
        const bool crash = f.open(QIODevice::ReadOnly) && f.readAll().contains(CrashMark);
        const QDateTime date = QDateTime::fromString(file.completeBaseName().mid(7), QStringLiteral("yyyyMMdd-HHmmss"));
        list.append(QVariantMap{
            {QStringLiteral("path"), file.absoluteFilePath()},
            {QStringLiteral("date"), date},
            {QStringLiteral("kind"), crash ? QStringLiteral("caida") : QStringLiteral("cierre")},
        });
    }
    return list;
}

// Un informe largo se acorta: el principio (versión, sistema) y el final
// (lo último antes de cerrarse y la pila)
QString CrashReporter::read(const QString &path) const
{
    if (QFileInfo(path).absolutePath() != QFileInfo(m_folder).absoluteFilePath())
        return {};
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    const QStringList lines = QString::fromUtf8(file.readAll()).split(QLatin1Char('\n'));
    if (lines.size() <= CopyHeadLines + CopyTailLines)
        return lines.join(QLatin1Char('\n'));
    return QStringList(lines.mid(0, CopyHeadLines)).join(QLatin1Char('\n'))
           + QStringLiteral("\n… %1 líneas omitidas (el informe completo está en %2) …\n")
                 .arg(lines.size() - CopyHeadLines - CopyTailLines)
                 .arg(QDir::toNativeSeparators(path))
           + QStringList(lines.mid(lines.size() - CopyTailLines)).join(QLatin1Char('\n'));
}

void CrashReporter::copy(const QString &path) const
{
    QGuiApplication::clipboard()->setText(read(path));
}

void CrashReporter::openFolder() const
{
    QDesktopServices::openUrl(QUrl::fromLocalFile(m_folder));
}

void CrashReporter::dismiss()
{
    if (m_pending.isEmpty())
        return;
    m_pending.clear();
    emit changed();
}

void CrashReporter::clear()
{
    const QFileInfoList files = QDir(m_folder).entryInfoList({QStringLiteral("cierre-*")}, QDir::Files);
    for (const QFileInfo &file : files)
        QFile::remove(file.absoluteFilePath());
    m_pending.clear();
    emit changed();
}

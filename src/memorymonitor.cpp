#include "memorymonitor.h"

#include <QCoreApplication>
#include <QHash>
#include <QList>
#include <QVariantList>

#if defined(Q_OS_WIN)
#include <windows.h>
#include <psapi.h>
#include <tlhelp32.h>
#elif defined(Q_OS_MACOS)
#include <libproc.h>
#include <sys/resource.h>
#else
#include <QDir>
#include <QFile>
#endif

namespace {

#if defined(Q_OS_WIN)

QList<qint64> descendants(qint64 root)
{
    // Padre de cada proceso, de una sola foto del sistema
    QMultiHash<qint64, qint64> children;
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot != INVALID_HANDLE_VALUE) {
        PROCESSENTRY32W entry;
        entry.dwSize = sizeof(entry);
        for (BOOL ok = Process32FirstW(snapshot, &entry); ok; ok = Process32NextW(snapshot, &entry))
            children.insert(entry.th32ParentProcessID, entry.th32ProcessID);
        CloseHandle(snapshot);
    }
    QList<qint64> found;
    QList<qint64> pending = { root };
    while (!pending.isEmpty()) {
        const qint64 parent = pending.takeFirst();
        for (const qint64 child : children.values(parent)) {
            // Windows reutiliza los números: un padre muerto puede «tener» hijos ajenos
            if (child != root && !found.contains(child)) {
                found.append(child);
                pending.append(child);
            }
        }
    }
    return found;
}

qint64 processBytes(qint64 pid)
{
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, DWORD(pid));
    if (!process)
        return 0;
    PROCESS_MEMORY_COUNTERS_EX counters = {};
    qint64 bytes = 0;
    if (GetProcessMemoryInfo(process, reinterpret_cast<PROCESS_MEMORY_COUNTERS *>(&counters), sizeof(counters)))
        bytes = qint64(counters.PrivateUsage);
    CloseHandle(process);
    return bytes;
}

// Todos los procesos del motor se llaman igual (QtWebEngineProcess.exe) y
// leer su línea de órdenes requiere API no documentada: sin tipo
QString processKind(qint64)
{
    return QString();
}

#elif defined(Q_OS_MACOS)

QList<qint64> descendants(qint64 root)
{
    QList<qint64> found;
    QList<qint64> pending = { root };
    while (!pending.isEmpty()) {
        const qint64 parent = pending.takeFirst();
        pid_t pids[256];
        const int count = proc_listchildpids(pid_t(parent), pids, sizeof(pids));
        for (int i = 0; i < count && i < 256; ++i) {
            if (!found.contains(pids[i])) {
                found.append(pids[i]);
                pending.append(pids[i]);
            }
        }
    }
    return found;
}

qint64 processBytes(qint64 pid)
{
    rusage_info_v2 info = {};
    if (proc_pid_rusage(pid_t(pid), RUSAGE_INFO_V2, reinterpret_cast<rusage_info_t *>(&info)) != 0)
        return 0;
    return qint64(info.ri_phys_footprint);
}

QString processKind(qint64)
{
    return QString();
}

#else

QList<qint64> descendants(qint64 root)
{
    // Padre de cada proceso, de /proc/<pid>/stat (el cuarto campo; el
    // segundo es el nombre entre paréntesis y puede llevar espacios)
    QMultiHash<qint64, qint64> children;
    const QStringList entries = QDir(QStringLiteral("/proc")).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        bool numeric = false;
        const qint64 pid = entry.toLongLong(&numeric);
        if (!numeric)
            continue;
        QFile stat(QStringLiteral("/proc/%1/stat").arg(pid));
        if (!stat.open(QIODevice::ReadOnly))
            continue;
        const QByteArray line = stat.readAll();
        const qsizetype end = line.lastIndexOf(')');
        if (end < 0)
            continue;
        const QList<QByteArray> fields = line.mid(end + 2).split(' ');
        if (fields.size() > 1)
            children.insert(fields.at(1).toLongLong(), pid);
    }
    QList<qint64> found;
    QList<qint64> pending = { root };
    while (!pending.isEmpty()) {
        const qint64 parent = pending.takeFirst();
        for (const qint64 child : children.values(parent)) {
            found.append(child);
            pending.append(child);
        }
    }
    return found;
}

// Valor en kB de una línea "Clave:   1234 kB" de un archivo de /proc
qint64 procField(const QString &path, const QByteArray &key)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return -1;
    const QList<QByteArray> lines = file.readAll().split('\n');
    for (const QByteArray &line : lines) {
        if (line.startsWith(key))
            return line.mid(key.size()).trimmed().split(' ').value(0).toLongLong() * 1024;
    }
    return -1;
}

qint64 processBytes(qint64 pid)
{
    // smaps_rollup existe desde Linux 4.14; antes, el RSS (cuenta de más lo compartido)
    const qint64 pss = procField(QStringLiteral("/proc/%1/smaps_rollup").arg(pid), "Pss:");
    if (pss >= 0)
        return pss;
    return qMax<qint64>(0, procField(QStringLiteral("/proc/%1/status").arg(pid), "VmRSS:"));
}

// El tipo de proceso de Chromium va en su línea de órdenes: --type=renderer…
QString processKind(qint64 pid)
{
    QFile file(QStringLiteral("/proc/%1/cmdline").arg(pid));
    if (!file.open(QIODevice::ReadOnly))
        return QString();
    const QList<QByteArray> args = file.readAll().split('\0');
    for (const QByteArray &arg : args) {
        if (!arg.startsWith("--type="))
            continue;
        const QByteArray type = arg.mid(7);
        if (type == "gpu-process")
            return QStringLiteral("gpu");
        return QString::fromLatin1(type);
    }
    return QString();
}

#endif

} // namespace

MemoryMonitor::MemoryMonitor(QObject *parent)
    : QObject(parent)
{
}

QVariantMap MemoryMonitor::measure() const
{
    const qint64 self = QCoreApplication::applicationPid();
    QVariantList processes;
    qint64 total = 0;
    const auto add = [&](qint64 pid, const QString &kind) {
        const qint64 bytes = processBytes(pid);
        total += bytes;
        processes.append(QVariantMap{
            { QStringLiteral("pid"), pid },
            { QStringLiteral("kind"), kind },
            { QStringLiteral("bytes"), bytes },
        });
    };
    add(self, QStringLiteral("browser"));
    const QList<qint64> children = descendants(self);
    for (const qint64 pid : children)
        add(pid, processKind(pid));
    return {
        { QStringLiteral("total"), total },
        { QStringLiteral("processes"), processes },
    };
}

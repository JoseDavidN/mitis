#include "memorymonitor.h"

#include <QCoreApplication>
#include <QHash>
#include <QList>
#include <QThread>
#include <QVariantList>

#if defined(Q_OS_WIN)
#include <windows.h>
#include <psapi.h>
#include <tlhelp32.h>
#elif defined(Q_OS_MACOS)
#include <libproc.h>
#include <mach/mach_time.h>
#include <sys/resource.h>
#else
#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <QSet>
#include <unistd.h>
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

// PROCESS_MEMORY_COUNTERS_EX2 (Windows 10 1809+), con nombre propio por si el
// SDK con que se compila no la trae
struct MemoryCountersEx2
{
    DWORD cb;
    DWORD PageFaultCount;
    SIZE_T PeakWorkingSetSize;
    SIZE_T WorkingSetSize;
    SIZE_T QuotaPeakPagedPoolUsage;
    SIZE_T QuotaPagedPoolUsage;
    SIZE_T QuotaPeakNonPagedPoolUsage;
    SIZE_T QuotaNonPagedPoolUsage;
    SIZE_T PagefileUsage;
    SIZE_T PeakPagefileUsage;
    SIZE_T PrivateUsage;
    SIZE_T PrivateWorkingSetSize;
    SIZE_T SharedCommitUsage;
};

// Espacio de trabajo privado: lo propio del proceso que está en RAM (la
// columna «Memoria» del Administrador de tareas; lo más parecido a la huella
// de macOS). La memoria comprometida (PrivateUsage) cuenta también lo
// reservado y sin usar, y con Chromium salía mucho mayor. Sin el dato
// (Windows anterior a 10 1809), la comprometida
qint64 processBytes(qint64 pid)
{
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, DWORD(pid));
    if (!process)
        return 0;
    qint64 bytes = 0;
    MemoryCountersEx2 counters = {};
    counters.cb = sizeof(counters);
    if (GetProcessMemoryInfo(process, reinterpret_cast<PROCESS_MEMORY_COUNTERS *>(&counters), sizeof(counters))
        && counters.PrivateWorkingSetSize > 0) {
        bytes = qint64(counters.PrivateWorkingSetSize);
    } else {
        PROCESS_MEMORY_COUNTERS_EX older = {};
        older.cb = sizeof(older);
        if (GetProcessMemoryInfo(process, reinterpret_cast<PROCESS_MEMORY_COUNTERS *>(&older), sizeof(older)))
            bytes = qint64(older.PrivateUsage);
    }
    CloseHandle(process);
    return bytes;
}

// Tiempo de CPU (usuario + sistema) en ns; -1 si no se puede leer
qint64 processCpuNs(qint64 pid)
{
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, DWORD(pid));
    if (!process)
        return -1;
    FILETIME creation, exited, kernel, user;
    qint64 ns = -1;
    if (GetProcessTimes(process, &creation, &exited, &kernel, &user)) {
        // FILETIME: unidades de 100 ns
        const auto value = [](const FILETIME &time) {
            return (quint64(time.dwHighDateTime) << 32) | time.dwLowDateTime;
        };
        ns = qint64((value(kernel) + value(user)) * 100);
    }
    CloseHandle(process);
    return ns;
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

qint64 processCpuNs(qint64 pid)
{
    rusage_info_v2 info = {};
    if (proc_pid_rusage(pid_t(pid), RUSAGE_INFO_V2, reinterpret_cast<rusage_info_t *>(&info)) != 0)
        return -1;
    // En Apple Silicon los tiempos van en unidades de mach_absolute_time, no en ns
    static const double scale = [] {
        mach_timebase_info_data_t base = {};
        mach_timebase_info(&base);
        return base.denom ? double(base.numer) / base.denom : 1.0;
    }();
    return qint64(double(info.ri_user_time + info.ri_system_time) * scale);
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

// Tiempo de CPU (utime + stime, campos 14 y 15 de /proc/<pid>/stat) en ns
qint64 processCpuNs(qint64 pid)
{
    QFile stat(QStringLiteral("/proc/%1/stat").arg(pid));
    if (!stat.open(QIODevice::ReadOnly))
        return -1;
    const QByteArray line = stat.readAll();
    const qsizetype end = line.lastIndexOf(')');
    if (end < 0)
        return -1;
    // Tras el nombre, el primer campo es el 3 (estado)
    const QList<QByteArray> fields = line.mid(end + 2).split(' ');
    static const long ticks = sysconf(_SC_CLK_TCK);
    if (fields.size() < 13 || ticks <= 0)
        return -1;
    return (fields.at(11).toLongLong() + fields.at(12).toLongLong()) * (1000000000LL / ticks);
}

// Lo que los procesos de Mitis usan de la GPU, según las estadísticas DRM de
// cada descriptor abierto en /dev/dri (Documentation/gpu/drm-usage-stats).
// Un mismo cliente puede estar abierto en varios descriptores o procesos: se
// cuenta una vez por drm-pdev + drm-client-id.
struct GpuSample
{
    QHash<QString, qint64> engineNs;    // "dispositivo/motor" → ns ocupado
    QHash<QString, int> capacity;       // motores iguales de esa clase
    qint64 memory = -1;
};

// "123 KiB", "5 MiB" o bytes sin unidad
qint64 fdinfoBytes(const QByteArray &value)
{
    const QList<QByteArray> parts = value.split(' ');
    qint64 bytes = parts.value(0).toLongLong();
    const QByteArray unit = parts.value(1);
    if (unit == "KiB")
        bytes *= 1024;
    else if (unit == "MiB")
        bytes *= 1024 * 1024;
    else if (unit == "GiB")
        bytes *= 1024LL * 1024 * 1024;
    return bytes;
}

void addGpuClients(qint64 pid, QSet<QByteArray> &seen, GpuSample &sample)
{
    const QString fdDir = QStringLiteral("/proc/%1/fd/").arg(pid);
    const QString infoDir = QStringLiteral("/proc/%1/fdinfo/").arg(pid);
    const QStringList fds = QDir(infoDir).entryList(QDir::Files);
    for (const QString &fd : fds) {
        // Solo los de la GPU: el resto (archivos, sockets…) no tiene estas líneas
        if (!QFile::symLinkTarget(fdDir + fd).startsWith(QLatin1String("/dev/dri/")))
            continue;
        QFile file(infoDir + fd);
        if (!file.open(QIODevice::ReadOnly))
            continue;
        QByteArray client, device;
        QHash<QByteArray, qint64> engines;
        QHash<QByteArray, int> capacity;
        qint64 resident = 0, legacy = 0;
        bool hasResident = false, hasLegacy = false;
        const QList<QByteArray> lines = file.readAll().split('\n');
        for (const QByteArray &line : lines) {
            const qsizetype colon = line.indexOf(':');
            if (colon < 0)
                continue;
            const QByteArray key = line.left(colon);
            const QByteArray value = line.mid(colon + 1).trimmed();
            if (key == "drm-client-id") {
                client = value;
            } else if (key == "drm-pdev") {
                device = value;
            } else if (key.startsWith("drm-engine-capacity-")) {
                capacity.insert(key.mid(20), value.toInt());
            } else if (key.startsWith("drm-engine-")) {
                engines[key.mid(11)] += value.split(' ').value(0).toLongLong();
            } else if (key.startsWith("drm-resident-")) {
                resident += fdinfoBytes(value);
                hasResident = true;
            } else if (key.startsWith("drm-memory-")) {
                // Nombre antiguo (amdgpu antes de drm-resident-)
                legacy += fdinfoBytes(value);
                hasLegacy = true;
            }
        }
        if (client.isEmpty())
            continue;
        const QByteArray id = device + '/' + client;
        if (seen.contains(id))
            continue;
        seen.insert(id);
        for (auto it = engines.cbegin(); it != engines.cend(); ++it) {
            const QString name = QString::fromLatin1(device + '/' + it.key());
            sample.engineNs[name] += it.value();
            sample.capacity[name] = qMax(1, capacity.value(it.key(), 1));
        }
        if (hasResident || hasLegacy)
            sample.memory = qMax<qint64>(0, sample.memory) + (hasResident ? resident : legacy);
    }
}

// Número de un archivo de /sys; -1 si no existe
qint64 sysNumber(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return -1;
    bool ok = false;
    const qint64 value = file.readAll().trimmed().toLongLong(&ok);
    return ok ? value : -1;
}

// Uso de la GPU de todo el sistema y su memoria de vídeo (amdgpu): la
// primera tarjeta que lo publique
void systemGpu(qint64 &usage, qint64 &vramUsed, qint64 &vramTotal)
{
    static const QRegularExpression cardName(QStringLiteral("^card\\d+$"));
    const QStringList cards = QDir(QStringLiteral("/sys/class/drm")).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &card : cards) {
        if (!cardName.match(card).hasMatch())
            continue;
        const QString device = QStringLiteral("/sys/class/drm/%1/device/").arg(card);
        usage = sysNumber(device + QStringLiteral("gpu_busy_percent"));
        vramUsed = sysNumber(device + QStringLiteral("mem_info_vram_used"));
        vramTotal = sysNumber(device + QStringLiteral("mem_info_vram_total"));
        if (usage >= 0 || vramTotal > 0)
            return;
    }
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

QVariantMap MemoryMonitor::measure()
{
    const qint64 self = QCoreApplication::applicationPid();
    QList<qint64> pids = { self };
    pids += descendants(self);

    if (!m_clock.isValid())
        m_clock.start();
    const qint64 now = m_clock.nsecsElapsed();
    const qint64 elapsed = m_lastNs < 0 ? -1 : now - m_lastNs;
    // Tras mucho sin medir (panel cerrado), la media de ese rato no dice nada
    // del momento: se empieza de nuevo
    const bool stale = elapsed < 0 || elapsed > 10LL * 1000 * 1000 * 1000;
    // Una medición a menos de medio segundo de la anterior (otra ventana)
    // reutiliza sus porcentajes
    const bool fresh = stale || elapsed >= 500LL * 1000 * 1000;
    const int cores = qMax(1, QThread::idealThreadCount());

    QHash<qint64, qint64> cpuNs;
    QHash<qint64, double> cpuPercent;
    QVariantList processes;
    qint64 total = 0;
    double cpuTotal = -1;
    for (int i = 0; i < pids.size(); ++i) {
        const qint64 pid = pids.at(i);
        const qint64 bytes = processBytes(pid);
        total += bytes;
        double cpu = -1;
        if (fresh) {
            const qint64 ns = processCpuNs(pid);
            if (ns >= 0) {
                cpuNs.insert(pid, ns);
                const auto previous = m_cpuNs.constFind(pid);
                // Si el tiempo baja, el número es de otro proceso (reutilizado)
                if (!stale && previous != m_cpuNs.cend() && ns >= previous.value())
                    cpu = qBound(0.0, double(ns - previous.value()) * 100 / (double(elapsed) * cores), 100.0);
            }
            cpuPercent.insert(pid, cpu);
        } else {
            cpu = m_cpuPercent.value(pid, -1);
        }
        if (cpu >= 0)
            cpuTotal = qMax(0.0, cpuTotal) + cpu;
        processes.append(QVariantMap{
            { QStringLiteral("pid"), pid },
            { QStringLiteral("kind"), i == 0 ? QStringLiteral("browser") : processKind(pid) },
            { QStringLiteral("bytes"), bytes },
            { QStringLiteral("cpu"), cpu },
        });
    }
    if (fresh) {
        m_cpuNs = cpuNs;
        m_cpuPercent = cpuPercent;
    }

    qint64 gpuMemory = -1, systemUsage = -1, vramUsed = -1, vramTotal = -1;
#if !defined(Q_OS_WIN) && !defined(Q_OS_MACOS)
    GpuSample gpu;
    QSet<QByteArray> seen;
    for (const qint64 pid : std::as_const(pids))
        addGpuClients(pid, seen, gpu);
    gpuMemory = gpu.memory;
    systemGpu(systemUsage, vramUsed, vramTotal);
    if (fresh) {
        // El motor más ocupado (gráficos, vídeo, cómputo…), como nvtop o intel_gpu_top
        double usage = -1;
        if (!stale) {
            for (auto it = gpu.engineNs.cbegin(); it != gpu.engineNs.cend(); ++it) {
                const qint64 previous = m_gpuEngineNs.value(it.key(), -1);
                if (previous < 0 || it.value() < previous)
                    continue;
                const double busy = double(it.value() - previous) * 100
                                    / (double(elapsed) * gpu.capacity.value(it.key(), 1));
                usage = qMax(usage, qBound(0.0, busy, 100.0));
            }
            // Clientes sin tiempo que comparar (todos nuevos): sin dato
        }
        m_gpuEngineNs = gpu.engineNs;
        m_gpuPercent = usage;
    }
#endif
    if (fresh)
        m_lastNs = now;

    return {
        { QStringLiteral("total"), total },
        { QStringLiteral("cpu"), cpuTotal },
        { QStringLiteral("processes"), processes },
        { QStringLiteral("gpu"), QVariantMap{
            { QStringLiteral("usage"), m_gpuPercent },
            { QStringLiteral("memory"), gpuMemory },
            { QStringLiteral("systemUsage"), systemUsage },
            { QStringLiteral("vramUsed"), vramUsed },
            { QStringLiteral("vramTotal"), vramTotal },
        } },
    };
}

#pragma once

#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Memoria, CPU y GPU que usa Mitis: su proceso y los del motor (renderizado
// de las páginas, GPU, red…), que son hijos suyos. Para el monitor de
// rendimiento. No mide por su cuenta: solo cuando se le pide, así que no
// cuesta nada mientras el panel está cerrado. En QML es el singleton
// `MemoryMonitor` del módulo Mitis.Core.
//
// Memoria (lo más parecido a «memoria de este proceso» que se puede sumar sin
// contar dos veces lo compartido):
//  · Linux: PSS (la memoria compartida se reparte entre quienes la usan)
//  · Windows: espacio de trabajo privado (PrivateWorkingSetSize, la columna
//    «Memoria» del Administrador de tareas); antes de Windows 10 1809, la
//    memoria comprometida (PrivateUsage)
//  · macOS: huella física (phys_footprint, la del Monitor de Actividad)
//
// CPU: tiempo de usuario + sistema de cada proceso entre dos mediciones,
// repartido entre todos los núcleos (100 % = el equipo entero, como el
// Administrador de tareas de Windows). Linux: /proc/<pid>/stat; Windows:
// GetProcessTimes; macOS: proc_pid_rusage.
//
// GPU, solo Linux: lo de Mitis sale de /proc/<pid>/fdinfo (estadísticas
// DRM por cliente: amdgpu, i915, xe, nouveau, msm…) y lo del sistema, de
// /sys/class/drm (amdgpu). En Windows y macOS, o sin esos datos: -1.
class MemoryMonitor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit MemoryMonitor(QObject *parent = nullptr);

    // { total (bytes), cpu (%), processes: [{ pid, kind, bytes, cpu }],
    //   gpu: { usage (%), memory (bytes), systemUsage (%), vramUsed, vramTotal } }.
    // El primer proceso es Mitis ("browser"); kind de los demás: "renderer",
    // "gpu", "utility", "zygote" o "" si el sistema no deja saberlo (Windows,
    // macOS). -1 = no disponible; la CPU y el uso de la GPU lo son también en
    // la primera medición (hacen falta dos para la diferencia).
    Q_INVOKABLE QVariantMap measure();

    // Memoria del equipo, para dormir pestañas cuando va justo (Main):
    // { total, available (bytes, -1 si no se sabe), low, recovered }. `low`: queda
    // menos del 15 % o de 1 GB (Linux, Windows) o el sistema avisa de presión
    // de memoria (macOS: la memoria «libre» engaña, comprime). `recovered`:
    // ya hay más del 20 % y de 1,5 GB (o el aviso pasó): deja de descargar.
    // Es barato (una lectura): se puede pedir cada pocos segundos.
    // Para probar, MITIS_MEMORIA_LIBRE=<MB> en el entorno finge la disponible.
    Q_INVOKABLE QVariantMap systemMemory() const;

private:
    // Tiempos de la medición anterior, para calcular los porcentajes
    QElapsedTimer m_clock;
    qint64 m_lastNs = -1;
    QHash<qint64, qint64> m_cpuNs;           // pid → tiempo de CPU (ns)
    QHash<QString, qint64> m_gpuEngineNs;    // motor de la GPU → tiempo ocupado (ns)
    // Últimos porcentajes: si dos ventanas miden casi a la vez, la segunda
    // los reutiliza en lugar de calcularlos sobre un intervalo diminuto
    QHash<qint64, double> m_cpuPercent;
    double m_gpuPercent = -1;
};

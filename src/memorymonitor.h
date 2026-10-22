#pragma once

#include <QObject>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Memoria que usa Mitis: su proceso y los del motor (renderizado de las
// páginas, GPU, red…), que son hijos suyos. Para el panel de memoria de
// desarrollo. No guarda nada ni mide por su cuenta: solo cuando se le pide,
// así que no cuesta nada mientras el panel está cerrado. En QML es el
// singleton `MemoryMonitor` del módulo Mitis.Core.
//
// Qué se mide en cada sistema (lo más parecido a «memoria de este proceso»
// que se puede sumar sin contar dos veces lo compartido):
//  · Linux: PSS (la memoria compartida se reparte entre quienes la usan)
//  · Windows: memoria privada (PrivateUsage)
//  · macOS: huella física (phys_footprint, la del Monitor de Actividad)
class MemoryMonitor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit MemoryMonitor(QObject *parent = nullptr);

    // { total (bytes), processes: [{ pid, kind, bytes }] }. El primero es
    // Mitis ("browser"); kind de los demás: "renderer", "gpu", "utility",
    // "zygote" o "" si el sistema no deja saberlo (Windows, macOS).
    Q_INVOKABLE QVariantMap measure() const;
};

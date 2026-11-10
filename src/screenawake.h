#pragma once

#include <QObject>
#include <QPointer>
#include <QList>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// Pantalla encendida mientras se ve un vídeo: que el sistema no la apague ni
// la bloquee por inactividad (en Linux, hypridle, swayidle, GNOME, KDE…).
// Cada ventana pide con hold() mientras su pestaña visible reproduce un vídeo
// (Main.qml); se pide al sistema mientras alguna lo necesite.
//  · Linux: org.freedesktop.ScreenSaver.Inhibit por D-Bus (el escritorio
//    lo suelta solo si Mitis se cierra de golpe).
//  · Windows: SetThreadExecutionState (pantalla y equipo encendidos).
//  · macOS: aserción de IOKit (PreventUserIdleDisplaySleep).
// En QML es el singleton `ScreenAwake` del módulo Mitis.Core.
class ScreenAwake : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Se está pidiendo al sistema
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

public:
    static ScreenAwake *instance();
    static ScreenAwake *create(QQmlEngine *, QJSEngine *);
    ~ScreenAwake() override;

    bool active() const { return m_active; }

    // `owner` (la ventana) pide (`on`) o deja de pedir la pantalla encendida
    Q_INVOKABLE void hold(QObject *owner, bool on);

signals:
    void activeChanged();

private:
    explicit ScreenAwake(QObject *parent = nullptr);
    void update();
    void setSystem(bool on);

    QList<QPointer<QObject>> m_owners;
    bool m_active = false;
    // Linux: cookie de Inhibit (0 sin pedir); macOS: id de la aserción
    quint32 m_cookie = 0;
    // Linux: Inhibit pedido y aún sin respuesta (al llegar, si ya no hace
    // falta, se suelta)
    bool m_waiting = false;
};

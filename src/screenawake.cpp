#include "screenawake.h"

#include <QCoreApplication>
#include <QQmlEngine>
#include <QtDebug>

#if defined(Q_OS_WIN)
#include <windows.h>
#elif defined(Q_OS_MACOS)
#include <IOKit/pwr_mgt/IOPMLib.h>
#elif defined(Q_OS_LINUX)
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>

namespace {
const QString Service = QStringLiteral("org.freedesktop.ScreenSaver");
const QString Path = QStringLiteral("/org/freedesktop/ScreenSaver");
const QString Interface = QStringLiteral("org.freedesktop.ScreenSaver");
}
#endif

ScreenAwake *ScreenAwake::instance()
{
    static ScreenAwake *awake = new ScreenAwake(QCoreApplication::instance());
    return awake;
}

ScreenAwake *ScreenAwake::create(QQmlEngine *, QJSEngine *)
{
    // Uno para toda la app (también entre recargas de --dev)
    ScreenAwake *awake = instance();
    QQmlEngine::setObjectOwnership(awake, QQmlEngine::CppOwnership);
    return awake;
}

ScreenAwake::ScreenAwake(QObject *parent)
    : QObject(parent)
{
}

ScreenAwake::~ScreenAwake()
{
    setSystem(false);
}

void ScreenAwake::hold(QObject *owner, bool on)
{
    if (!owner)
        return;
    const qsizetype at = m_owners.indexOf(owner);
    if (on && at < 0) {
        m_owners.append(owner);
        // Una ventana cerrada deja de pedirlo
        connect(owner, &QObject::destroyed, this, [this] { update(); });
    } else if (!on && at >= 0) {
        m_owners.removeAt(at);
    }
    update();
}

void ScreenAwake::update()
{
    m_owners.removeAll(nullptr);
    const bool wanted = !m_owners.isEmpty();
    if (wanted == m_active)
        return;
    m_active = wanted;
    setSystem(wanted);
    emit activeChanged();
}

void ScreenAwake::setSystem(bool on)
{
#if defined(Q_OS_WIN)
    // Se queda hasta la próxima llamada desde este mismo hilo
    SetThreadExecutionState(on ? ES_CONTINUOUS | ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED : ES_CONTINUOUS);
#elif defined(Q_OS_MACOS)
    if (on && m_cookie == 0) {
        IOPMAssertionID id = 0;
        if (IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep, kIOPMAssertionLevelOn,
                                        CFSTR("Mitis: reproduciendo un video"), &id) == kIOReturnSuccess)
            m_cookie = id;
    } else if (!on && m_cookie != 0) {
        IOPMAssertionRelease(m_cookie);
        m_cookie = 0;
    }
#elif defined(Q_OS_LINUX)
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected())
        return;
    if (on) {
        if (m_cookie != 0 || m_waiting)
            return;
        m_waiting = true;
        QDBusMessage call = QDBusMessage::createMethodCall(Service, Path, Interface, QStringLiteral("Inhibit"));
        call << QStringLiteral("Mitis") << QStringLiteral("Reproduciendo un vídeo");
        auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(call), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
            w->deleteLater();
            m_waiting = false;
            const QDBusPendingReply<quint32> reply = *w;
            if (reply.isError()) {
                // Sin servicio (escritorio sin salvapantallas): nada que impedir
                qInfo("Pantalla encendida: el escritorio no lo admite (%s)", qPrintable(reply.error().name()));
                return;
            }
            m_cookie = reply.value();
            // Ya no hacía falta cuando llegó la respuesta
            if (!m_active)
                setSystem(false);
        });
    } else if (m_cookie != 0) {
        QDBusMessage call = QDBusMessage::createMethodCall(Service, Path, Interface, QStringLiteral("UnInhibit"));
        call << m_cookie;
        bus.asyncCall(call);
        m_cookie = 0;
    }
#else
    Q_UNUSED(on);
#endif
}

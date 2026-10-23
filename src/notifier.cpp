#include "notifier.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QMetaObject>
#include <QQmlEngine>
#include <QQuickWebEngineProfile>
#include <QStandardPaths>
#include <QWebEngineNotification>

#if defined(MITIS_DBUS_NOTIFICATIONS)
#include <QDBusConnection>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusMessage>
#elif defined(Q_OS_WIN)
#include <windows.h>
#include <shellapi.h>
#include <QGuiApplication>
#include <QIcon>
#endif

SystemNotifier::SystemNotifier(QObject *parent)
    : QObject(parent)
{
    platformInit();
}

SystemNotifier::~SystemNotifier()
{
    // Las que siguen a la vista se quitan: sin Mitis no se pueden atender
    const auto keys = m_items.keys();
    for (const quint32 key : keys) {
        platformClose(key, m_items.value(key));
        forget(key);
    }
    platformShutdown();
}

void SystemNotifier::attach(QQuickWebEngineProfile *profile)
{
    connect(profile, &QQuickWebEngineProfile::presentNotification, this, &SystemNotifier::present);
}

void SystemNotifier::present(QWebEngineNotification *notification)
{
    if (!notification)
        return;
    // La crea el motor para QML, que la recogería como basura: es nuestra
    QQmlEngine::setObjectOwnership(notification, QQmlEngine::CppOwnership);
    notification->setParent(this);

    // Misma etiqueta y sitio que una que está a la vista: la sustituye
    quint32 replacing = 0;
    Item item;
    for (auto it = m_items.cbegin(); it != m_items.cend(); ++it) {
        if (it->notification->matches(notification)) {
            replacing = it.key();
            item.systemId = it->systemId;
            break;
        }
    }
    if (replacing) {
        const Item old = m_items.take(replacing);
        if (!old.iconPath.isEmpty())
            QFile::remove(old.iconPath);
        old.notification->deleteLater();
    }

    const quint32 key = m_nextKey++;
    item.notification = notification;
    item.iconPath = saveIcon(key, notification->icon());
    m_items.insert(key, item);

    // La página la cierra (o la sustituye por código): se quita del sistema
    connect(notification, &QWebEngineNotification::closed, this, [this, key] { closedByPage(key); });

    platformShow(key, m_items[key], replacing);
    // Para la página, ya se muestra (evento show)
    notification->show();
}

void SystemNotifier::clicked(quint32 key)
{
    const auto it = m_items.constFind(key);
    if (it == m_items.cend())
        return;
    const QUrl origin = it->notification->origin();
    it->notification->click();
    emit activated(origin);
    // Pulsada, el sistema la quita: para la página, cerrada
    dismissed(key);
}

void SystemNotifier::dismissed(quint32 key)
{
    const auto it = m_items.constFind(key);
    if (it == m_items.cend())
        return;
    QWebEngineNotification *notification = it->notification;
    // closed() de la página no debe volver aquí
    disconnect(notification, &QWebEngineNotification::closed, this, nullptr);
    notification->close();
    forget(key);
}

void SystemNotifier::closedByPage(quint32 key)
{
    const auto it = m_items.constFind(key);
    if (it == m_items.cend())
        return;
    platformClose(key, *it);
    forget(key);
}

void SystemNotifier::forget(quint32 key)
{
    const Item item = m_items.take(key);
    if (!item.iconPath.isEmpty())
        QFile::remove(item.iconPath);
    if (item.notification)
        item.notification->deleteLater();
    if (m_current == key)
        m_current = 0;
}

// Icono de la notificación (el del sitio o el que pase la página) en la
// caché, para el sistema. Sin icono, "": el sistema pone el de Mitis.
QString SystemNotifier::saveIcon(quint32 key, const QImage &icon) const
{
#if defined(Q_OS_WIN)
    Q_UNUSED(key)
    Q_UNUSED(icon)
    return QString(); // Windows recibe el icono en memoria (HICON)
#else
    if (icon.isNull())
        return QString();
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                        + QStringLiteral("/notificaciones");
    if (!QDir().mkpath(dir))
        return QString();
    const QString path = dir + QStringLiteral("/%1.png").arg(key);
    return icon.save(path, "PNG") ? path : QString();
#endif
}

quint32 SystemNotifier::keyForSystemId(uint id) const
{
    for (auto it = m_items.cbegin(); it != m_items.cend(); ++it) {
        if (it->systemId == id)
            return it.key();
    }
    return 0;
}

// ── Linux: org.freedesktop.Notifications ─────────────────────────────
#if defined(MITIS_DBUS_NOTIFICATIONS)

namespace {
const QString Service = QStringLiteral("org.freedesktop.Notifications");
const QString Path = QStringLiteral("/org/freedesktop/Notifications");
const QString Interface = QStringLiteral("org.freedesktop.Notifications");
}

void SystemNotifier::platformInit()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(Service, Path, Interface, QStringLiteral("ActionInvoked"),
                this, SLOT(onActionInvoked(uint,QString)));
    bus.connect(Service, Path, Interface, QStringLiteral("NotificationClosed"),
                this, SLOT(onNotificationClosed(uint,uint)));
}

void SystemNotifier::platformShutdown() {}

void SystemNotifier::platformShow(quint32 key, Item &item, quint32 replacing)
{
    Q_UNUSED(replacing)
    const QWebEngineNotification *notification = item.notification;

    QVariantMap hints;
    // Nombre e icono de la aplicación: los de mitis.desktop
    hints.insert(QStringLiteral("desktop-entry"), QStringLiteral("mitis"));
    if (!item.iconPath.isEmpty())
        hints.insert(QStringLiteral("image-path"), item.iconPath);

    // El cuerpo admite marcas sencillas en algunos escritorios: se escapa.
    // Debajo, el sitio, para saber de dónde viene
    QString body = notification->message().toHtmlEscaped();
    const QString host = notification->origin().host();
    if (!host.isEmpty())
        body += (body.isEmpty() ? QString() : QStringLiteral("\n")) + host;

    QDBusMessage message = QDBusMessage::createMethodCall(Service, Path, Interface, QStringLiteral("Notify"));
    message << QStringLiteral("Mitis")
            << quint32(item.systemId) // sustituye a la de la misma etiqueta
            << QString()              // icono: el de desktop-entry
            << notification->title()
            << body
            << QStringList{ QStringLiteral("default"), QStringLiteral("Abrir") }
            << hints
            << qint32(-1);            // duración: la del escritorio

    // Sin bloquear: el id llega en la respuesta
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, key](QDBusPendingCallWatcher *call) {
        call->deleteLater();
        const QDBusPendingReply<uint> reply = *call;
        if (reply.isError()) {
            qWarning().noquote() << "[Mitis] No se pudo mostrar la notificación:" << reply.error().message();
            return;
        }
        const auto it = m_items.find(key);
        if (it != m_items.end()) {
            it->systemId = reply.value();
        } else {
            // La página la cerró antes de que el sistema respondiera
            QDBusMessage close = QDBusMessage::createMethodCall(Service, Path, Interface,
                                                                QStringLiteral("CloseNotification"));
            close << reply.value();
            QDBusConnection::sessionBus().asyncCall(close);
        }
    });
}

void SystemNotifier::platformClose(quint32 key, const Item &item)
{
    Q_UNUSED(key)
    if (item.systemId == 0)
        return;
    QDBusMessage close = QDBusMessage::createMethodCall(Service, Path, Interface,
                                                        QStringLiteral("CloseNotification"));
    close << quint32(item.systemId);
    QDBusConnection::sessionBus().asyncCall(close);
}

void SystemNotifier::onActionInvoked(uint id, const QString &action)
{
    Q_UNUSED(action) // "default" (clic en la notificación) o "Abrir": lo mismo
    if (const quint32 key = keyForSystemId(id))
        clicked(key);
}

void SystemNotifier::onNotificationClosed(uint id, uint reason)
{
    Q_UNUSED(reason)
    // Tras un clic también llega: entonces ya se olvidó y no hay nada que hacer
    if (const quint32 key = keyForSystemId(id))
        dismissed(key);
}

// ── Windows: área de notificación ────────────────────────────────────
#elif defined(Q_OS_WIN)

namespace {
constexpr UINT TrayMessage = WM_APP + 1;
constexpr UINT TrayId = 1;
const wchar_t WindowClass[] = L"MitisNotificaciones";

void copyText(wchar_t *target, size_t size, const QString &text)
{
    const std::wstring wide = text.left(int(size) - 1).toStdWString();
    wcsncpy_s(target, size, wide.c_str(), _TRUNCATE);
}
}

struct NotifierNative
{
    static LRESULT CALLBACK windowProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam)
    {
        if (message == TrayMessage) {
            auto *owner = reinterpret_cast<SystemNotifier *>(GetWindowLongPtrW(window, GWLP_USERDATA));
            const quint32 key = owner ? owner->m_current : 0;
            // NOTIFYICON_VERSION_4: el evento va en la parte baja de lParam.
            // Se atiende después: aquí se está dentro de la llamada del sistema
            if (!owner)
                return 0;
            switch (LOWORD(lParam)) {
            case NIN_BALLOONUSERCLICK:
                QMetaObject::invokeMethod(owner, [owner, key] {
                    owner->clicked(key);
                    hideIfIdle(owner);
                }, Qt::QueuedConnection);
                return 0;
            case NIN_BALLOONTIMEOUT:
            case NIN_BALLOONHIDE:
                QMetaObject::invokeMethod(owner, [owner, key] {
                    owner->dismissed(key);
                    hideIfIdle(owner);
                }, Qt::QueuedConnection);
                return 0;
            default:
                return 0;
            }
        }
        return DefWindowProcW(window, message, wParam, lParam);
    }

    static NOTIFYICONDATAW data(HWND window)
    {
        NOTIFYICONDATAW nid {};
        nid.cbSize = sizeof(nid);
        nid.hWnd = window;
        nid.uID = TrayId;
        return nid;
    }

    // Quita el icono del área de notificación (y con él la notificación)
    static void removeIcon(HWND window);
    // Si ya no se ve ninguna (una nueva pudo llegar entretanto: entonces no)
    static void hideIfIdle(SystemNotifier *owner)
    {
        if (owner->m_current == 0)
            removeIcon(static_cast<HWND>(owner->m_native));
    }
};

namespace {
HICON g_balloonIcon = nullptr;
HICON g_appIcon = nullptr;
bool g_iconAdded = false;
}

void NotifierNative::removeIcon(HWND window)
{
    if (!window || !g_iconAdded)
        return;
    NOTIFYICONDATAW nid = data(window);
    Shell_NotifyIconW(NIM_DELETE, &nid);
    g_iconAdded = false;
}

void SystemNotifier::platformInit()
{
    WNDCLASSW windowClass {};
    windowClass.lpfnWndProc = &NotifierNative::windowProc;
    windowClass.hInstance = GetModuleHandleW(nullptr);
    windowClass.lpszClassName = WindowClass;
    RegisterClassW(&windowClass);
    // Ventana oculta (nunca se muestra): solo recibe los avisos
    HWND window = CreateWindowExW(0, WindowClass, L"Mitis", WS_POPUP, 0, 0, 0, 0,
                                  nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
    if (window)
        SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
    m_native = window;
}

void SystemNotifier::platformShutdown()
{
    HWND window = static_cast<HWND>(m_native);
    if (!window)
        return;
    NotifierNative::removeIcon(window);
    DestroyWindow(window);
    m_native = nullptr;
    if (g_balloonIcon)
        DestroyIcon(g_balloonIcon);
    if (g_appIcon)
        DestroyIcon(g_appIcon);
    g_balloonIcon = g_appIcon = nullptr;
}

void SystemNotifier::platformShow(quint32 key, Item &item, quint32 replacing)
{
    Q_UNUSED(replacing)
    HWND window = static_cast<HWND>(m_native);
    if (!window)
        return;

    // Windows enseña una a la vez: la anterior, para la página, se cierra
    if (m_current && m_current != key && m_items.contains(m_current))
        dismissed(m_current);
    m_current = key;

    if (!g_appIcon)
        g_appIcon = QGuiApplication::windowIcon().pixmap(32, 32).toImage().toHICON();

    NOTIFYICONDATAW nid = NotifierNative::data(window);
    if (!g_iconAdded) {
        nid.uFlags = NIF_ICON | NIF_TIP | NIF_MESSAGE;
        nid.uCallbackMessage = TrayMessage;
        nid.hIcon = g_appIcon;
        copyText(nid.szTip, ARRAYSIZE(nid.szTip), QStringLiteral("Mitis"));
        if (!Shell_NotifyIconW(NIM_ADD, &nid))
            return;
        nid.uVersion = NOTIFYICON_VERSION_4;
        Shell_NotifyIconW(NIM_SETVERSION, &nid);
        g_iconAdded = true;
    }

    const QWebEngineNotification *notification = item.notification;
    if (g_balloonIcon) {
        DestroyIcon(g_balloonIcon);
        g_balloonIcon = nullptr;
    }
    const QImage icon = notification->icon();
    if (!icon.isNull())
        g_balloonIcon = icon.scaled(64, 64, Qt::KeepAspectRatio, Qt::SmoothTransformation).toHICON();

    QString body = notification->message();
    const QString host = notification->origin().host();
    if (!host.isEmpty())
        body += (body.isEmpty() ? QString() : QStringLiteral("\n")) + host;

    NOTIFYICONDATAW info = NotifierNative::data(window);
    info.uFlags = NIF_INFO;
    copyText(info.szInfoTitle, ARRAYSIZE(info.szInfoTitle), notification->title());
    // Un texto vacío no muestra nada: al menos un espacio
    copyText(info.szInfo, ARRAYSIZE(info.szInfo), body.isEmpty() ? QStringLiteral(" ") : body);
    if (g_balloonIcon) {
        info.dwInfoFlags = NIIF_USER | NIIF_LARGE_ICON;
        info.hBalloonIcon = g_balloonIcon;
    } else {
        info.dwInfoFlags = NIIF_NONE;
    }
    Shell_NotifyIconW(NIM_MODIFY, &info);
}

void SystemNotifier::platformClose(quint32 key, const Item &item)
{
    Q_UNUSED(item)
    // Solo se ve la última: si es esta, se quita
    if (key == m_current)
        NotifierNative::removeIcon(static_cast<HWND>(m_native));
}

void SystemNotifier::onActionInvoked(uint, const QString &) {}
void SystemNotifier::onNotificationClosed(uint, uint) {}

// ── macOS: notifier_mac.mm ───────────────────────────────────────────
#elif defined(Q_OS_MACOS)

void SystemNotifier::onActionInvoked(uint, const QString &) {}
void SystemNotifier::onNotificationClosed(uint, uint) {}

// ── Sin servicio de notificaciones: no se muestran ───────────────────
#else

void SystemNotifier::platformInit() {}
void SystemNotifier::platformShutdown() {}
void SystemNotifier::platformShow(quint32, Item &, quint32) {}
void SystemNotifier::platformClose(quint32, const Item &) {}
void SystemNotifier::onActionInvoked(uint, const QString &) {}
void SystemNotifier::onNotificationClosed(uint, uint) {}

#endif

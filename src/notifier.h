#pragma once

#include <QHash>
#include <QObject>
#include <QString>
#include <QUrl>

class QImage;
class QQuickWebEngineProfile;
class QWebEngineNotification;

// Notificaciones de las páginas (API Notification de la web) como
// notificaciones del sistema, nunca dentro de Mitis:
//  · Linux: servicio org.freedesktop.Notifications (D-Bus), el de todos los
//    escritorios (KDE, GNOME, XFCE…).
//  · Windows: notificación del área de notificación (Shell_NotifyIcon), que
//    Windows 10/11 muestra como notificación del sistema. Una a la vez: la
//    nueva sustituye a la anterior.
//  · macOS: UserNotifications (notifier_mac.mm).
// Al pulsarla, la página recibe el clic (onclick) y Mitis avisa con
// activated() para traer al frente su pestaña. Al cerrarla, la página
// recibe el cierre. Una notificación con la misma etiqueta (tag) que otra
// la sustituye, como en Chrome.
//
// Las notificaciones push (con el sitio cerrado) no llegan aquí: Qt WebEngine
// no tiene servicio push.
class SystemNotifier : public QObject
{
    Q_OBJECT

public:
    explicit SystemNotifier(QObject *parent = nullptr);
    ~SystemNotifier() override;

    // Muestra las notificaciones de las páginas de este perfil
    void attach(QQuickWebEngineProfile *profile);

signals:
    // El usuario pulsó una notificación del sitio `origin`
    void activated(const QUrl &origin);

private slots:
    // Señales del servicio de notificaciones de Linux (D-Bus)
    void onActionInvoked(uint id, const QString &action);
    void onNotificationClosed(uint id, uint reason);

private:
    struct Item {
        QWebEngineNotification *notification = nullptr;
        uint systemId = 0;      // Linux: id del servicio (0 hasta que responde)
        QString iconPath;       // copia del icono en disco (Linux, macOS)
    };

    void present(QWebEngineNotification *notification);
    // Lo pide el sistema (clic o cierre): se lo cuenta a la página y se olvida
    void clicked(quint32 key);
    void dismissed(quint32 key);
    // Lo pide la página: se quita del sistema
    void closedByPage(quint32 key);
    void forget(quint32 key);
    QString saveIcon(quint32 key, const QImage &icon) const;
    quint32 keyForSystemId(uint id) const;

    // Por sistema (notifier.cpp; macOS en notifier_mac.mm)
    void platformInit();
    void platformShutdown();
    void platformShow(quint32 key, Item &item, quint32 replacing);
    void platformClose(quint32 key, const Item &item);

    QHash<quint32, Item> m_items;
    quint32 m_nextKey = 1;
    // Windows: ventana oculta que recibe los avisos del área de notificación
    // y la notificación que se ve ahora. macOS: delegado del centro.
    void *m_native = nullptr;
    quint32 m_current = 0;
    friend struct NotifierNative;
};

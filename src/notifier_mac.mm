// SystemNotifier en macOS: centro de notificaciones (UserNotifications).
// Requiere que Mitis se ejecute como paquete .app (identificador de bundle):
// fuera de él, el centro no existe y las notificaciones no se muestran.

#include "notifier.h"

#include <QMetaObject>
#include <QPointer>
#include <QWebEngineNotification>

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

struct NotifierNative
{
    static void clicked(SystemNotifier *owner, quint32 key) { owner->clicked(key); }
    static void dismissed(SystemNotifier *owner, quint32 key) { owner->dismissed(key); }
};

@interface MitisNotificationDelegate : NSObject <UNUserNotificationCenterDelegate>
@property (nonatomic, assign) QPointer<SystemNotifier> *owner;
@end

@implementation MitisNotificationDelegate

// Con Mitis delante, también se muestran (por defecto macOS las calla)
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
    Q_UNUSED(center)
    Q_UNUSED(notification)
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList
                      | UNNotificationPresentationOptionSound);
}

// Pulsada (o descartada): se atiende en el hilo de Mitis
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
    Q_UNUSED(center)
    const quint32 key = quint32(response.notification.request.identifier.longLongValue);
    const bool open = [response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier];
    QPointer<SystemNotifier> owner = self.owner ? *self.owner : QPointer<SystemNotifier>();
    if (owner) {
        QMetaObject::invokeMethod(owner.data(), [owner, key, open] {
            if (!owner)
                return;
            if (open)
                NotifierNative::clicked(owner.data(), key);
            else
                NotifierNative::dismissed(owner.data(), key);
        }, Qt::QueuedConnection);
    }
    completionHandler();
}

@end

namespace {
bool hasBundle()
{
    return NSBundle.mainBundle.bundleIdentifier != nil;
}
NSString *identifier(quint32 key)
{
    return [NSString stringWithFormat:@"%u", key];
}
}

void SystemNotifier::platformInit()
{
    if (!hasBundle())
        return;
    MitisNotificationDelegate *delegate = [[MitisNotificationDelegate alloc] init];
    delegate.owner = new QPointer<SystemNotifier>(this);
    UNUserNotificationCenter.currentNotificationCenter.delegate = delegate;
    m_native = (__bridge_retained void *)delegate;
}

void SystemNotifier::platformShutdown()
{
    if (!m_native)
        return;
    MitisNotificationDelegate *delegate = (__bridge_transfer MitisNotificationDelegate *)m_native;
    UNUserNotificationCenter.currentNotificationCenter.delegate = nil;
    delete delegate.owner;
    delegate.owner = nullptr;
    m_native = nullptr;
}

void SystemNotifier::platformShow(quint32 key, Item &item, quint32 replacing)
{
    if (!m_native)
        return;
    const QWebEngineNotification *notification = item.notification;

    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = notification->title().toNSString();
    content.body = notification->message().toNSString();
    // El sitio, debajo del título
    content.subtitle = notification->origin().host().toNSString();
    content.sound = UNNotificationSound.defaultSound;
    if (!item.iconPath.isEmpty()) {
        NSURL *url = [NSURL fileURLWithPath:item.iconPath.toNSString()];
        UNNotificationAttachment *attachment =
            [UNNotificationAttachment attachmentWithIdentifier:@"icon" URL:url options:nil error:nil];
        if (attachment)
            content.attachments = @[ attachment ];
        // El sistema se lleva el archivo: ya no hay que borrarlo
        item.iconPath.clear();
    }

    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    if (replacing)
        [center removeDeliveredNotificationsWithIdentifiers:@[ identifier(replacing) ]];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier(key)
                                                                          content:content
                                                                          trigger:nil];
    // La primera vez macOS pregunta si se permiten; después responde al momento
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                          completionHandler:^(BOOL granted, NSError *error) {
                              Q_UNUSED(error)
                              if (granted)
                                  [center addNotificationRequest:request withCompletionHandler:nil];
                          }];
}

void SystemNotifier::platformClose(quint32 key, const Item &item)
{
    Q_UNUSED(item)
    if (!m_native)
        return;
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    [center removeDeliveredNotificationsWithIdentifiers:@[ identifier(key) ]];
    [center removePendingNotificationRequestsWithIdentifiers:@[ identifier(key) ]];
}

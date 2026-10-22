#include "enginebridge.h"

#include <QQuickWebEngineProfile>
#include <QtDebug>

#include "requestinterceptor.h"

EngineBridge::EngineBridge(const QString &widevinePath, QObject *parent)
    : QObject(parent)
    , m_interceptor(new RequestInterceptor(this))
    , m_widevinePath(widevinePath)
{
}

QString EngineBridge::googleChromeVersion() const
{
    return QString::fromLatin1(RequestInterceptor::googleChromeVersion());
}

// Un solo interceptor para toda la app: en --dev el perfil se vuelve a crear
// en cada recarga y se le instala el mismo
void EngineBridge::installInterceptor(QObject *profile)
{
    auto *webProfile = qobject_cast<QQuickWebEngineProfile *>(profile);
    if (!webProfile) {
        qWarning("[Mitis] installInterceptor: no es un perfil de Qt WebEngine");
        return;
    }
    webProfile->setUrlRequestInterceptor(m_interceptor);
}

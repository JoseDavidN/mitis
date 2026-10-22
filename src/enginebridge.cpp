#include "enginebridge.h"

#include <QQuickWebEngineProfile>
#include <QWebEngineCookieStore>
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

void EngineBridge::setBlockThirdPartyCookies(bool value)
{
    if (m_blockThirdPartyCookies.exchange(value) != value)
        emit preferencesChanged();
}

bool EngineBridge::doNotTrack() const
{
    return m_interceptor->doNotTrack;
}

void EngineBridge::setDoNotTrack(bool value)
{
    if (m_interceptor->doNotTrack.exchange(value) != value)
        emit preferencesChanged();
}

bool EngineBridge::httpsUpgrade() const
{
    return m_interceptor->httpsUpgrade;
}

void EngineBridge::setHttpsUpgrade(bool value)
{
    if (m_interceptor->httpsUpgrade.exchange(value) != value)
        emit preferencesChanged();
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
    // Cookies de terceros: las de otro sitio dentro de la página (anuncios,
    // rastreadores, botones de redes sociales). El puente vive toda la app.
    webProfile->cookieStore()->setCookieFilter([this](const QWebEngineCookieStore::FilterRequest &request) {
        return !(request.thirdParty && m_blockThirdPartyCookies);
    });
}

bool EngineBridge::takeHttpsFallback(const QUrl &url)
{
    return url.scheme() == QLatin1String("https") && m_interceptor->takeHttpsFallback(url.host());
}

bool EngineBridge::isHttpsUpgrade(const QUrl &url) const
{
    return url.scheme() == QLatin1String("https") && m_interceptor->isUpgraded(url.host());
}

void EngineBridge::confirmHttps(const QUrl &url)
{
    if (url.scheme() == QLatin1String("https"))
        m_interceptor->confirmHttps(url.host());
}

void EngineBridge::clearCookies(QObject *profile)
{
    auto *webProfile = qobject_cast<QQuickWebEngineProfile *>(profile);
    if (!webProfile) {
        qWarning("[Mitis] clearCookies: no es un perfil de Qt WebEngine");
        return;
    }
    webProfile->cookieStore()->deleteAllCookies();
}

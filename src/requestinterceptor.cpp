#include "requestinterceptor.h"

#include "contentblocker.h"

#include <QHash>
#include <QHostAddress>
#include <QWebEngineUrlRequestInfo>

namespace {
// Red local: direcciones IP, localhost, *.local y nombres sin dominio
// ("router"). Ahí https casi nunca existe y no se sube.
bool isLocalHost(const QString &host)
{
    return !host.contains(QLatin1Char('.')) || host == QLatin1String("localhost")
        || host.endsWith(QLatin1String(".localhost")) || host.endsWith(QLatin1String(".local"))
        || !QHostAddress(host).isNull();
}

// Tipo de recurso del motor → el de las listas de filtros
FilterEngine::Type filterType(QWebEngineUrlRequestInfo::ResourceType type)
{
    switch (type) {
    case QWebEngineUrlRequestInfo::ResourceTypeMainFrame:
    case QWebEngineUrlRequestInfo::ResourceTypeNavigationPreloadMainFrame:
        return FilterEngine::Document;
    case QWebEngineUrlRequestInfo::ResourceTypeSubFrame:
    case QWebEngineUrlRequestInfo::ResourceTypeNavigationPreloadSubFrame:
        return FilterEngine::Subdocument;
    case QWebEngineUrlRequestInfo::ResourceTypeStylesheet:
        return FilterEngine::Stylesheet;
    case QWebEngineUrlRequestInfo::ResourceTypeScript:
    case QWebEngineUrlRequestInfo::ResourceTypeWorker:
    case QWebEngineUrlRequestInfo::ResourceTypeSharedWorker:
    case QWebEngineUrlRequestInfo::ResourceTypeServiceWorker:
        return FilterEngine::Script;
    case QWebEngineUrlRequestInfo::ResourceTypeImage:
    case QWebEngineUrlRequestInfo::ResourceTypeFavicon:
        return FilterEngine::Image;
    case QWebEngineUrlRequestInfo::ResourceTypeFontResource:
        return FilterEngine::Font;
    case QWebEngineUrlRequestInfo::ResourceTypeObject:
    case QWebEngineUrlRequestInfo::ResourceTypePluginResource:
        return FilterEngine::Object;
    case QWebEngineUrlRequestInfo::ResourceTypeMedia:
        return FilterEngine::Media;
    case QWebEngineUrlRequestInfo::ResourceTypeXhr:
    case QWebEngineUrlRequestInfo::ResourceTypeJson:
        return FilterEngine::Xhr;
    case QWebEngineUrlRequestInfo::ResourceTypePing:
    case QWebEngineUrlRequestInfo::ResourceTypeCspReport:
        return FilterEngine::Ping;
    case QWebEngineUrlRequestInfo::ResourceTypeWebSocket:
        return FilterEngine::WebSocket;
    default:
        return FilterEngine::Other;
    }
}

}

RequestInterceptor::RequestInterceptor(ContentBlocker *blocker, bool strict, QObject *parent)
    : QWebEngineUrlRequestInterceptor(parent)
    , m_blocker(blocker)
    , m_strict(strict)
{
}


bool RequestInterceptor::takeHttpsFallback(const QString &host)
{
    if (!m_upgraded.remove(host))
        return false;
    m_httpAllowed.insert(host);
    return true;
}

void RequestInterceptor::confirmHttps(const QString &host)
{
    m_upgraded.remove(host);
}

void RequestInterceptor::interceptRequest(QWebEngineUrlRequestInfo &info)
{
    const QUrl url = info.requestUrl();
    const bool mainFrame = info.resourceType() == QWebEngineUrlRequestInfo::ResourceTypeMainFrame;

    // Anuncios y rastreadores. La página que abre el usuario solo se bloquea
    // si una lista lo pide expresamente ($document: sitios de estafas…)
    if (m_blocker->shouldBlock(url, mainFrame ? url : info.firstPartyUrl(), filterType(info.resourceType()), m_strict)) {
        info.block(true);
        return;
    }

    if (doNotTrack || m_strict) {
        info.setHttpHeader("DNT", "1");
        info.setHttpHeader("Sec-GPC", "1");
    }

    // Solo la página (marco principal): sus recursos http dentro de una
    // página https ya los sube o bloquea el propio motor. Sin parámetros de
    // rastreo y, si es http, por https: todo en una sola redirección.
    if (mainFrame && info.requestMethod() == "GET") {
        QUrl target = m_blocker->withoutTrackingParams(url, m_strict);
        const QString host = url.host();
        if ((httpsUpgrade || m_strict) && url.scheme() == QLatin1String("http") && !isLocalHost(host)
            && !m_httpAllowed.contains(host)) {
            target.setScheme(QStringLiteral("https"));
            if (url.port() == 80)
                target.setPort(-1);
            m_upgraded.insert(host);
        }
        if (target != url) {
            info.redirect(target);
            return;
        }
    }
}

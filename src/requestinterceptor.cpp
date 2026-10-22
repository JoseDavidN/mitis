#include "requestinterceptor.h"

#include <QHash>
#include <QHostAddress>
#include <QWebEngineUrlRequestInfo>
#include <QtWebEngineCore/qtwebenginecoreglobal.h>

namespace {
bool isGoogleSignIn(const QUrl &url)
{
    return url.host() == QLatin1String("accounts.google.com");
}

// Red local: direcciones IP, localhost, *.local y nombres sin dominio
// ("router"). Ahí https casi nunca existe y no se sube.
bool isLocalHost(const QString &host)
{
    return !host.contains(QLatin1Char('.')) || host == QLatin1String("localhost")
        || host.endsWith(QLatin1String(".localhost")) || host.endsWith(QLatin1String(".local"))
        || !QHostAddress(host).isNull();
}

// Chrome estable vigente (Arch: paquete chromium). Si Google vuelve a
// rechazar el inicio de sesión, lo primero es subir esta versión.
constexpr auto CurrentChromeVersion = "153.0.8010.36";

int majorOf(const QByteArray &version)
{
    return version.left(version.indexOf('.')).toInt();
}

// La marca "de relleno" que añade Chromium (GREASE) para su versión
constexpr auto GreaseBrand = R"("Not=A?Brand";v="24")";
constexpr auto GreaseFullBrand = R"("Not=A?Brand";v="24.0.0.0")";
}

QByteArray RequestInterceptor::googleChromeVersion()
{
    const QByteArray engine = qWebEngineChromiumVersion();
    const QByteArray current = CurrentChromeVersion;
    return majorOf(engine) >= majorOf(current) ? engine : current;
}

RequestInterceptor::RequestInterceptor(QObject *parent)
    : QWebEngineUrlRequestInterceptor(parent)
{
    // 153.0.8010.36 → mayor 153
    const QByteArray full = googleChromeVersion();
    const QByteArray major = QByteArray::number(majorOf(full));
#if defined(Q_OS_WIN)
    const QByteArray platform = "Windows NT 10.0; Win64; x64";
#elif defined(Q_OS_MACOS)
    const QByteArray platform = "Macintosh; Intel Mac OS X 10_15_7";
#else
    const QByteArray platform = "X11; Linux x86_64";
#endif
    // Como el de Chrome: solo la versión mayor, el resto a cero
    m_userAgent = "Mozilla/5.0 (" + platform + ") AppleWebKit/537.36 (KHTML, like Gecko) Chrome/"
        + major + ".0.0.0 Safari/537.36";
    m_brands = QByteArray(GreaseBrand) + R"(, "Chromium";v=")" + major
        + R"(", "Google Chrome";v=")" + major + '"';
    m_fullVersionList = QByteArray(GreaseFullBrand) + R"(, "Chromium";v=")" + full
        + R"(", "Google Chrome";v=")" + full + '"';
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
    if (doNotTrack) {
        info.setHttpHeader("DNT", "1");
        info.setHttpHeader("Sec-GPC", "1");
    }

    // Solo la página (marco principal): sus recursos http dentro de una
    // página https ya los sube o bloquea el propio motor
    const QUrl url = info.requestUrl();
    if (httpsUpgrade && url.scheme() == QLatin1String("http")
        && info.resourceType() == QWebEngineUrlRequestInfo::ResourceTypeMainFrame
        && info.requestMethod() == "GET") {
        const QString host = url.host();
        if (!isLocalHost(host) && !m_httpAllowed.contains(host)) {
            QUrl secure = url;
            secure.setScheme(QStringLiteral("https"));
            if (url.port() == 80)
                secure.setPort(-1);
            m_upgraded.insert(host);
            info.redirect(secure);
            return;
        }
    }

    if (!isGoogleSignIn(url) && !isGoogleSignIn(info.firstPartyUrl()))
        return;

    // Solo se reemplazan las que el motor ya envía: el Chrome real manda
    // sec-ch-ua siempre y la lista completa solo si la página la pidió
    info.setHttpHeader("User-Agent", m_userAgent);
    info.setHttpHeader("sec-ch-ua", m_brands);
    if (info.httpHeaders().contains("sec-ch-ua-full-version-list"))
        info.setHttpHeader("sec-ch-ua-full-version-list", m_fullVersionList);
}

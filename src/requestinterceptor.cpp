#include "requestinterceptor.h"

#include <QHash>
#include <QWebEngineUrlRequestInfo>
#include <QtWebEngineCore/qtwebenginecoreglobal.h>

namespace {
bool isGoogleSignIn(const QUrl &url)
{
    return url.host() == QLatin1String("accounts.google.com");
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

void RequestInterceptor::interceptRequest(QWebEngineUrlRequestInfo &info)
{
    if (!isGoogleSignIn(info.requestUrl()) && !isGoogleSignIn(info.firstPartyUrl()))
        return;

    // Solo se reemplazan las que el motor ya envía: el Chrome real manda
    // sec-ch-ua siempre y la lista completa solo si la página la pidió
    info.setHttpHeader("User-Agent", m_userAgent);
    info.setHttpHeader("sec-ch-ua", m_brands);
    if (info.httpHeaders().contains("sec-ch-ua-full-version-list"))
        info.setHttpHeader("sec-ch-ua-full-version-list", m_fullVersionList);
}

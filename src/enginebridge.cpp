#include "enginebridge.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QPointer>
#include <QSslCertificate>
#include <QSslCipher>
#include <QSslSocket>
#include <QTimer>
#include <QQmlEngine>
#include <QQuickWebEngineProfile>
#include <QWebEngineCookieStore>
#include <QtDebug>

#include "contentblocker.h"
#include "notifier.h"
#include "requestinterceptor.h"

#include <memory>

namespace {
// Un perfil con nombre de almacenamiento (vacío: sin disco). Qt 6.9 lo
// recibe en el constructor y así no arranca un instante sin disco; en 6.8,
// después de crearlo.
QQuickWebEngineProfile *newProfile(const QString &storageName, QObject *parent)
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 9, 0)
    return new QQuickWebEngineProfile(storageName, parent);
#else
    auto *profile = new QQuickWebEngineProfile(parent);
    if (!storageName.isEmpty()) {
        profile->setStorageName(storageName);
        profile->setOffTheRecord(false);
    }
    return profile;
#endif
}
}

EngineBridge::EngineBridge(const QString &widevinePath, QObject *parent)
    : QObject(parent)
    , m_blocker(new ContentBlocker(this))
    , m_interceptor(new RequestInterceptor(m_blocker, this))
    , m_widevinePath(widevinePath)
{
    connect(m_blocker, &ContentBlocker::stateChanged, this, &EngineBridge::adBlockStateChanged);
    connect(m_blocker, &ContentBlocker::blockedCountChanged, this, &EngineBridge::adBlockBlockedChanged);

    // En disco, en la carpeta de datos de Mitis (QtWebEngine/Mitis): la misma
    // que usaba el perfil creado en QML, así se conservan cookies y permisos
    m_profile = newProfile(QStringLiteral("Mitis"), this);
    m_profile->setHttpCacheType(QQuickWebEngineProfile::DiskHttpCache);
    m_profile->setPersistentCookiesPolicy(QQuickWebEngineProfile::AllowPersistentCookies);
    // Permisos concedidos o bloqueados (ubicación, notificaciones…): los
    // guarda el motor, por sitio. Cámara y micrófono: BrowserProfile.qml.
    m_profile->setPersistentPermissionsPolicy(QQuickWebEngineProfile::PersistentPermissionsPolicy::StoreOnDisk);
    installInterceptor(m_profile);

    // Notificaciones de las páginas: del sistema, no dentro de Mitis
    m_notifier = new SystemNotifier(this);
    connect(m_notifier, &SystemNotifier::activated, this, &EngineBridge::notificationActivated);
    m_notifier->attach(m_profile);
}

// Los perfiles se destruyen antes que la aplicación (main.cpp): después,
// Qt WebEngine se queda bloqueado al cerrar
EngineBridge::~EngineBridge()
{
    // Las notificaciones abiertas son del motor: se sueltan antes que el perfil
    delete m_notifier;
    delete m_profile;
}

QQuickWebEngineProfile *EngineBridge::createPrivateProfile()
{
    // Nombre de almacenamiento vacío: sin disco. (El constructor sin nombre
    // también lo haría, pero desde Qt 6.9 avisa de que quedará obsoleto.)
    auto *profile = newProfile(QString(), this);
    profile->setHttpCacheType(QQuickWebEngineProfile::MemoryHttpCache);
    profile->setPersistentCookiesPolicy(QQuickWebEngineProfile::NoPersistentCookies);
    profile->setPersistentPermissionsPolicy(QQuickWebEngineProfile::PersistentPermissionsPolicy::StoreInMemory);
    installInterceptor(profile);
    m_notifier->attach(profile);
    // Es de C++: QML no debe recogerlo como basura
    QQmlEngine::setObjectOwnership(profile, QQmlEngine::CppOwnership);
    return profile;
}

void EngineBridge::destroyPrivateProfile(QObject *profile)
{
    if (profile && profile != m_profile && profile->parent() == this)
        profile->deleteLater();
}

// Junto al ejecutable (Windows), en Contents/Resources (macOS) o en
// share/licenses/mitis (Linux)
QString EngineBridge::licensesPath() const
{
    const QDir app(QCoreApplication::applicationDirPath());
    const QStringList candidatas = {
        app.filePath(QStringLiteral("licencias")),
        app.filePath(QStringLiteral("../Resources/licencias")),
        app.filePath(QStringLiteral("../share/licenses/mitis")),
    };
    for (const QString &carpeta : candidatas) {
        if (QFileInfo(carpeta).isDir())
            return QDir::cleanPath(carpeta);
    }
    return QString();
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

bool EngineBridge::adBlock() const
{
    return m_blocker->isEnabled();
}

void EngineBridge::setAdBlock(bool value)
{
    if (m_blocker->isEnabled() == value)
        return;
    m_blocker->setEnabled(value);
    emit preferencesChanged();
}

void EngineBridge::setAdBlockAllowedSites(const QStringList &sites)
{
    if (m_adBlockAllowedSites == sites)
        return;
    m_adBlockAllowedSites = sites;
    m_blocker->setAllowedSites(sites);
    emit preferencesChanged();
}

bool EngineBridge::stripTrackingParams() const
{
    return m_blocker->stripTracking;
}

void EngineBridge::setStripTrackingParams(bool value)
{
    if (m_blocker->stripTracking == value)
        return;
    m_blocker->stripTracking = value;
    emit preferencesChanged();
}

int EngineBridge::adBlockRules() const
{
    return m_blocker->ruleCount();
}

QDateTime EngineBridge::adBlockUpdated() const
{
    return m_blocker->updated();
}

bool EngineBridge::adBlockUpdating() const
{
    return m_blocker->updating();
}

double EngineBridge::adBlockBlocked() const
{
    return double(m_blocker->blockedCount());
}

namespace {
// Motivo en español de un error de certificado (errorString() es inglés)
QString certificateProblem(const QSslError &error)
{
    switch (error.error()) {
    case QSslError::HostNameMismatch:
        return QStringLiteral("El certificado es de otro sitio.");
    case QSslError::CertificateExpired:
        return QStringLiteral("El certificado ha caducado.");
    case QSslError::CertificateNotYetValid:
        return QStringLiteral("El certificado aún no es válido.");
    case QSslError::SelfSignedCertificate:
    case QSslError::SelfSignedCertificateInChain:
        return QStringLiteral("El certificado lo firmó el propio sitio, no una entidad de confianza.");
    case QSslError::UnableToGetLocalIssuerCertificate:
    case QSslError::UnableToGetIssuerCertificate:
    case QSslError::UnableToVerifyFirstCertificate:
        return QStringLiteral("No se pudo comprobar quién emitió el certificado.");
    case QSslError::CertificateRevoked:
        return QStringLiteral("El certificado fue revocado.");
    default:
        return QStringLiteral("El certificado no es de confianza.");
    }
}

QString protocolName(QSsl::SslProtocol protocol)
{
    switch (protocol) {
    case QSsl::TlsV1_3:
        return QStringLiteral("TLS 1.3");
    case QSsl::TlsV1_2:
        return QStringLiteral("TLS 1.2");
    default:
        return QString();
    }
}
}

void EngineBridge::requestCertificate(const QString &host, int port)
{
    if (host.isEmpty())
        return;
    const QString key = host + QLatin1Char(':') + QString::number(port);
    if (m_certificates.contains(key)) {
        emit certificateReady(host, m_certificates.value(key));
        return;
    }

    auto *socket = new QSslSocket(this);
    socket->setPeerVerifyName(host);
    auto problems = std::make_shared<QStringList>();
    auto done = std::make_shared<bool>(false);
    QPointer<QSslSocket> guard(socket);

    // Una sola respuesta por consulta: conectado, fallo o tiempo agotado
    auto finish = [this, guard, host, key, problems, done](bool connected, const QString &failure) {
        if (*done || !guard)
            return;
        *done = true;
        QVariantMap info;
        if (connected) {
            const QSslCertificate certificate = guard->peerCertificate();
            info.insert(QStringLiteral("verified"), problems->isEmpty());
            info.insert(QStringLiteral("errors"), *problems);
            info.insert(QStringLiteral("subject"),
                        certificate.subjectInfo(QSslCertificate::CommonName).join(QStringLiteral(", ")));
            info.insert(QStringLiteral("subjectOrganization"),
                        certificate.subjectInfo(QSslCertificate::Organization).join(QStringLiteral(", ")));
            info.insert(QStringLiteral("issuer"),
                        certificate.issuerInfo(QSslCertificate::Organization).join(QStringLiteral(", ")));
            info.insert(QStringLiteral("issuerName"),
                        certificate.issuerInfo(QSslCertificate::CommonName).join(QStringLiteral(", ")));
            info.insert(QStringLiteral("validFrom"), certificate.effectiveDate());
            info.insert(QStringLiteral("validTo"), certificate.expiryDate());
            QStringList names = certificate.subjectAlternativeNames().values(QSsl::DnsEntry);
            info.insert(QStringLiteral("names"), names.mid(0, 8));
            info.insert(QStringLiteral("protocol"), protocolName(guard->sessionProtocol()));
            m_certificates.insert(key, info);
        } else {
            info.insert(QStringLiteral("error"), failure);
        }
        guard->abort();
        guard->deleteLater();
        emit certificateReady(host, info);
    };

    // Los errores se anotan y se sigue: aun así se quiere ver el certificado
    connect(socket, &QSslSocket::sslErrors, this, [socket, problems](const QList<QSslError> &errors) {
        for (const QSslError &error : errors) {
            const QString problem = certificateProblem(error);
            if (!problems->contains(problem))
                problems->append(problem);
        }
        socket->ignoreSslErrors();
    });
    connect(socket, &QSslSocket::encrypted, this, [finish] { finish(true, QString()); });
    connect(socket, &QAbstractSocket::errorOccurred, this, [finish](QAbstractSocket::SocketError) {
        finish(false, QStringLiteral("No se pudo conectar con el sitio para ver su certificado."));
    });
    QTimer::singleShot(8000, socket, [finish] {
        finish(false, QStringLiteral("El sitio tardó demasiado en responder."));
    });
    socket->connectToHostEncrypted(host, quint16(port));
}

void EngineBridge::updateFilterLists()
{
    m_blocker->update();
}

QString EngineBridge::cosmeticCss(const QUrl &url) const
{
    return m_blocker->cosmeticCss(url);
}

QString EngineBridge::siteOf(const QUrl &url) const
{
    return ContentBlocker::siteOf(url);
}

// Un solo interceptor para los dos perfiles
void EngineBridge::installInterceptor(QQuickWebEngineProfile *webProfile)
{
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

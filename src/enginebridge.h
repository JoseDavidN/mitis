#pragma once

#include <QDateTime>
#include <QObject>
#include <QQuickWebEngineProfile>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QHash>
#include <QVariantMap>

#include <atomic>

class ContentBlocker;
class SystemNotifier;
class RequestInterceptor;

// Lo que BrowserProfile.qml y BrowserTab.qml necesitan del motor y QML no
// ofrece: los perfiles (el normal, en disco, y el de las ventanas privadas),
// con su interceptor de peticiones y su filtro de cookies, y las
// preferencias de Configuración que estos aplican. Se publica en QML como la
// propiedad de contexto `MitisEngine` (no como tipo del módulo, que en
// --dev no existe).
class EngineBridge : public QObject
{
    Q_OBJECT
    // Biblioteca de Widevine que usa el motor; "" si no se encontró ninguna
    // (las páginas con contenido protegido no se podrán reproducir)
    Q_PROPERTY(QString widevinePath READ widevinePath CONSTANT)
    // Carpeta de licencias del paquete; vacía en una compilación sin instalar
    Q_PROPERTY(QString licensesPath READ licensesPath CONSTANT)
    // El perfil de navegación (cookies, caché, permisos en disco). Lo crea
    // C++ con su nombre de almacenamiento desde el principio: creado en QML,
    // Qt avisa de que quedará obsoleto y arranca un instante sin disco. Vive
    // toda la app (también entre recargas de --dev).
    Q_PROPERTY(QQuickWebEngineProfile *profile READ profile CONSTANT)
    // Preferencias que se aplican petición a petición (las enlaza BrowserProfile)
    Q_PROPERTY(bool blockThirdPartyCookies READ blockThirdPartyCookies WRITE setBlockThirdPartyCookies NOTIFY preferencesChanged)
    Q_PROPERTY(bool doNotTrack READ doNotTrack WRITE setDoNotTrack NOTIFY preferencesChanged)
    Q_PROPERTY(bool httpsUpgrade READ httpsUpgrade WRITE setHttpsUpgrade NOTIFY preferencesChanged)

    // ── Bloqueador de anuncios y rastreadores (ContentBlocker) ──
    Q_PROPERTY(bool adBlock READ adBlock WRITE setAdBlock NOTIFY preferencesChanged)
    // Sitios (dominio registrable) donde no se bloquea nada
    Q_PROPERTY(QStringList adBlockAllowedSites READ adBlockAllowedSites WRITE setAdBlockAllowedSites NOTIFY preferencesChanged)
    // Quitar utm_…, fbclid… de las direcciones que se abren
    Q_PROPERTY(bool stripTrackingParams READ stripTrackingParams WRITE setStripTrackingParams NOTIFY preferencesChanged)
    // Reglas cargadas (0: aún no hay listas)
    Q_PROPERTY(int adBlockRules READ adBlockRules NOTIFY adBlockStateChanged)
    // Descarga de las listas (inválida si no se han descargado nunca)
    Q_PROPERTY(QDateTime adBlockUpdated READ adBlockUpdated NOTIFY adBlockStateChanged)
    // Descargando o compilando las listas
    Q_PROPERTY(bool adBlockUpdating READ adBlockUpdating NOTIFY adBlockStateChanged)
    // Peticiones bloqueadas desde que se abrió Mitis
    Q_PROPERTY(double adBlockBlocked READ adBlockBlocked NOTIFY adBlockBlockedChanged)

public:
    explicit EngineBridge(const QString &widevinePath, QObject *parent = nullptr);
    ~EngineBridge() override;

    QQuickWebEngineProfile *profile() const { return m_profile; }
    // Perfil de las ventanas privadas: solo en memoria. Lo crea BrowserProfile
    // con la primera ventana privada y lo devuelve al cerrar la última.
    Q_INVOKABLE QQuickWebEngineProfile *createPrivateProfile();
    Q_INVOKABLE void destroyPrivateProfile(QObject *profile);

    QString widevinePath() const { return m_widevinePath; }
    QString licensesPath() const;
    bool blockThirdPartyCookies() const { return m_blockThirdPartyCookies; }
    void setBlockThirdPartyCookies(bool value);
    bool doNotTrack() const;
    void setDoNotTrack(bool value);
    bool httpsUpgrade() const;
    void setHttpsUpgrade(bool value);
    bool adBlock() const;
    void setAdBlock(bool value);
    QStringList adBlockAllowedSites() const { return m_adBlockAllowedSites; }
    void setAdBlockAllowedSites(const QStringList &sites);
    bool stripTrackingParams() const;
    void setStripTrackingParams(bool value);
    int adBlockRules() const;
    QDateTime adBlockUpdated() const;
    bool adBlockUpdating() const;
    double adBlockBlocked() const;
    // Certificado del sitio para el panel del sitio: Mitis abre su propia
    // conexión TLS con él (solo al pedirlo) y responde con certificateReady
    Q_INVOKABLE void requestCertificate(const QString &host, int port = 443);

    // Descarga ahora las listas de filtros
    Q_INVOKABLE void updateFilterLists();
    // CSS que oculta los huecos de anuncios en la página `url` ("" si nada)
    Q_INVOKABLE QString cosmeticCss(const QUrl &url) const;
    // Sitio de una dirección para permitir anuncios ("https://www.a.com/x" → "a.com")
    Q_INVOKABLE QString siteOf(const QUrl &url) const;

    // Borra todas las cookies del perfil (QML no llega a su almacén)
    Q_INVOKABLE void clearCookies(QObject *profile);
    // Falló la carga de `url`: true si era una página subida de http a https,
    // que entonces hay que volver a pedir por http (ver RequestInterceptor)
    Q_INVOKABLE bool takeHttpsFallback(const QUrl &url);
    // `url` es una página que Mitis subió de http a https (el usuario no pidió https)
    Q_INVOKABLE bool isHttpsUpgrade(const QUrl &url) const;
    // La página `url` cargó bien
    Q_INVOKABLE void confirmHttps(const QUrl &url);

signals:
    void preferencesChanged();
    void adBlockStateChanged();
    void adBlockBlockedChanged();
    // El usuario pulsó una notificación del sistema del sitio `origin`
    // (src/notifier.*): Main.qml trae al frente su pestaña
    void notificationActivated(const QUrl &origin);
    // { verified, errors: [texto], subject, subjectOrganization, issuer,
    //   issuerName, validFrom, validTo, names: [dominios], protocol } o
    // { error: texto } si no se pudo conectar
    void certificateReady(const QString &host, const QVariantMap &certificate);

private:
    // Interceptor de peticiones y filtro de cookies
    void installInterceptor(QQuickWebEngineProfile *profile);

    ContentBlocker *m_blocker;
    SystemNotifier *m_notifier;
    RequestInterceptor *m_interceptor;
    QStringList m_adBlockAllowedSites;
    // Certificados ya consultados en esta sesión ("host:puerto" → datos)
    QHash<QString, QVariantMap> m_certificates;
    QQuickWebEngineProfile *m_profile = nullptr;
    QString m_widevinePath;
    // Lo lee el filtro de cookies, que el motor puede llamar desde otro hilo
    std::atomic<bool> m_blockThirdPartyCookies { false };
};

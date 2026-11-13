#pragma once

#include <QDateTime>
#include <QObject>
#include <QRandomGenerator>
#include <QQuickWebEngineProfile>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QHash>
#include <QVariantMap>

#include <atomic>

class ContentBlocker;
class SystemNotifier;
class ScreenCapture;
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
    // Clave al azar de los avisos del gestor de contraseñas en las páginas
    // (BrowserProfile.passwordPrefix); una por arranque
    Q_PROPERTY(QString passwordToken READ passwordToken CONSTANT)
    // Linux con un gestor de ventanas en mosaico (Hyprland, Sway, i3, niri,
    // River): él coloca y cierra las ventanas con el teclado, así que sobran
    // la barra de título y los bordes de redimensionar. Lo mira Main.qml
    Q_PROPERTY(bool tilingDesktop READ tilingDesktop CONSTANT)
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

    // Proxy SOCKS5 y DNS cifrado de las páginas (Configuración → Privacidad),
    // para todos los perfiles. Se aplican al momento: main.cpp al arrancar
    // (antes de crear los perfiles) y BrowserProfile en cada cambio. Solo
    // hacen algo si lo elegido cambió
    static void applyProxy();
    static void applySecureDns();
    Q_INVOKABLE void updateNetworkSettings() const;

    // Reiniciar Mitis, para los ajustes que el motor solo lee al arrancar
    // (vídeo por la GPU, páginas de «atrás al instante»): emite restarting,
    // Main.qml se cierra guardando la sesión y main.cpp lo vuelve a abrir
    // (relaunchIfRequested), con las mismas pestañas
    Q_INVOKABLE void restart();
    static void relaunchIfRequested();

    // Compartir pantalla propio (ScreenCapture: Wayland sin el portal). Si no
    // está disponible, las páginas usan el getDisplayMedia del motor
    Q_INVOKABLE bool screenCaptureAvailable();
    // { screens: [{ id, name, detail }], windows: [...] }
    Q_INVOKABLE QVariantMap screenCaptureSources();
    // Clave de la sesión para la página `page` ("" si no se pudo empezar)
    Q_INVOKABLE QString startScreenCapture(const QString &kind, quint32 id, const QUrl &page);
    Q_INVOKABLE void stopScreenCapture(const QString &token);

    // Llaves de acceso con el móvil (src/hybrid.*, solo Linux; en Windows y
    // macOS las atiende el sistema). Ver assets/scripts/webauthn.js
    Q_INVOKABLE bool passkeysAvailable() const;
    // { session, qr } o { error }: `optionsJson`, el publicKey de la página
    Q_INVOKABLE QVariantMap startPasskey(const QString &kind, const QString &optionsJson, const QUrl &page);
    Q_INVOKABLE void cancelPasskey(int session);
    Q_INVOKABLE void passkeyBluetoothOn(int session);
    // Módulos de un código QR: { size, modules: "0101…" (fila a fila) }
    Q_INVOKABLE QVariantMap qrCode(const QString &text) const;

    QString widevinePath() const { return m_widevinePath; }
    QString licensesPath() const;
    QString passwordToken() const { return m_passwordToken; }
    static bool tilingDesktop();
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
    // Con qué dibuja la ventana: "Metal", "Direct3D 11", "Direct3D 12",
    // "Vulkan", "OpenGL", "software" o "" si aún no se sabe. Lo pregunta a la
    // ventana (o, sin ella, el que usaría Qt). GraphicsInfo de QML da
    // «desconocido» hasta que la ventana ha dibujado y no sirve para esto
    Q_INVOKABLE QString graphicsApi(QObject *window) const;
    // Esquinas redondeadas de la ventana, como las del sistema (Windows 11,
    // macOS); rectas con `rounded` en falso (maximizada, pantalla completa)
    Q_INVOKABLE void setRoundedCorners(QObject *window, bool rounded) const;
    // Minimiza conservando si estaba maximizada. showMinimized() lo borra: en
    // Windows, Qt quita entonces la marca de volver maximizada y, al
    // restaurarla, la ventana sin marco queda sin maximizar y mal de tamaño
    Q_INVOKABLE void minimizeWindow(QObject *window) const;
    // Una página abierta con window.open nace con la vista de la pestaña que
    // la abrió y Qt (6.11) la sigue usando para siempre sin comprobar que
    // exista: cerrada esa pestaña, mover el ratón sobre la nueva tumbaba a
    // Mitis. Al cerrarse la que abrió, BrowserTab le pasa aquí su vista y la
    // lista de pestañas que abrió: la vista se queda, fuera de la ventana y
    // en about:blank (sin la página), hasta que se cierren todas.
    Q_INVOKABLE void keepOpenerView(QObject *view, const QVariantList &openedTabs);

    // Descarga ahora las listas de filtros
    Q_INVOKABLE void updateFilterLists();
    // CSS que oculta los huecos de anuncios en la página `url` ("" si nada).
    // `strict`: de una ventana privada (siempre, sin sitios permitidos)
    Q_INVOKABLE QString cosmeticCss(const QUrl &url, bool strict = false) const;
    // Scriptlets de uBlock Origin para la página `url`: el código listo para
    // inyectar en el mundo de la página (assets/scripts/scriptlets.js con las
    // reglas del sitio) o "" si el sitio no tiene ninguno
    Q_INVOKABLE QString scriptlets(const QUrl &url, bool strict = false) const;
    // Sitio de una dirección para permitir anuncios ("https://www.a.com/x" → "a.com")
    Q_INVOKABLE QString siteOf(const QUrl &url) const;

    // Cuánto ocupa en disco la caché del perfil normal: lo mide en otro hilo
    // y responde con cacheUsageReady(bytes)
    Q_INVOKABLE void requestCacheUsage();

    // Borra todas las cookies del perfil (QML no llega a su almacén)
    Q_INVOKABLE void clearCookies(QObject *profile);
    // Falló la carga de `url`: true si era una página subida de http a https,
    // que entonces hay que volver a pedir por http (ver RequestInterceptor)
    Q_INVOKABLE bool takeHttpsFallback(const QUrl &url, bool privateProfile = false);
    // `url` es una página que Mitis subió de http a https (el usuario no pidió https)
    Q_INVOKABLE bool isHttpsUpgrade(const QUrl &url, bool privateProfile = false) const;
    // La página `url` cargó bien
    Q_INVOKABLE void confirmHttps(const QUrl &url, bool privateProfile = false);

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
    void cacheUsageReady(double bytes);
    // Se pidió reiniciar (restart): la interfaz se cierra guardando la sesión
    void restarting();
    // Una captura de pantalla propia terminó por su cuenta (ventana cerrada,
    // página que ya no pide fotogramas): BrowserTab la olvida
    void screenCaptureEnded(const QString &token);
    // Llave de acceso con el móvil: "scanning", "bluetoothOff", "noBluetooth",
    // "connecting", "confirm"; y el final ({ ok, … } o { error, message })
    void passkeyState(int session, const QString &state);
    void passkeyFinished(int session, const QVariantMap &result);

private:
    RequestInterceptor *interceptorFor(bool privateProfile) const;
    // Interceptor de peticiones y filtro de cookies
    void installInterceptor(QQuickWebEngineProfile *profile, RequestInterceptor *interceptor, bool strict);

    ContentBlocker *m_blocker;
    SystemNotifier *m_notifier;
    ScreenCapture *m_screenCapture;
    QHash<int, QObject *> m_passkeys;
    int m_nextPasskey = 1;
    RequestInterceptor *m_interceptor;
    // El del perfil privado: privacidad siempre activa (existe con él)
    RequestInterceptor *m_privateInterceptor = nullptr;
    QStringList m_adBlockAllowedSites;
    // Certificados ya consultados en esta sesión ("host:puerto" → datos)
    QHash<QString, QVariantMap> m_certificates;
    QQuickWebEngineProfile *m_profile = nullptr;
    QString m_widevinePath;
    const QString m_passwordToken = QString::number(QRandomGenerator::system()->generate64(), 36)
                                    + QString::number(QRandomGenerator::system()->generate64(), 36);
    // Lo lee el filtro de cookies, que el motor puede llamar desde otro hilo
    std::atomic<bool> m_blockThirdPartyCookies { false };
};

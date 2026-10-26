#pragma once

#include <QObject>
#include <QSettings>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

// Ajustes de Mitis, guardados entre sesiones con QSettings (en Linux,
// ~/.config/Mitis/Mitis.conf). En QML es el singleton `Settings` del módulo
// Mitis.Core. Las preferencias que muestra la página de Configuración son
// propiedades (se pueden enlazar); los datos internos (listado de descargas,
// permisos de cámara y micrófono) van por value()/setValue().
//
// Las claves son las que usaba Settings de QtCore ("Categoría/nombre"): lo ya
// guardado se conserva.
class Settings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Buscador elegido: clave de SearchEngines ("duckduckgo", "google"…) o "custom"
    Q_PROPERTY(QString searchEngine READ searchEngine WRITE setSearchEngine NOTIFY searchEngineChanged)
    // Buscador personalizado: nombre y plantilla con %s ("" si no hay)
    Q_PROPERTY(QString searchCustomName READ searchCustomName WRITE setSearchCustomName NOTIFY searchCustomNameChanged)
    Q_PROPERTY(QString searchCustomUrl READ searchCustomUrl WRITE setSearchCustomUrl NOTIFY searchCustomUrlChanged)
    // Página de nueva pestaña: URL de la imagen de fondo ("" = la del tema)
    Q_PROPERTY(QString newTabBackground READ newTabBackground WRITE setNewTabBackground NOTIFY newTabBackgroundChanged)
    // Accesos rápidos en JSON: [{ name, url }]; "" = nunca guardados (los de serie)
    Q_PROPERTY(QString quickLinks READ quickLinks WRITE setQuickLinks NOTIFY quickLinksChanged)
    // Carpeta de descargas ("" = la del sistema)
    Q_PROPERTY(QString downloadFolder READ downloadFolder WRITE setDownloadFolder NOTIFY downloadFolderChanged)
    // Herramientas de desarrollo: «Inspeccionar» y F12. Desactivadas de serie
    Q_PROPERTY(bool devTools READ devTools WRITE setDevTools NOTIFY devToolsChanged)
    // Monitor de rendimiento: el panel de memoria, CPU y GPU. Desactivado de serie
    Q_PROPERTY(bool performanceMonitor READ performanceMonitor WRITE setPerformanceMonitor NOTIFY performanceMonitorChanged)
    // Al abrir Mitis: "restore" (las pestañas de la última vez, de serie),
    // "newtab" (una página de nueva pestaña) o "page" (startupUrl)
    Q_PROPERTY(QString startupMode READ startupMode WRITE setStartupMode NOTIFY startupModeChanged)
    Q_PROPERTY(QString startupUrl READ startupUrl WRITE setStartupUrl NOTIFY startupUrlChanged)

    // ── Apariencia de las páginas ──
    // Zoom con el que abren las páginas (1 = 100 %)
    Q_PROPERTY(double defaultZoom READ defaultZoom WRITE setDefaultZoom NOTIFY defaultZoomChanged)
    // Oscurecer las páginas claras (lo hace el motor)
    Q_PROPERTY(bool darkPages READ darkPages WRITE setDarkPages NOTIFY darkPagesChanged)
    // Ocultar las barras de desplazamiento de las páginas (se sigue desplazando)
    Q_PROPERTY(bool hideScrollbars READ hideScrollbars WRITE setHideScrollbars NOTIFY hideScrollbarsChanged)
    // Atrás y adelante con los botones laterales del ratón y los gestos de
    // macOS (NavigationGestures); encendido por defecto
    Q_PROPERTY(bool navigationGestures READ navigationGestures WRITE setNavigationGestures NOTIFY navigationGesturesChanged)
    // Precargar páginas: la del enlace bajo el ratón (preload.js) y los
    // nombres de dominio de los enlaces (motor). Apagada por defecto: gasta
    // datos y avisa a los sitios de por dónde pasa el ratón
    Q_PROPERTY(bool preloadPages READ preloadPages WRITE setPreloadPages NOTIFY preloadPagesChanged)
    // Corrector ortográfico en español al escribir en las páginas; encendido por defecto
    Q_PROPERTY(bool spellCheck READ spellCheck WRITE setSpellCheck NOTIFY spellCheckChanged)
    // Experimental: controles de vidrio esmerilado (Glass), apagado por defecto
    Q_PROPERTY(bool glassEffect READ glassEffect WRITE setGlassEffect NOTIFY glassEffectChanged)
    // Tono morado del velo del vidrio: 0 lavanda, 1 violeta, 2 profundo
    Q_PROPERTY(int glassTone READ glassTone WRITE setGlassTone NOTIFY glassToneChanged)
    // Idiomas preferidos de las páginas, en orden ("es", "en"…)
    Q_PROPERTY(QStringList languages READ languages WRITE setLanguages NOTIFY languagesChanged)

    // ── Privacidad y seguridad ──
    Q_PROPERTY(bool blockThirdPartyCookies READ blockThirdPartyCookies WRITE setBlockThirdPartyCookies NOTIFY blockThirdPartyCookiesChanged)
    // Borrar cookies y caché al cerrar Mitis
    Q_PROPERTY(bool clearOnExit READ clearOnExit WRITE setClearOnExit NOTIFY clearOnExitChanged)
    // Pedir a los sitios que no rastreen (cabeceras DNT y Sec-GPC)
    Q_PROPERTY(bool doNotTrack READ doNotTrack WRITE setDoNotTrack NOTIFY doNotTrackChanged)
    // WebRTC (videollamadas) no revela la IP de la red local
    Q_PROPERTY(bool hideLocalIp READ hideLocalIp WRITE setHideLocalIp NOTIFY hideLocalIpChanged)
    // Abrir con https:// las direcciones http:// (si falla, se vuelve a http). Activado de serie
    Q_PROPERTY(bool httpsUpgrade READ httpsUpgrade WRITE setHttpsUpgrade NOTIFY httpsUpgradeChanged)
    // DNS cifrado (DNS sobre HTTPS) de las páginas: "off" (el del sistema),
    // "auto" (de serie: cifrado y, si no responde, el del sistema) o "secure"
    // (solo cifrado). El motor lo lee al arrancar (main.cpp): vale desde el
    // próximo arranque, y para todas las ventanas
    Q_PROPERTY(QString secureDns READ secureDns WRITE setSecureDns NOTIFY secureDnsChanged)
    // Servidor del DNS cifrado: clave de secureDnsProviders
    Q_PROPERTY(QString secureDnsProvider READ secureDnsProvider WRITE setSecureDnsProvider NOTIFY secureDnsProviderChanged)
    // Servidores que se pueden elegir: [{ key, name, detail }]
    Q_PROPERTY(QVariantList secureDnsProviders READ secureDnsProviders CONSTANT)
    // Lo elegido no es lo que usa el motor desde que arrancó: falta reiniciar
    Q_PROPERTY(bool secureDnsPending READ secureDnsPending NOTIFY secureDnsPendingChanged)

    // ── Contenido y permisos ──
    Q_PROPERTY(bool javascript READ javascript WRITE setJavascript NOTIFY javascriptChanged)
    Q_PROPERTY(bool images READ images WRITE setImages NOTIFY imagesChanged)
    // Ventanas emergentes que no abre un clic del usuario. Bloqueadas de serie
    Q_PROPERTY(bool blockPopups READ blockPopups WRITE setBlockPopups NOTIFY blockPopupsChanged)
    // Vídeo y audio que empiezan solos, sin que el usuario toque la página
    Q_PROPERTY(bool autoplay READ autoplay WRITE setAutoplay NOTIFY autoplayChanged)
    // Permisos que se deniegan sin preguntar: "location", "camera",
    // "microphone", "notifications", "clipboard", "screen"
    Q_PROPERTY(QStringList blockedPermissions READ blockedPermissions WRITE setBlockedPermissions NOTIFY blockedPermissionsChanged)

    // Perfil (solo en este equipo): nombre, foto (dirección file://) y color
    // del avatar (clave de Theme.avatarColors). Son datos del usuario, como
    // los permisos: resetPreferences() no los borra
    Q_PROPERTY(QString profileName READ profileName WRITE setProfileName NOTIFY profileNameChanged)
    Q_PROPERTY(QString profilePhoto READ profilePhoto WRITE setProfilePhoto NOTIFY profilePhotoChanged)
    Q_PROPERTY(QString profileColor READ profileColor WRITE setProfileColor NOTIFY profileColorChanged)

    // Tema de la interfaz: "nocturno" (de serie), "oscuro" o "claro" (Theme.qml)
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY themeChanged)

    // Bloquear anuncios y rastreadores, y quitar el rastreo de los enlaces
    Q_PROPERTY(bool blockAds READ blockAds WRITE setBlockAds NOTIFY blockAdsChanged)
    Q_PROPERTY(bool stripTrackingParams READ stripTrackingParams WRITE setStripTrackingParams NOTIFY stripTrackingParamsChanged)
    // Sitios (dominio registrable) donde el bloqueador no actúa. Es un dato
    // del usuario, como los permisos: resetPreferences() no lo borra
    Q_PROPERTY(QStringList adBlockAllowedSites READ adBlockAllowedSites WRITE setAdBlockAllowedSites NOTIFY adBlockAllowedSitesChanged)

    // Preguntar en qué carpeta guardar cada descarga
    Q_PROPERTY(bool askDownloadFolder READ askDownloadFolder WRITE setAskDownloadFolder NOTIFY askDownloadFolderChanged)
    // Minutos sin usar tras los que una pestaña se descarga de la memoria
    // (antes se congela); 0 = nunca se suspenden
    Q_PROPERTY(int suspendAfter READ suspendAfter WRITE setSuspendAfter NOTIFY suspendAfterChanged)
    // Espacio en disco para la caché de las páginas, en MB (0 = lo decide el
    // motor según el disco libre). 250 de serie
    Q_PROPERTY(int cacheSize READ cacheSize WRITE setCacheSize NOTIFY cacheSizeChanged)
    // Con la memoria del equipo justa, descargar antes las pestañas ocultas
    // (Main.relieveMemory). Encendido de serie: solo actúa cuando hace falta
    Q_PROPERTY(bool memorySaver READ memorySaver WRITE setMemorySaver NOTIFY memorySaverChanged)

public:
    explicit Settings(QObject *parent = nullptr);

    QString searchEngine() const;
    void setSearchEngine(const QString &value);
    QString searchCustomName() const;
    void setSearchCustomName(const QString &value);
    QString searchCustomUrl() const;
    void setSearchCustomUrl(const QString &value);
    QString newTabBackground() const;
    void setNewTabBackground(const QString &value);
    QString quickLinks() const;
    void setQuickLinks(const QString &value);
    QString downloadFolder() const;
    void setDownloadFolder(const QString &value);
    bool devTools() const;
    void setDevTools(bool value);
    bool performanceMonitor() const;
    void setPerformanceMonitor(bool value);
    QString startupMode() const;
    void setStartupMode(const QString &value);
    QString startupUrl() const;
    void setStartupUrl(const QString &value);
    double defaultZoom() const;
    void setDefaultZoom(double value);
    bool darkPages() const;
    void setDarkPages(bool value);
    bool hideScrollbars() const;
    void setHideScrollbars(bool value);
    bool preloadPages() const;
    void setPreloadPages(bool value);
    bool spellCheck() const;
    void setSpellCheck(bool value);
    bool navigationGestures() const;
    void setNavigationGestures(bool value);
    bool glassEffect() const;
    void setGlassEffect(bool value);
    int glassTone() const;
    void setGlassTone(int value);
    QStringList languages() const;
    void setLanguages(const QStringList &value);
    bool blockThirdPartyCookies() const;
    void setBlockThirdPartyCookies(bool value);
    bool clearOnExit() const;
    void setClearOnExit(bool value);
    bool doNotTrack() const;
    void setDoNotTrack(bool value);
    bool hideLocalIp() const;
    void setHideLocalIp(bool value);
    bool httpsUpgrade() const;
    void setHttpsUpgrade(bool value);
    bool javascript() const;
    void setJavascript(bool value);
    bool images() const;
    void setImages(bool value);
    bool blockPopups() const;
    void setBlockPopups(bool value);
    bool autoplay() const;
    void setAutoplay(bool value);
    QStringList blockedPermissions() const;
    void setBlockedPermissions(const QStringList &value);
    QString profileName() const;
    void setProfileName(const QString &value);
    QString profilePhoto() const;
    void setProfilePhoto(const QString &value);
    QString profileColor() const;
    void setProfileColor(const QString &value);
    QString theme() const;
    void setTheme(const QString &value);
    bool blockAds() const;
    void setBlockAds(bool value);
    bool stripTrackingParams() const;
    void setStripTrackingParams(bool value);
    QStringList adBlockAllowedSites() const;
    void setAdBlockAllowedSites(const QStringList &value);
    bool askDownloadFolder() const;
    void setAskDownloadFolder(bool value);
    int suspendAfter() const;
    void setSuspendAfter(int value);
    int cacheSize() const;
    void setCacheSize(int value);
    bool memorySaver() const;
    void setMemorySaver(bool value);
    QString secureDns() const;
    void setSecureDns(const QString &value);
    QString secureDnsProvider() const;
    void setSecureDnsProvider(const QString &value);
    QVariantList secureDnsProviders() const;
    bool secureDnsPending() const;

    // Para main.cpp, antes de crear los perfiles: dirección (plantilla de
    // DNS sobre HTTPS) del servidor elegido y, una vez aplicado, con qué
    // modo y servidor arrancó el motor ("off" si con el del sistema)
    static QString secureDnsTemplate(const QString &provider);
    static void setSecureDnsStarted(const QString &modeAndProvider);

    // Valor de `key` ("Categoría/nombre") o `defaultValue` si no está guardado
    Q_INVOKABLE QVariant value(const QString &key, const QVariant &defaultValue = {}) const;
    Q_INVOKABLE void setValue(const QString &key, const QVariant &value);
    // Vuelve las preferencias a sus valores de serie. Los datos (accesos
    // rápidos, buscador personalizado, sesión, descargas, permisos) se conservan
    Q_INVOKABLE void resetPreferences();

signals:
    void searchEngineChanged();
    void searchCustomNameChanged();
    void searchCustomUrlChanged();
    void newTabBackgroundChanged();
    void quickLinksChanged();
    void downloadFolderChanged();
    void devToolsChanged();
    void performanceMonitorChanged();
    void startupModeChanged();
    void startupUrlChanged();
    void defaultZoomChanged();
    void darkPagesChanged();
    void hideScrollbarsChanged();
    void navigationGesturesChanged();
    void spellCheckChanged();
    void preloadPagesChanged();
    void glassEffectChanged();
    void glassToneChanged();
    void languagesChanged();
    void blockThirdPartyCookiesChanged();
    void clearOnExitChanged();
    void doNotTrackChanged();
    void hideLocalIpChanged();
    void httpsUpgradeChanged();
    void javascriptChanged();
    void imagesChanged();
    void blockPopupsChanged();
    void autoplayChanged();
    void blockedPermissionsChanged();
    void profileNameChanged();
    void profilePhotoChanged();
    void profileColorChanged();
    void themeChanged();
    void blockAdsChanged();
    void stripTrackingParamsChanged();
    void adBlockAllowedSitesChanged();
    void askDownloadFolderChanged();
    void suspendAfterChanged();
    void cacheSizeChanged();
    void memorySaverChanged();
    void secureDnsChanged();
    void secureDnsProviderChanged();
    void secureDnsPendingChanged();

private:
    // Guarda `value` en `key` y avisa si cambió
    bool store(const QString &key, const QVariant &value);
    // Lo mismo para un booleano (en el archivo es el texto "true")
    bool storeBool(const QString &key, bool value, bool defaultValue);
    bool flag(const QString &key, bool defaultValue) const;

    QSettings m_settings;
};

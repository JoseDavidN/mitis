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
    // Al abrir Mitis: "restore" (las pestañas de la última vez, de serie),
    // "newtab" (una página de nueva pestaña) o "page" (startupUrl)
    Q_PROPERTY(QString startupMode READ startupMode WRITE setStartupMode NOTIFY startupModeChanged)
    Q_PROPERTY(QString startupUrl READ startupUrl WRITE setStartupUrl NOTIFY startupUrlChanged)

    // ── Apariencia de las páginas ──
    // Zoom con el que abren las páginas (1 = 100 %)
    Q_PROPERTY(double defaultZoom READ defaultZoom WRITE setDefaultZoom NOTIFY defaultZoomChanged)
    // Oscurecer las páginas claras (lo hace el motor)
    Q_PROPERTY(bool darkPages READ darkPages WRITE setDarkPages NOTIFY darkPagesChanged)
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

    // Preguntar en qué carpeta guardar cada descarga
    Q_PROPERTY(bool askDownloadFolder READ askDownloadFolder WRITE setAskDownloadFolder NOTIFY askDownloadFolderChanged)

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
    QString startupMode() const;
    void setStartupMode(const QString &value);
    QString startupUrl() const;
    void setStartupUrl(const QString &value);
    double defaultZoom() const;
    void setDefaultZoom(double value);
    bool darkPages() const;
    void setDarkPages(bool value);
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
    bool askDownloadFolder() const;
    void setAskDownloadFolder(bool value);

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
    void startupModeChanged();
    void startupUrlChanged();
    void defaultZoomChanged();
    void darkPagesChanged();
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
    void askDownloadFolderChanged();

private:
    // Guarda `value` en `key` y avisa si cambió
    bool store(const QString &key, const QVariant &value);
    // Lo mismo para un booleano (en el archivo es el texto "true")
    bool storeBool(const QString &key, bool value, bool defaultValue);
    bool flag(const QString &key, bool defaultValue) const;

    QSettings m_settings;
};

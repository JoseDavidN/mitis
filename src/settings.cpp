#include "settings.h"

namespace {
const QString SearchEngineKey = QStringLiteral("Search/engine");
const QString SearchCustomNameKey = QStringLiteral("Search/customName");
const QString SearchCustomUrlKey = QStringLiteral("Search/customUrl");
const QString NewTabBackgroundKey = QStringLiteral("NewTab/background");
const QString QuickLinksKey = QStringLiteral("NewTab/quickLinks");
const QString DownloadFolderKey = QStringLiteral("Downloads/folder");
const QString DevToolsKey = QStringLiteral("Developer/tools");
// De versiones anteriores: solo se lee, para el valor de serie de StartupModeKey
const QString RestoreSessionKey = QStringLiteral("Session/restore");
const QString StartupModeKey = QStringLiteral("Startup/mode");
const QString StartupUrlKey = QStringLiteral("Startup/url");
const QString DefaultZoomKey = QStringLiteral("Pages/zoom");
const QString DarkPagesKey = QStringLiteral("Pages/dark");
const QString LanguagesKey = QStringLiteral("Pages/languages");
const QString BlockThirdPartyCookiesKey = QStringLiteral("Privacy/blockThirdPartyCookies");
const QString ClearOnExitKey = QStringLiteral("Privacy/clearOnExit");
const QString DoNotTrackKey = QStringLiteral("Privacy/doNotTrack");
const QString HideLocalIpKey = QStringLiteral("Privacy/hideLocalIp");
const QString HttpsUpgradeKey = QStringLiteral("Security/httpsUpgrade");
const QString JavascriptKey = QStringLiteral("Content/javascript");
const QString ImagesKey = QStringLiteral("Content/images");
const QString BlockPopupsKey = QStringLiteral("Content/blockPopups");
const QString AutoplayKey = QStringLiteral("Content/autoplay");
const QString BlockedPermissionsKey = QStringLiteral("Permissions/blocked");
const QString AskDownloadFolderKey = QStringLiteral("Downloads/askFolder");

const QStringList DefaultLanguages = { QStringLiteral("es"), QStringLiteral("en") };
}

// Sin argumentos, QSettings usa el nombre de la organización y de la
// aplicación (main.cpp): el mismo archivo que usaba Settings de QtCore
Settings::Settings(QObject *parent)
    : QObject(parent)
{
}

bool Settings::store(const QString &key, const QVariant &value)
{
    if (m_settings.value(key) == value)
        return false;
    m_settings.setValue(key, value);
    return true;
}

QString Settings::searchEngine() const
{
    return m_settings.value(SearchEngineKey, QStringLiteral("duckduckgo")).toString();
}

void Settings::setSearchEngine(const QString &value)
{
    if (store(SearchEngineKey, value))
        emit searchEngineChanged();
}

QString Settings::searchCustomName() const
{
    return m_settings.value(SearchCustomNameKey).toString();
}

void Settings::setSearchCustomName(const QString &value)
{
    if (store(SearchCustomNameKey, value))
        emit searchCustomNameChanged();
}

QString Settings::searchCustomUrl() const
{
    return m_settings.value(SearchCustomUrlKey).toString();
}

void Settings::setSearchCustomUrl(const QString &value)
{
    if (store(SearchCustomUrlKey, value))
        emit searchCustomUrlChanged();
}

QString Settings::newTabBackground() const
{
    return m_settings.value(NewTabBackgroundKey).toString();
}

void Settings::setNewTabBackground(const QString &value)
{
    if (store(NewTabBackgroundKey, value))
        emit newTabBackgroundChanged();
}

QString Settings::quickLinks() const
{
    return m_settings.value(QuickLinksKey).toString();
}

void Settings::setQuickLinks(const QString &value)
{
    if (store(QuickLinksKey, value))
        emit quickLinksChanged();
}

QString Settings::downloadFolder() const
{
    return m_settings.value(DownloadFolderKey).toString();
}

void Settings::setDownloadFolder(const QString &value)
{
    if (store(DownloadFolderKey, value))
        emit downloadFolderChanged();
}

bool Settings::storeBool(const QString &key, bool value, bool defaultValue)
{
    // Se compara el valor leído: en el archivo, un booleano es el texto "true"
    if (m_settings.value(key, defaultValue).toBool() == value)
        return false;
    m_settings.setValue(key, value);
    return true;
}

bool Settings::devTools() const
{
    return flag(DevToolsKey, false);
}

void Settings::setDevTools(bool value)
{
    if (storeBool(DevToolsKey, value, false))
        emit devToolsChanged();
}

bool Settings::flag(const QString &key, bool defaultValue) const
{
    return m_settings.value(key, defaultValue).toBool();
}

QString Settings::startupMode() const
{
    // Antes era solo «continuar donde lo dejaste» (sí o no)
    const QString legacy = flag(RestoreSessionKey, true) ? QStringLiteral("restore") : QStringLiteral("newtab");
    return m_settings.value(StartupModeKey, legacy).toString();
}

void Settings::setStartupMode(const QString &value)
{
    if (store(StartupModeKey, value))
        emit startupModeChanged();
}

QString Settings::startupUrl() const
{
    return m_settings.value(StartupUrlKey).toString();
}

void Settings::setStartupUrl(const QString &value)
{
    if (store(StartupUrlKey, value))
        emit startupUrlChanged();
}

double Settings::defaultZoom() const
{
    return m_settings.value(DefaultZoomKey, 1.0).toDouble();
}

void Settings::setDefaultZoom(double value)
{
    if (qFuzzyCompare(defaultZoom(), value))
        return;
    m_settings.setValue(DefaultZoomKey, value);
    emit defaultZoomChanged();
}

bool Settings::darkPages() const
{
    return flag(DarkPagesKey, false);
}

void Settings::setDarkPages(bool value)
{
    if (storeBool(DarkPagesKey, value, false))
        emit darkPagesChanged();
}

QStringList Settings::languages() const
{
    const QStringList value = m_settings.value(LanguagesKey, DefaultLanguages).toStringList();
    return value.isEmpty() ? DefaultLanguages : value;
}

void Settings::setLanguages(const QStringList &value)
{
    if (languages() == value)
        return;
    m_settings.setValue(LanguagesKey, value);
    emit languagesChanged();
}

bool Settings::blockThirdPartyCookies() const
{
    return flag(BlockThirdPartyCookiesKey, false);
}

void Settings::setBlockThirdPartyCookies(bool value)
{
    if (storeBool(BlockThirdPartyCookiesKey, value, false))
        emit blockThirdPartyCookiesChanged();
}

bool Settings::clearOnExit() const
{
    return flag(ClearOnExitKey, false);
}

void Settings::setClearOnExit(bool value)
{
    if (storeBool(ClearOnExitKey, value, false))
        emit clearOnExitChanged();
}

bool Settings::doNotTrack() const
{
    return flag(DoNotTrackKey, false);
}

void Settings::setDoNotTrack(bool value)
{
    if (storeBool(DoNotTrackKey, value, false))
        emit doNotTrackChanged();
}

bool Settings::hideLocalIp() const
{
    return flag(HideLocalIpKey, false);
}

void Settings::setHideLocalIp(bool value)
{
    if (storeBool(HideLocalIpKey, value, false))
        emit hideLocalIpChanged();
}

bool Settings::httpsUpgrade() const
{
    return flag(HttpsUpgradeKey, true);
}

void Settings::setHttpsUpgrade(bool value)
{
    if (storeBool(HttpsUpgradeKey, value, true))
        emit httpsUpgradeChanged();
}

bool Settings::javascript() const
{
    return flag(JavascriptKey, true);
}

void Settings::setJavascript(bool value)
{
    if (storeBool(JavascriptKey, value, true))
        emit javascriptChanged();
}

bool Settings::images() const
{
    return flag(ImagesKey, true);
}

void Settings::setImages(bool value)
{
    if (storeBool(ImagesKey, value, true))
        emit imagesChanged();
}

bool Settings::blockPopups() const
{
    return flag(BlockPopupsKey, true);
}

void Settings::setBlockPopups(bool value)
{
    if (storeBool(BlockPopupsKey, value, true))
        emit blockPopupsChanged();
}

bool Settings::autoplay() const
{
    return flag(AutoplayKey, false);
}

void Settings::setAutoplay(bool value)
{
    if (storeBool(AutoplayKey, value, false))
        emit autoplayChanged();
}

QStringList Settings::blockedPermissions() const
{
    return m_settings.value(BlockedPermissionsKey).toStringList();
}

void Settings::setBlockedPermissions(const QStringList &value)
{
    if (blockedPermissions() == value)
        return;
    m_settings.setValue(BlockedPermissionsKey, value);
    emit blockedPermissionsChanged();
}

bool Settings::askDownloadFolder() const
{
    return flag(AskDownloadFolderKey, false);
}

void Settings::setAskDownloadFolder(bool value)
{
    if (storeBool(AskDownloadFolderKey, value, false))
        emit askDownloadFolderChanged();
}

QVariant Settings::value(const QString &key, const QVariant &defaultValue) const
{
    return m_settings.value(key, defaultValue);
}

void Settings::setValue(const QString &key, const QVariant &value)
{
    m_settings.setValue(key, value);
}

void Settings::resetPreferences()
{
    const QStringList keys = {
        SearchEngineKey, NewTabBackgroundKey, DownloadFolderKey, DevToolsKey, RestoreSessionKey,
        StartupModeKey, StartupUrlKey, DefaultZoomKey, DarkPagesKey, LanguagesKey,
        BlockThirdPartyCookiesKey, ClearOnExitKey, DoNotTrackKey, HideLocalIpKey, HttpsUpgradeKey,
        JavascriptKey, ImagesKey, BlockPopupsKey, AutoplayKey, BlockedPermissionsKey, AskDownloadFolderKey,
    };
    for (const QString &key : keys)
        m_settings.remove(key);
    // Se avisa de todas: las enlazadas leen el valor de serie
    emit searchEngineChanged();
    emit newTabBackgroundChanged();
    emit downloadFolderChanged();
    emit devToolsChanged();
    emit startupModeChanged();
    emit startupUrlChanged();
    emit defaultZoomChanged();
    emit darkPagesChanged();
    emit languagesChanged();
    emit blockThirdPartyCookiesChanged();
    emit clearOnExitChanged();
    emit doNotTrackChanged();
    emit hideLocalIpChanged();
    emit httpsUpgradeChanged();
    emit javascriptChanged();
    emit imagesChanged();
    emit blockPopupsChanged();
    emit autoplayChanged();
    emit blockedPermissionsChanged();
    emit askDownloadFolderChanged();
}

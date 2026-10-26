#include "settings.h"

namespace {
const QString SearchEngineKey = QStringLiteral("Search/engine");
const QString SearchCustomNameKey = QStringLiteral("Search/customName");
const QString SearchCustomUrlKey = QStringLiteral("Search/customUrl");
const QString NewTabBackgroundKey = QStringLiteral("NewTab/background");
const QString QuickLinksKey = QStringLiteral("NewTab/quickLinks");
const QString DownloadFolderKey = QStringLiteral("Downloads/folder");
const QString DevToolsKey = QStringLiteral("Developer/tools");
const QString PerformanceMonitorKey = QStringLiteral("Developer/performanceMonitor");
// De versiones anteriores: solo se lee, para el valor de serie de StartupModeKey
const QString RestoreSessionKey = QStringLiteral("Session/restore");
const QString StartupModeKey = QStringLiteral("Startup/mode");
const QString StartupUrlKey = QStringLiteral("Startup/url");
const QString DefaultZoomKey = QStringLiteral("Pages/zoom");
const QString DarkPagesKey = QStringLiteral("Pages/dark");
const QString HideScrollbarsKey = QStringLiteral("Pages/hideScrollbars");
const QString NavigationGesturesKey = QStringLiteral("Pages/navigationGestures");
const QString SpellCheckKey = QStringLiteral("Pages/spellCheck");
const QString PreloadPagesKey = QStringLiteral("Pages/preload");
const QString GlassEffectKey = QStringLiteral("Appearance/glassEffect");
const QString GlassToneKey = QStringLiteral("Appearance/glassTone");
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
const QString ProfileNameKey = QStringLiteral("Profile/name");
const QString ProfilePhotoKey = QStringLiteral("Profile/photo");
const QString ProfileColorKey = QStringLiteral("Profile/color");
const QString ThemeKey = QStringLiteral("Appearance/theme");
const QString BlockAdsKey = QStringLiteral("Blocker/enabled");
const QString StripTrackingParamsKey = QStringLiteral("Blocker/stripParams");
const QString AdBlockAllowedSitesKey = QStringLiteral("Blocker/allowedSites");
const QString AskDownloadFolderKey = QStringLiteral("Downloads/askFolder");
const QString SuspendAfterKey = QStringLiteral("Performance/suspendAfter");
const QString CacheSizeKey = QStringLiteral("Performance/cacheSize");
const QString MemorySaverKey = QStringLiteral("Performance/memorySaver");
const QString ControlsRevealKey = QStringLiteral("Appearance/controlsReveal");
const QString SecureDnsKey = QStringLiteral("Privacy/secureDns");
const QString SecureDnsProviderKey = QStringLiteral("Privacy/secureDnsProvider");

// Servidores de DNS sobre HTTPS: conocidos, sin cuenta y con política de no
// guardar datos. AdGuard y el de Mullvad con filtro bloquean además anuncios
struct DnsProvider {
    const char *key;
    const char *name;
    const char *detail;
    const char *url;
};
const DnsProvider DnsProviders[] = {
    { "cloudflare", "Cloudflare", "1.1.1.1, el más rápido en la mayoría de sitios", "https://cloudflare-dns.com/dns-query" },
    { "quad9", "Quad9", "Bloquea además dominios de virus y estafas", "https://dns.quad9.net/dns-query" },
    { "mullvad", "Mullvad", "Sin filtros ni registros", "https://dns.mullvad.net/dns-query" },
    { "adguard", "AdGuard", "Bloquea además anuncios y rastreadores", "https://dns.adguard-dns.com/dns-query" },
};
// Con qué arrancó el motor ("modo:servidor" o "off"); vacío = aún no se sabe
QString secureDnsStarted;

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

bool Settings::performanceMonitor() const
{
    return flag(PerformanceMonitorKey, false);
}

void Settings::setPerformanceMonitor(bool value)
{
    if (storeBool(PerformanceMonitorKey, value, false))
        emit performanceMonitorChanged();
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

bool Settings::hideScrollbars() const
{
    return flag(HideScrollbarsKey, false);
}

void Settings::setHideScrollbars(bool value)
{
    if (storeBool(HideScrollbarsKey, value, false))
        emit hideScrollbarsChanged();
}

bool Settings::preloadPages() const
{
    return flag(PreloadPagesKey, false);
}

void Settings::setPreloadPages(bool value)
{
    if (storeBool(PreloadPagesKey, value, false))
        emit preloadPagesChanged();
}

bool Settings::spellCheck() const
{
    return flag(SpellCheckKey, true);
}

void Settings::setSpellCheck(bool value)
{
    if (storeBool(SpellCheckKey, value, true))
        emit spellCheckChanged();
    emit preloadPagesChanged();
}

bool Settings::navigationGestures() const
{
    return flag(NavigationGesturesKey, true);
}

void Settings::setNavigationGestures(bool value)
{
    if (storeBool(NavigationGesturesKey, value, true))
        emit navigationGesturesChanged();
}

bool Settings::glassEffect() const
{
    return flag(GlassEffectKey, false);
}

void Settings::setGlassEffect(bool value)
{
    if (storeBool(GlassEffectKey, value, false))
        emit glassEffectChanged();
}

int Settings::glassTone() const
{
    return qBound(0, m_settings.value(GlassToneKey, 1).toInt(), 2);
}

void Settings::setGlassTone(int value)
{
    value = qBound(0, value, 2);
    if (glassTone() == value)
        return;
    m_settings.setValue(GlassToneKey, value);
    emit glassToneChanged();
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

QString Settings::profileName() const
{
    return m_settings.value(ProfileNameKey).toString();
}

void Settings::setProfileName(const QString &value)
{
    if (store(ProfileNameKey, value.trimmed()))
        emit profileNameChanged();
}

QString Settings::profilePhoto() const
{
    return m_settings.value(ProfilePhotoKey).toString();
}

void Settings::setProfilePhoto(const QString &value)
{
    if (store(ProfilePhotoKey, value))
        emit profilePhotoChanged();
}

QString Settings::profileColor() const
{
    return m_settings.value(ProfileColorKey, QStringLiteral("violeta")).toString();
}

void Settings::setProfileColor(const QString &value)
{
    if (store(ProfileColorKey, value))
        emit profileColorChanged();
}

QString Settings::theme() const
{
    return m_settings.value(ThemeKey, QStringLiteral("nocturno")).toString();
}

void Settings::setTheme(const QString &value)
{
    if (store(ThemeKey, value))
        emit themeChanged();
}

bool Settings::blockAds() const
{
    return flag(BlockAdsKey, true);
}

void Settings::setBlockAds(bool value)
{
    if (storeBool(BlockAdsKey, value, true))
        emit blockAdsChanged();
}

bool Settings::stripTrackingParams() const
{
    return flag(StripTrackingParamsKey, true);
}

void Settings::setStripTrackingParams(bool value)
{
    if (storeBool(StripTrackingParamsKey, value, true))
        emit stripTrackingParamsChanged();
}

QStringList Settings::adBlockAllowedSites() const
{
    return m_settings.value(AdBlockAllowedSitesKey).toStringList();
}

void Settings::setAdBlockAllowedSites(const QStringList &value)
{
    if (adBlockAllowedSites() == value)
        return;
    m_settings.setValue(AdBlockAllowedSitesKey, value);
    emit adBlockAllowedSitesChanged();
}

bool Settings::askDownloadFolder() const
{
    return flag(AskDownloadFolderKey, false);
}

void Settings::setAskDownloadFolder(bool value)
{
    if (storeBool(AskDownloadFolderKey, value, false))
        emit askDownloadFolderChanged();
    emit suspendAfterChanged();
    emit blockAdsChanged();
    emit stripTrackingParamsChanged();
    emit themeChanged();
}

int Settings::suspendAfter() const
{
    return m_settings.value(SuspendAfterKey, 30).toInt();
}

void Settings::setSuspendAfter(int value)
{
    if (suspendAfter() == value)
        return;
    m_settings.setValue(SuspendAfterKey, value);
    emit suspendAfterChanged();
}

QVariant Settings::value(const QString &key, const QVariant &defaultValue) const
{
    return m_settings.value(key, defaultValue);
}

int Settings::cacheSize() const
{
    return qMax(0, m_settings.value(CacheSizeKey, 250).toInt());
}

void Settings::setCacheSize(int value)
{
    if (cacheSize() == value)
        return;
    m_settings.setValue(CacheSizeKey, value);
    emit cacheSizeChanged();
}

bool Settings::memorySaver() const
{
    return flag(MemorySaverKey, true);
}

void Settings::setMemorySaver(bool value)
{
    if (storeBool(MemorySaverKey, value, true))
        emit memorySaverChanged();
}

QString Settings::controlsReveal() const
{
    return m_settings.value(ControlsRevealKey).toString() == QLatin1String("hover") ? QStringLiteral("hover")
                                                                                   : QStringLiteral("click");
}

void Settings::setControlsReveal(const QString &value)
{
    if (controlsReveal() == value)
        return;
    m_settings.setValue(ControlsRevealKey, value);
    emit controlsRevealChanged();
}

QString Settings::secureDns() const
{
    // De serie, automático: cifrado y, si el servidor no responde, el del sistema
    const QString mode = m_settings.value(SecureDnsKey, QStringLiteral("auto")).toString();
    return mode == QLatin1String("off") || mode == QLatin1String("secure") ? mode : QStringLiteral("auto");
}

void Settings::setSecureDns(const QString &value)
{
    if (secureDns() == value)
        return;
    m_settings.setValue(SecureDnsKey, value);
    emit secureDnsChanged();
    emit secureDnsPendingChanged();
}

QString Settings::secureDnsProvider() const
{
    const QString key = m_settings.value(SecureDnsProviderKey).toString();
    return secureDnsTemplate(key).isEmpty() ? QString::fromLatin1(DnsProviders[0].key) : key;
}

void Settings::setSecureDnsProvider(const QString &value)
{
    if (secureDnsProvider() == value)
        return;
    m_settings.setValue(SecureDnsProviderKey, value);
    emit secureDnsProviderChanged();
    emit secureDnsPendingChanged();
}

QVariantList Settings::secureDnsProviders() const
{
    QVariantList list;
    for (const DnsProvider &provider : DnsProviders)
        list.append(QVariantMap{ { QStringLiteral("key"), QString::fromLatin1(provider.key) },
                                 { QStringLiteral("name"), QString::fromUtf8(provider.name) },
                                 { QStringLiteral("detail"), QString::fromUtf8(provider.detail) } });
    return list;
}

bool Settings::secureDnsPending() const
{
    if (secureDnsStarted.isEmpty())
        return false;
    const QString chosen = secureDns() == QLatin1String("off") ? QStringLiteral("off")
                                                               : secureDns() + u':' + secureDnsProvider();
    return chosen != secureDnsStarted;
}

QString Settings::secureDnsTemplate(const QString &provider)
{
    for (const DnsProvider &item : DnsProviders) {
        if (provider == QLatin1String(item.key))
            return QString::fromLatin1(item.url);
    }
    return {};
}

void Settings::setSecureDnsStarted(const QString &modeAndProvider)
{
    secureDnsStarted = modeAndProvider;
}

void Settings::setValue(const QString &key, const QVariant &value)
{
    m_settings.setValue(key, value);
}

void Settings::resetPreferences()
{
    const QStringList keys = {
        SearchEngineKey, NewTabBackgroundKey, DownloadFolderKey, DevToolsKey, PerformanceMonitorKey, RestoreSessionKey,
        StartupModeKey, StartupUrlKey, DefaultZoomKey, DarkPagesKey, HideScrollbarsKey, NavigationGesturesKey, SpellCheckKey, PreloadPagesKey, GlassEffectKey, GlassToneKey, LanguagesKey,
        BlockThirdPartyCookiesKey, ClearOnExitKey, DoNotTrackKey, HideLocalIpKey, HttpsUpgradeKey,
        JavascriptKey, ImagesKey, BlockPopupsKey, AutoplayKey, BlockedPermissionsKey, AskDownloadFolderKey,
        SuspendAfterKey, BlockAdsKey, StripTrackingParamsKey, ThemeKey, SecureDnsKey, SecureDnsProviderKey,
        CacheSizeKey, MemorySaverKey, ControlsRevealKey,
    };
    for (const QString &key : keys)
        m_settings.remove(key);
    // Se avisa de todas: las enlazadas leen el valor de serie
    emit searchEngineChanged();
    emit newTabBackgroundChanged();
    emit downloadFolderChanged();
    emit devToolsChanged();
    emit performanceMonitorChanged();
    emit startupModeChanged();
    emit startupUrlChanged();
    emit defaultZoomChanged();
    emit darkPagesChanged();
    emit hideScrollbarsChanged();
    emit navigationGesturesChanged();
    emit spellCheckChanged();
    emit glassEffectChanged();
    emit glassToneChanged();
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
    emit preloadPagesChanged();
    emit suspendAfterChanged();
    emit blockAdsChanged();
    emit stripTrackingParamsChanged();
    emit themeChanged();
    emit secureDnsChanged();
    emit secureDnsProviderChanged();
    emit secureDnsPendingChanged();
    emit cacheSizeChanged();
    emit memorySaverChanged();
    emit controlsRevealChanged();
}

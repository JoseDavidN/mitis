#include "widevine.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QList>
#include <QStringList>
#include <QVersionNumber>
#include <QtGlobal>

#include <utility>

namespace {

struct Candidate
{
    QString path;
    QVersionNumber version;
};

#if defined(Q_OS_WIN)
constexpr auto LibraryName = "widevinecdm.dll";
constexpr auto PlatformDir = "win_x64";
#elif defined(Q_OS_MACOS)
constexpr auto LibraryName = "libwidevinecdm.dylib";
#  if defined(Q_PROCESSOR_ARM)
constexpr auto PlatformDir = "mac_arm64";
#  else
constexpr auto PlatformDir = "mac_x64";
#  endif
#else
constexpr auto LibraryName = "libwidevinecdm.so";
#  if defined(Q_PROCESSOR_ARM)
constexpr auto PlatformDir = "linux_arm64";
#  else
constexpr auto PlatformDir = "linux_x64";
#  endif
#endif

// Dentro de una carpeta WidevineCdm de Chrome o Chromium
QString platformLibrary(const QString &cdmDir)
{
    return cdmDir + QStringLiteral("/_platform_specific/") + QLatin1String(PlatformDir)
         + QLatin1Char('/') + QLatin1String(LibraryName);
}

// Versión de una carpeta WidevineCdm según su manifest.json
// ("version": "4.10.2891.0"); sin él, 0
QVersionNumber manifestVersion(const QString &cdmDir)
{
    QFile manifest(cdmDir + QStringLiteral("/manifest.json"));
    if (!manifest.open(QIODevice::ReadOnly))
        return {};
    const QByteArray text = manifest.read(64 * 1024);
    const qsizetype key = text.indexOf("\"version\"");
    if (key < 0)
        return {};
    const qsizetype start = text.indexOf('"', text.indexOf(':', key)) + 1;
    const qsizetype end = text.indexOf('"', start);
    return QVersionNumber::fromString(QString::fromLatin1(text.mid(start, end - start)));
}

void addIfExists(QList<Candidate> &found, const QString &path, const QVersionNumber &version)
{
    if (QFileInfo(path).isFile())
        found.append({ QDir::cleanPath(path), version });
}

// Una carpeta WidevineCdm instalada con el navegador
void addCdmDir(QList<Candidate> &found, const QString &cdmDir)
{
    addIfExists(found, platformLibrary(cdmDir), manifestVersion(cdmDir));
}

// Carpetas con una subcarpeta por versión: la que el navegador actualiza solo
// (…/WidevineCdm/4.10.2891.0/) o la de Firefox (…/gmp-widevinecdm/4.10.2891.0/)
void addVersionDirs(QList<Candidate> &found, const QString &parent, bool firefox)
{
    const QDir dir(parent);
    const auto versions = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &name : versions) {
        const QString versionDir = dir.filePath(name);
        const QString library = firefox ? versionDir + QLatin1Char('/') + QLatin1String(LibraryName)
                                        : platformLibrary(versionDir);
        addIfExists(found, library, QVersionNumber::fromString(name));
    }
}

// Firefox: un gmp-widevinecdm por perfil
void addFirefoxProfiles(QList<Candidate> &found, const QString &profilesDir)
{
    const QDir dir(profilesDir);
    const auto profiles = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &profile : profiles)
        addVersionDirs(found, dir.filePath(profile) + QStringLiteral("/gmp-widevinecdm"), true);
}

// Chrome en Windows y macOS guarda la suya junto a cada versión instalada:
// …/Application/141.0.7390.65/WidevineCdm
void addChromeVersions(QList<Candidate> &found, const QString &parent, const QString &suffix)
{
    const QDir dir(parent);
    const auto versions = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &name : versions) {
        if (!QVersionNumber::fromString(name).isNull())
            addCdmDir(found, dir.filePath(name) + suffix);
    }
}

} // namespace

QString Widevine::find()
{
    QList<Candidate> found;
    const QString home = QDir::homePath();

#if defined(Q_OS_WIN)
    const QString programFiles = qEnvironmentVariable("ProgramFiles");
    const QString programFilesX86 = qEnvironmentVariable("ProgramFiles(x86)");
    const QString localAppData = qEnvironmentVariable("LOCALAPPDATA");
    const QString appData = qEnvironmentVariable("APPDATA");
    for (const QString &base : { programFiles, programFilesX86, localAppData }) {
        if (base.isEmpty())
            continue;
        addChromeVersions(found, base + QStringLiteral("/Google/Chrome/Application"), QStringLiteral("/WidevineCdm"));
        addChromeVersions(found, base + QStringLiteral("/Microsoft/Edge/Application"), QStringLiteral("/WidevineCdm"));
    }
    if (!localAppData.isEmpty()) {
        addVersionDirs(found, localAppData + QStringLiteral("/Google/Chrome/User Data/WidevineCdm"), false);
        addVersionDirs(found, localAppData + QStringLiteral("/Chromium/User Data/WidevineCdm"), false);
    }
    if (!appData.isEmpty())
        addFirefoxProfiles(found, appData + QStringLiteral("/Mozilla/Firefox/Profiles"));
#elif defined(Q_OS_MACOS)
    for (const QString &apps : { QStringLiteral("/Applications"), home + QStringLiteral("/Applications") }) {
        addChromeVersions(found,
                          apps + QStringLiteral("/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions"),
                          QStringLiteral("/Libraries/WidevineCdm"));
    }
    const QString support = home + QStringLiteral("/Library/Application Support");
    addVersionDirs(found, support + QStringLiteral("/Google/Chrome/WidevineCdm"), false);
    addVersionDirs(found, support + QStringLiteral("/Chromium/WidevineCdm"), false);
    addFirefoxProfiles(found, support + QStringLiteral("/Firefox/Profiles"));
#else
    // Instalada con el navegador (paquetes de Chrome, chromium-widevine de Arch…)
    for (const QString &dir : { QStringLiteral("/opt/google/chrome/WidevineCdm"),
                                QStringLiteral("/opt/google/chrome-beta/WidevineCdm"),
                                QStringLiteral("/opt/google/chrome-unstable/WidevineCdm"),
                                QStringLiteral("/usr/lib/chromium/WidevineCdm"),
                                QStringLiteral("/usr/lib/chromium-browser/WidevineCdm"),
                                QStringLiteral("/usr/lib64/chromium/WidevineCdm") }) {
        addCdmDir(found, dir);
    }
    // La que Chrome y Chromium descargan y actualizan por su cuenta
    const QString config = qEnvironmentVariable("XDG_CONFIG_HOME", home + QStringLiteral("/.config"));
    addVersionDirs(found, config + QStringLiteral("/google-chrome/WidevineCdm"), false);
    addVersionDirs(found, config + QStringLiteral("/chromium/WidevineCdm"), false);
    addFirefoxProfiles(found, home + QStringLiteral("/.mozilla/firefox"));
#endif

    // La más nueva; a igual versión, la primera (más estable que la de Firefox)
    const Candidate *best = nullptr;
    for (const Candidate &candidate : std::as_const(found)) {
        if (!best || candidate.version > best->version)
            best = &candidate;
    }
    return best ? best->path : QString();
}

QString Widevine::setup()
{
    QByteArray flags = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
    const QByteArray option = "--widevine-path=";
    const qsizetype given = flags.indexOf(option);
    if (given >= 0) {
        // Ruta puesta a mano (puede llevar comillas)
        const qsizetype start = given + option.size();
        qsizetype end = flags.indexOf(' ', start);
        if (end < 0)
            end = flags.size();
        return QString::fromLocal8Bit(flags.mid(start, end - start)).remove(QLatin1Char('"'));
    }

    const QString path = find();
    if (path.isEmpty())
        return {};
    // Entre comillas: en Windows y macOS la ruta lleva espacios
    if (!flags.isEmpty())
        flags.append(' ');
    flags.append(option + '"' + QDir::toNativeSeparators(path).toLocal8Bit() + '"');
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", flags);
    return path;
}

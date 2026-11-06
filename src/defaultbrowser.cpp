#include "defaultbrowser.h"

#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QQmlEngine>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>

#ifdef Q_OS_WIN
#include <windows.h>
#include <shlwapi.h>
#endif

namespace {

#if defined(Q_OS_WIN)

// Lo que registra el instalador (installer/src/instalacion.cpp)
constexpr wchar_t ProgId[] = L"MitisHTML";

QString handlerOf(const wchar_t *scheme)
{
    wchar_t progId[128] = {};
    DWORD size = ARRAYSIZE(progId);
    // Lo pregunta a Windows: dónde guarda la elección cambia entre versiones
    if (FAILED(AssocQueryStringW(ASSOCF_IS_PROTOCOL, ASSOCSTR_PROGID, scheme, nullptr, progId, &size)))
        return {};
    return QString::fromWCharArray(progId);
}

bool registered()
{
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Software\\Classes\\MitisHTML", 0, KEY_READ, &key) != ERROR_SUCCESS)
        return false;
    RegCloseKey(key);
    return true;
}

#elif !defined(Q_OS_MACOS)

const QString DesktopFile = QStringLiteral("mitis.desktop");

// El .desktop instalado; un AppImage no lo trae y lo crea al elegirlo
QString installedDesktopFile()
{
    return QStandardPaths::locate(QStandardPaths::ApplicationsLocation, DesktopFile);
}

bool writeAppImageDesktopFile()
{
    const QString appImage = qEnvironmentVariable("APPIMAGE");
    if (appImage.isEmpty())
        return false;
    const QString folder = QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
    QDir().mkpath(folder);
    QSaveFile file(folder + QLatin1Char('/') + DesktopFile);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    file.write("[Desktop Entry]\nType=Application\nVersion=1.5\nName=Mitis\nGenericName=Navegador web\n"
               "Exec=\"" + appImage.toUtf8() + "\" %U\nIcon=mitis\nTerminal=false\n"
               "Categories=Network;WebBrowser;\n"
               "MimeType=text/html;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;\n"
               "StartupWMClass=Mitis\n");
    return file.commit();
}

#endif

} // namespace

DefaultBrowser *DefaultBrowser::instance()
{
    static DefaultBrowser *browser = new DefaultBrowser(QCoreApplication::instance());
    return browser;
}

DefaultBrowser *DefaultBrowser::create(QQmlEngine *, QJSEngine *)
{
    DefaultBrowser *browser = instance();
    // Es de la app, no del motor QML (en --dev hay uno nuevo en cada recarga)
    QQmlEngine::setObjectOwnership(browser, QQmlEngine::CppOwnership);
    return browser;
}

DefaultBrowser::DefaultBrowser(QObject *parent)
    : QObject(parent)
{
}

void DefaultBrowser::report(bool available, bool isDefault)
{
    if (m_checked && m_available == available && m_isDefault == isDefault)
        return;
    m_checked = true;
    m_available = available;
    m_isDefault = isDefault;
    emit changed();
}

void DefaultBrowser::refresh()
{
#if defined(Q_OS_WIN)
    report(registered(), handlerOf(L"https") == QString::fromWCharArray(ProgId)
                             && handlerOf(L"http") == QString::fromWCharArray(ProgId));
#elif defined(Q_OS_MACOS)
    // Fuera de un .app (compilación sin empaquetar) no hay nada registrado
    report(QCoreApplication::applicationDirPath().endsWith(QLatin1String(".app/Contents/MacOS")),
           macIsDefaultBrowser());
#else
    const bool tools = !QStandardPaths::findExecutable(QStringLiteral("xdg-settings")).isEmpty();
    const bool canRegister = !installedDesktopFile().isEmpty() || !qEnvironmentVariableIsEmpty("APPIMAGE");
    if (!tools || !canRegister) {
        report(false, false);
        return;
    }
    auto *process = new QProcess(this);
    connect(process, &QProcess::finished, this, [this, process] {
        report(true, QString::fromUtf8(process->readAllStandardOutput()).trimmed() == DesktopFile);
        process->deleteLater();
    });
    connect(process, &QProcess::errorOccurred, this, [this, process](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            report(false, false);
            process->deleteLater();
        }
    });
    process->start(QStringLiteral("xdg-settings"), { QStringLiteral("get"), QStringLiteral("default-web-browser") });
#endif
}

void DefaultBrowser::makeDefault()
{
#if defined(Q_OS_WIN)
    // Mitis está en RegisteredApplications del usuario: Windows abre su página
    // («Establecer como predeterminado»). Al volver a Mitis se comprueba
    QDesktopServices::openUrl(QUrl(QStringLiteral("ms-settings:defaultapps?registeredAppUser=Mitis")));
#elif defined(Q_OS_MACOS)
    macMakeDefaultBrowser([this] { refresh(); });
#else
    if (installedDesktopFile().isEmpty() && !writeAppImageDesktopFile())
        return;
    auto *settings = new QProcess(this);
    connect(settings, &QProcess::finished, this, [this, settings] {
        settings->deleteLater();
        // xdg-settings cubre los enlaces; los archivos de páginas, xdg-mime
        auto *mime = new QProcess(this);
        connect(mime, &QProcess::finished, this, [this, mime] {
            mime->deleteLater();
            refresh();
        });
        mime->start(QStringLiteral("xdg-mime"),
                    { QStringLiteral("default"), DesktopFile, QStringLiteral("text/html"),
                      QStringLiteral("application/xhtml+xml"), QStringLiteral("x-scheme-handler/http"),
                      QStringLiteral("x-scheme-handler/https") });
    });
    settings->start(QStringLiteral("xdg-settings"),
                    { QStringLiteral("set"), QStringLiteral("default-web-browser"), DesktopFile });
#endif
}

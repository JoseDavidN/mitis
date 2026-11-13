#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QLibraryInfo>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSettings>
#include <QStandardPaths>
#include <QTranslator>
#include <QtQml/qqmlextensionplugin.h>
#include <QtWebEngineCore/qtwebenginecoreglobal.h>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>

#include "crashreporter.h"
#include "devreloader.h"
#include "enginebridge.h"
#include "iconprovider.h"
#include "links.h"
#include "updater.h"
#include "networkfactory.h"
#include "profiles.h"
#include "screencapture.h"
#include "settings.h"
#include "widevine.h"

// Tipos de C++ para QML (Settings…): módulo Mitis.Core, enlazado estático
Q_IMPORT_QML_PLUGIN(Mitis_CorePlugin)

namespace {
// Biblioteca de Widevine que usa el motor (ver Widevine::setup)
QString widevinePath;

// Fuente de toda la interfaz (no de las páginas web): Nunito, empaquetada.
// Es variable: un solo archivo con todos los pesos
void setupFont()
{
    if (QFontDatabase::addApplicationFont(QStringLiteral(":/fonts/Nunito.ttf")) < 0) {
        qWarning("[Mitis] No se pudo cargar la fuente Nunito; se usa la del sistema");
        return;
    }
    QGuiApplication::setFont(QFont(QStringLiteral("Nunito")));
}

// La interfaz está en español: los textos propios de Qt (diálogos de
// archivos, menús de edición) también
void setupTranslations(QGuiApplication &app)
{
    auto *translator = new QTranslator(&app);
    if (translator->load(QStringLiteral("qt_es"), QLibraryInfo::path(QLibraryInfo::TranslationsPath)))
        QCoreApplication::installTranslator(translator);
}

// Corrector ortográfico: el diccionario de español (es.bdic) viaja con Mitis
// en una carpeta «qtwebengine_dictionaries» que cambia de sitio según el
// paquete: junto al ejecutable (Windows y la compilación), en Resources
// (macOS) o en share/mitis (Linux instalado y AppImage). Se le dice al motor
// la que exista; QTWEBENGINE_DICTIONARIES_PATH puesta a mano manda
void setupDictionaries()
{
    if (qEnvironmentVariableIsSet("QTWEBENGINE_DICTIONARIES_PATH"))
        return;
    const QString app = QCoreApplication::applicationDirPath();
    const QString name = QStringLiteral("qtwebengine_dictionaries");
    const QStringList candidates = {
        app + u'/' + name,
        app + QStringLiteral("/../Resources/") + name,
        app + QStringLiteral("/../share/mitis/") + name,
    };
    for (const QString &dir : candidates) {
        if (QFileInfo::exists(dir + QStringLiteral("/es.bdic"))) {
            qputenv("QTWEBENGINE_DICTIONARIES_PATH", QDir::cleanPath(dir).toLocal8Bit());
            return;
        }
    }
}

// Opciones de Chromium para gastar menos (Fase 5, docs/rendimiento.md). Van
// delante de las que el usuario ponga en QTWEBENGINE_CHROMIUM_FLAGS, que así
// puede cambiar cualquiera (la última gana).
void setupChromiumFlags()
{
    // Atrás y adelante al instante (caché de páginas anteriores; la enciende
    // cada vista, BrowserTab): cuántas páginas guarda cada pestaña y durante
    // cuánto. Chromium guarda de serie 6 durante 10 min; aquí, las elegidas
    // en Configuración (al menos 1: apagada no guarda ninguna) durante 3 min
    // (docs/rendimiento.md)
    const int backPages = qMax(1, Settings::instantBackPagesSaved());
    Settings::setInstantBackStarted(backPages);
    QByteArray features = "BackForwardCacheSize:cache_size/" + QByteArray::number(backPages)
        + ",BackForwardCacheTimeToLiveControl:time_to_live_seconds/180";
#ifdef Q_OS_LINUX
    // Vídeo por la GPU (VA-API; Configuración → Rendimiento): en Linux
    // Chromium lo trae apagado y decodifica con el procesador. Necesita Qt
    // Quick en OpenGL con EGL (Wayland, o X11 con QT_XCB_GL_INTEGRATION=xcb_egl);
    // si el driver no sirve, el motor vuelve solo al procesador. En la misma
    // lista: un segundo --enable-features sustituiría al primero
    const bool hardwareVideo = Settings::hardwareVideoDecodeSaved();
    Settings::setHardwareVideoDecodeStarted(hardwareVideo);
    if (hardwareVideo)
        features += ",AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL";
#endif
    const QByteArray flags =
        // Peticiones que el motor hace por su cuenta en segundo plano, sin
        // que ninguna página las pida
        "--disable-background-networking "
        // <a ping>: avisos de rastreo al pulsar un enlace
        "--no-pings "
        // APIs de publicidad de Privacy Sandbox: solo sirven a los anuncios,
        // guardan datos y trabajan en segundo plano. Las páginas comprueban
        // si existen antes de usarlas.
        "--disable-features=BrowsingTopics,InterestGroupStorage,AdInterestGroupAPI,Fledge,"
        "AttributionReportingCrossAppWeb,ConversionMeasurement,SharedStorageAPI,"
        "PrivateAggregationApi,FencedFrames,PrivacySandboxAdsAPIsOverride "
        "--enable-features=" + features + " "
        // Las páginas con versión oscura (prefers-color-scheme) la usan con
        // los temas oscuros de Mitis (Theme.qml: todos menos «claro»). Qt
        // WebEngine no deja cambiarlo en marcha: vale desde el próximo arranque.
        // La aplicación aún no existe: QSettings con los nombres del perfil.
        + QByteArray(QSettings(QCoreApplication::organizationName(), QCoreApplication::applicationName())
                             .value(QStringLiteral("Appearance/theme")).toString() == QLatin1String("claro")
                         ? "--blink-settings=preferredColorScheme=1"
                         : "--blink-settings=preferredColorScheme=0");
    // El proxy no va aquí: EngineBridge::applyProxy, que se puede cambiar en marcha
    const QByteArray engine = flags;
    const QByteArray user = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", user.isEmpty() ? engine : engine + ' ' + user);
}

// Diálogos de archivos (subir, guardar, elegir carpeta) del escritorio, por el
// portal (xdg-desktop-portal) en los gestores en mosaico (Hyprland, Sway…):
// sin GNOME ni KDE, Qt abriría su propio diálogo, distinto del resto del
// equipo. Si no hay portal, Qt vuelve a su diálogo. Antes de crear la
// aplicación; un QT_QPA_PLATFORMTHEME del usuario manda
void setupDesktopPortal()
{
#ifdef Q_OS_LINUX
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORMTHEME") && EngineBridge::tilingDesktop())
        qputenv("QT_QPA_PLATFORMTHEME", "xdgdesktopportal");
#endif
}

// El motor se queda con el proveedor y lo destruye con él. La fábrica de
// red y el puente con el motor web no: son uno para toda la vida de la app
// (en --dev hay un motor QML nuevo en cada recarga)
void setupEngine(QQmlApplicationEngine *engine, const QString &iconDir, EngineBridge *bridge)
{
    static NetworkFactory network(
        QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/interfaz"));
    engine->setNetworkAccessManagerFactory(&network);
    // Puente con el motor web para BrowserProfile.qml (perfiles, interceptor…)
    engine->rootContext()->setContextProperty(QStringLiteral("MitisEngine"), bridge);
    engine->addImageProvider(QStringLiteral("icon"), new IconProvider(iconDir));
}
}

int main(int argc, char *argv[])
{
    // Perfil (Profiles): antes de nada, porque de él salen la carpeta de datos
    // y los ajustes que el motor lee al arrancar
    QStringList arguments;
    for (int i = 0; i < argc; ++i)
        arguments.append(QString::fromLocal8Bit(argv[i]));
    Profiles::select(arguments);

    // Contenido protegido: la ruta de Widevine se da al motor antes de iniciarlo
    widevinePath = Widevine::setup();
    setupChromiumFlags();
    // Esquemas propios: antes de iniciar el motor
    ScreenCapture::registerScheme();
    // WebEngine debe inicializarse antes de crear la aplicación
    QtWebEngineQuick::initialize();
    setupDesktopPortal();

    QGuiApplication app(argc, argv);
    // Nombre y organización ya los puso Profiles::select (según el perfil)
    QGuiApplication::setApplicationVersion(MITIS_VERSION);
    QGuiApplication::setWindowIcon(QIcon(QStringLiteral(":/branding/mitis.png")));
    // Con Wayland, el escritorio asocia la ventana a su entrada e icono (mitis.desktop)
    QGuiApplication::setDesktopFileName(QStringLiteral("mitis"));
    setupFont();
    setupTranslations(app);
    // Antes de que EngineBridge cree los perfiles (el motor la lee entonces)
    setupDictionaries();

    // Navegador predeterminado: los enlaces llegan como argumentos. Si ya hay
    // un Mitis abierto con este perfil, se los lleva él (y se pone delante) y
    // este termina: dos procesos no pueden compartir el perfil del motor.
    const QStringList urls = Links::fromArguments(app.arguments());
    if (Links::instance()->forwardToRunning(urls))
        return 0;
    if (!urls.isEmpty())
        Links::instance()->add(urls);
    Links::instance()->listen();

    // Registro de la sesión e informes de cierres inesperados (Configuración
    // → Desarrollo): desde aquí, ya sabiendo que este proceso se queda
    CrashReporter::instance()->install();
    qInfo("Chromium %s (Qt WebEngine)", qWebEngineChromiumVersion());
    // Busca versiones nuevas en el servidor de descargas (al poco y cada tanto)
    Updater::instance();

    // Perfiles del navegador y bloqueador: antes que la interfaz, que los usa,
    // y destruidos después de ella (ver el final)
    // Proxy y DNS cifrado de las páginas: antes de crear los perfiles (y
    // después, en marcha, desde BrowserProfile)
    EngineBridge::applyProxy();
    EngineBridge::applySecureDns();
    auto *bridge = new EngineBridge(widevinePath);

    // La interfaz (motor QML o recargador); se destruye a mano al salir
    QObject *ui = nullptr;
    if (app.arguments().contains(QStringLiteral("--dev"))) {
        // Modo desarrollo: QML desde el código fuente, con recarga en caliente.
        // Un error de QML no cierra la app; basta con corregirlo y guardar.
        auto *reloader = new DevReloader(QStringLiteral(MITIS_QML_DIR), &app);
        ui = reloader;
        QObject::connect(reloader, &DevReloader::engineCreated, &app, [bridge](QQmlApplicationEngine *engine) {
            setupEngine(engine, QStringLiteral(MITIS_ICONS_DIR), bridge);
        });
        reloader->start();
    } else {
        auto *engine = new QQmlApplicationEngine(&app);
        ui = engine;
        setupEngine(engine, QStringLiteral(":/icons"), bridge);
        QObject::connect(
            engine, &QQmlApplicationEngine::objectCreationFailed,
            &app, [] { QCoreApplication::exit(-1); },
            Qt::QueuedConnection);
        engine->loadFromModule("Mitis", "Main");
    }

    const int result = app.exec();
    // La interfaz (y con ella las páginas y el perfil de Qt WebEngine) se
    // destruye antes que la aplicación: si se deja como hija de `app`, se
    // destruye a mitad del cierre de esta y Qt WebEngine se queda bloqueado,
    // con el proceso vivo y sin ventanas
    delete ui;
    // Los perfiles, después de las páginas y antes que la aplicación
    delete bridge;
    CrashReporter::instance()->finish();
    // «Reiniciar ahora» (Configuración): ya cerrado todo, se abre otro Mitis
    EngineBridge::relaunchIfRequested();
    return result;
}
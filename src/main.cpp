#include <QCoreApplication>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QLibraryInfo>
#include <QQmlApplicationEngine>
#include <QStandardPaths>
#include <QTranslator>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>

#include "devreloader.h"
#include "iconprovider.h"
#include "networkfactory.h"

namespace {
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

// El motor se queda con el proveedor y lo destruye con él. La fábrica de
// red no: es una sola para toda la vida de la app (en --dev hay un motor
// nuevo en cada recarga)
void setupEngine(QQmlApplicationEngine *engine, const QString &iconDir)
{
    static NetworkFactory network(
        QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/interfaz"));
    engine->setNetworkAccessManagerFactory(&network);
    engine->addImageProvider(QStringLiteral("icon"), new IconProvider(iconDir));
}
}

int main(int argc, char *argv[])
{
    // WebEngine debe inicializarse antes de crear la aplicación
    QtWebEngineQuick::initialize();

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("Mitis");
    QGuiApplication::setApplicationVersion(MITIS_VERSION);
    QGuiApplication::setOrganizationName("Mitis");
    setupFont();
    setupTranslations(app);

    if (app.arguments().contains(QStringLiteral("--dev"))) {
        // Modo desarrollo: QML desde el código fuente, con recarga en caliente.
        // Un error de QML no cierra la app; basta con corregirlo y guardar.
        auto *reloader = new DevReloader(QStringLiteral(MITIS_QML_DIR), &app);
        QObject::connect(reloader, &DevReloader::engineCreated, &app, [](QQmlApplicationEngine *engine) {
            setupEngine(engine, QStringLiteral(MITIS_ICONS_DIR));
        });
        reloader->start();
    } else {
        auto *engine = new QQmlApplicationEngine(&app);
        setupEngine(engine, QStringLiteral(":/icons"));
        QObject::connect(
            engine, &QQmlApplicationEngine::objectCreationFailed,
            &app, [] { QCoreApplication::exit(-1); },
            Qt::QueuedConnection);
        engine->loadFromModule("Mitis", "Main");
    }

    return app.exec();
}
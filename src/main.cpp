#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>

int main(int argc, char *argv[])
{
    // WebEngine debe inicializarse antes de crear la aplicación
    QtWebEngineQuick::initialize();

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("Mitis");
    QGuiApplication::setApplicationVersion(MITIS_VERSION);
    QGuiApplication::setOrganizationName("Mitis");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("Mitis", "Main");

    return app.exec();
}

#include "devreloader.h"

#include <QDir>
#include <QDirIterator>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QSet>
#include <QWindow>
#include <QtDebug>

DevReloader::DevReloader(const QString &qmlDir, QObject *parent)
    : QObject(parent)
    , m_engine(nullptr)
    , m_qmlDir(qmlDir)
    , m_mainUrl(QUrl::fromLocalFile(QDir(qmlDir).filePath(QStringLiteral("Main.qml"))))
{
    // Agrupa varios eventos de guardado en una sola recarga
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(150);
    connect(&m_debounce, &QTimer::timeout, this, &DevReloader::reload);

    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &DevReloader::scheduleReload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &DevReloader::scheduleReload);
}

void DevReloader::start()
{
    qInfo().noquote() << "[Mitis] Modo desarrollo: QML desde" << m_qmlDir;
    watchFiles();
    createEngine();
    m_engine->load(m_mainUrl);
}

void DevReloader::createEngine()
{
    m_engine = new QQmlApplicationEngine(this);
    emit engineCreated(m_engine);
}

void DevReloader::scheduleReload()
{
    m_debounce.start();
}

void DevReloader::watchFiles()
{
    if (!m_watcher.files().isEmpty())
        m_watcher.removePaths(m_watcher.files());
    if (!m_watcher.directories().isEmpty())
        m_watcher.removePaths(m_watcher.directories());

    // Se vuelve a registrar todo en cada recarga porque muchos editores
    // guardan reemplazando el archivo, y eso elimina la vigilancia anterior.
    QSet<QString> dirs{m_qmlDir};
    QStringList files;
    QDirIterator it(m_qmlDir, {QStringLiteral("*.qml"), QStringLiteral("*.js")},
                    QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString file = it.next();
        files << file;
        dirs.insert(QFileInfo(file).absolutePath());
    }

    m_watcher.addPaths(files);
    m_watcher.addPaths(QStringList(dirs.begin(), dirs.end()));
}

void DevReloader::reload()
{
    // Conserva la posición y el tamaño de la ventana entre recargas
    QRect geometry;
    Qt::WindowStates states;
    bool hadWindow = false;

    // Evita que la app se cierre al destruir la ventana anterior
    QGuiApplication::setQuitOnLastWindowClosed(false);

    const auto roots = m_engine->rootObjects();
    for (QObject *obj : roots) {
        if (auto *window = qobject_cast<QWindow *>(obj); window && !hadWindow) {
            geometry = window->geometry();
            states = window->windowStates();
            hadWindow = true;
        }
    }

    // Al destruir el motor se destruyen también sus ventanas
    m_engine->deleteLater();
    m_engine = nullptr;

    QTimer::singleShot(0, this, [=] {
        createEngine();
        m_engine->load(m_mainUrl);

        const auto newRoots = m_engine->rootObjects();
        if (!newRoots.isEmpty()) {
            if (auto *window = qobject_cast<QWindow *>(newRoots.last()); window && hadWindow) {
                window->setGeometry(geometry);
                window->setWindowStates(states);
            }
            qInfo() << "[Mitis] Interfaz recargada";
        } else {
            qWarning() << "[Mitis] Error en QML. Corrígelo y guarda para reintentar.";
        }

        QGuiApplication::setQuitOnLastWindowClosed(true);
        watchFiles();
    });
}
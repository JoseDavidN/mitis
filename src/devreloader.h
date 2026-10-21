#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>
#include <QUrl>

class QQmlApplicationEngine;

// Modo desarrollo: carga la interfaz desde la carpeta qml/ del código fuente
// y la recarga automáticamente cada vez que se guarda un archivo .qml o .js.
// Usa un motor nuevo en cada recarga: clearComponentCache() no recarga los
// singletons como Theme.
class DevReloader : public QObject
{
    Q_OBJECT

public:
    explicit DevReloader(const QString &qmlDir, QObject *parent = nullptr);

    void start();

signals:
    // Cada motor nuevo, antes de cargar la interfaz: para registrar en él
    // lo que la interfaz necesita (proveedores de imágenes, etc.)
    void engineCreated(QQmlApplicationEngine *engine);

private:
    void scheduleReload();
    void reload();
    void watchFiles();
    void createEngine();

    QQmlApplicationEngine *m_engine;
    QString m_qmlDir;
    QUrl m_mainUrl;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
#pragma once

#include <QObject>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

class QLocalServer;
class QQmlEngine;
class QJSEngine;

// Enlaces que el sistema pide abrir en Mitis (navegador predeterminado):
// los argumentos al arrancar (`Mitis https://…`), los que manda otro Mitis
// lanzado después y, en macOS, los que llegan como evento FileOpen.
//
// Un solo Mitis por perfil: el que arranca con Mitis ya abierto le pasa sus
// enlaces por un QLocalServer y termina (dos procesos no pueden usar el
// mismo perfil del motor). El nombre del canal sale de la carpeta de datos:
// perfiles distintos (otra carpeta XDG) son Mitis independientes.
//
// En QML es el singleton `Links` del módulo Mitis.Core; hay uno para toda
// la app (también entre recargas de --dev).
class Links : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    static Links *instance();
    static Links *create(QQmlEngine *, QJSEngine *);

    // Argumentos de la línea de órdenes → direcciones (las rutas de archivo,
    // relativas a la carpeta actual, pasan a file://)
    static QStringList fromArguments(const QStringList &arguments);

    // true si ya hay un Mitis abierto con este perfil: le pasa `urls` (o, sin
    // ninguna, solo que se muestre) y este proceso debe terminar
    bool forwardToRunning(const QStringList &urls);
    // Empieza a escuchar a los Mitis que se lancen después
    void listen();

    void add(const QStringList &urls);

    // Los enlaces pendientes (y los quita): los abre la ventana principal
    Q_INVOKABLE QStringList takePending();

signals:
    // Hay enlaces pendientes, o se pidió mostrar Mitis (pending puede estar vacío)
    void received();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    explicit Links(QObject *parent = nullptr);
    static QString serverName();

    QStringList m_pending;
    QLocalServer *m_server = nullptr;
};

#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// Perfiles de Mitis, como los de Zen o Firefox: cada uno es un Mitis aparte
// (otro proceso) con su propia carpeta de datos (cookies, historial,
// marcadores, contraseñas, ajustes, sesión), así que uno no afecta a otro.
// Se distinguen por el nombre de la aplicación, del que salen todas las
// rutas (QStandardPaths, QSettings): el principal es «Mitis» (la carpeta de
// siempre) y los demás «Mitis-<id>». main.cpp elige el perfil antes de
// iniciar el motor (select): con --perfil <id>, ese; sin él, el principal o,
// si ya está abierto y no hay enlaces que abrir, uno nuevo. La lista vive en
// un registro común (QSettings «Mitis/perfiles»); el nombre, color y foto de
// cada uno, en sus propios ajustes (Profile/…).
class Profiles : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Id del perfil de este Mitis ("" = el principal)
    Q_PROPERTY(QString current READ current CONSTANT)

public:
    static Profiles *instance();
    static Profiles *create(QQmlEngine *, QJSEngine *);

    // main.cpp, antes de nada: el perfil de este proceso según sus argumentos
    static void select(const QStringList &arguments);
    static QString currentId();
    // Argumentos para abrir otro Mitis con el perfil de este (reiniciar)
    static QStringList launchArguments();

    QString current() const { return currentId(); }

    // [{ id, name, color, photo, running, current }]: el principal y los
    // creados, en ese orden. Se calcula al pedirlo (cada fila mira si su
    // Mitis está abierto)
    Q_INVOKABLE QVariantList list() const;
    // Abre el Mitis de ese perfil (si ya está abierto, no pasa nada)
    Q_INVOKABLE void open(const QString &id) const;
    // Crea un perfil y lo abre
    Q_INVOKABLE void openNew() const;
    // Borra un perfil y todos sus datos (no el principal ni uno abierto)
    Q_INVOKABLE bool remove(const QString &id);

signals:
    void changed();

private:
    explicit Profiles(QObject *parent = nullptr);
    static QString createProfile();
};

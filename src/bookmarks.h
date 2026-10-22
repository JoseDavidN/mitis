#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Marcadores, en SQLite (bookmarks.sqlite, en la carpeta de datos de Mitis).
// Son pocos: se tienen todos en memoria y se escriben al momento (añadir o
// quitar uno es una consulta mínima). En QML es el singleton `Bookmarks` del
// módulo Mitis.Core.
class Bookmarks : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Todos, el más reciente primero: [{ url, title, added (ms) }]
    Q_PROPERTY(QVariantList items READ items NOTIFY changed)
    // Solo las direcciones, para saber al momento si una página está guardada
    Q_PROPERTY(QStringList urls READ urls NOTIFY changed)

public:
    explicit Bookmarks(QObject *parent = nullptr);
    ~Bookmarks() override;

    QVariantList items() const { return m_items; }
    QStringList urls() const { return m_urls; }

    Q_INVOKABLE bool contains(const QString &url) const { return m_urls.contains(url); }
    // Si ya estaba, solo se actualiza el título
    Q_INVOKABLE void add(const QString &url, const QString &title);
    Q_INVOKABLE void remove(const QString &url);
    // Los que contienen `text` en la dirección o el título
    Q_INVOKABLE QVariantList search(const QString &text, int limit = -1) const;

signals:
    void changed();

private:
    void load();

    QString m_connection;
    QVariantList m_items;
    QStringList m_urls;
};

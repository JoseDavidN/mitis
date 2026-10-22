#pragma once

#include <QObject>
#include <QString>
#include <QThread>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class HistoryWriter;

// Historial de navegación, en SQLite (history.sqlite, en la carpeta de datos
// de Mitis). Una fila por dirección: título, última visita y número de
// visitas. En QML es el singleton `History` del módulo Mitis.Core.
//
// Las escrituras (cada página que se carga) van a un hilo propio para no
// frenar la interfaz; las lecturas son consultas pequeñas y se hacen aquí.
// Al terminar cada escritura se emite changed().
class History : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit History(QObject *parent = nullptr);
    ~History() override;

    // Una visita a `url` (solo http y https). Si ya estaba, sube su contador
    Q_INVOKABLE void addVisit(const QString &url, const QString &title);
    // El título llega a veces después de terminar la carga
    Q_INVOKABLE void updateTitle(const QString &url, const QString &title);

    // Las visitadas más recientes: [{ url, title, lastVisit (ms), visits }].
    // Con `filter`, solo las que lo contienen en la dirección o el título.
    Q_INVOKABLE QVariantList recent(int limit, const QString &filter = QString()) const;
    // Sugerencias para la barra de dirección: las que contienen `text`,
    // primero las más visitadas
    Q_INVOKABLE QVariantList suggest(const QString &text, int limit) const;

    Q_INVOKABLE void remove(const QString &url);
    // Borra lo visitado desde `sinceMs` (0 = todo)
    Q_INVOKABLE void clear(double sinceMs = 0);

signals:
    // Se terminó de escribir algo: hay que volver a leer
    void changed();

    // Al hilo de escritura
    void writeVisit(const QString &url, const QString &title, qint64 when);
    void writeTitle(const QString &url, const QString &title);
    void writeRemove(const QString &url);
    void writeClear(qint64 since);

private:
    QVariantList query(const QString &sql, const QVariantList &values) const;

    QString m_path;
    QString m_connection;
    QThread m_thread;
    HistoryWriter *m_writer;
};

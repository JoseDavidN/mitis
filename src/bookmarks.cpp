#include "bookmarks.h"

#include <QDateTime>
#include <QDir>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QtDebug>

Bookmarks::Bookmarks(QObject *parent)
    : QObject(parent)
    // En --dev hay un motor QML (y unos Bookmarks) nuevo en cada recarga
    , m_connection(QStringLiteral("bookmarks-") + QString::number(reinterpret_cast<quintptr>(this), 16))
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connection);
    db.setDatabaseName(dir + QStringLiteral("/bookmarks.sqlite"));
    if (!db.open()) {
        qWarning() << "[Mitis] No se pudieron abrir los marcadores:" << db.lastError().text();
        return;
    }
    QSqlQuery query(db);
    query.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS bookmarks ("
                              "url TEXT PRIMARY KEY, title TEXT NOT NULL DEFAULT '', "
                              "added INTEGER NOT NULL)"));
    load();
}

Bookmarks::~Bookmarks()
{
    {
        QSqlDatabase db = QSqlDatabase::database(m_connection, false);
        db.close();
    }
    QSqlDatabase::removeDatabase(m_connection);
}

void Bookmarks::load()
{
    m_items.clear();
    m_urls.clear();
    QSqlQuery query(QSqlDatabase::database(m_connection));
    query.exec(QStringLiteral("SELECT url, title, added FROM bookmarks ORDER BY added DESC"));
    while (query.next()) {
        m_urls.append(query.value(0).toString());
        m_items.append(QVariantMap{
            { QStringLiteral("url"), query.value(0) },
            { QStringLiteral("title"), query.value(1) },
            { QStringLiteral("added"), query.value(2).toDouble() },
        });
    }
}

void Bookmarks::add(const QString &url, const QString &title)
{
    if (url.isEmpty())
        return;
    QSqlQuery query(QSqlDatabase::database(m_connection));
    query.prepare(QStringLiteral("INSERT INTO bookmarks (url, title, added) VALUES (?, ?, ?) "
                                 "ON CONFLICT(url) DO UPDATE SET title = excluded.title"));
    query.addBindValue(url);
    // Una cadena nula se guardaría como NULL
    query.addBindValue(title.isNull() ? QStringLiteral("") : title);
    query.addBindValue(QDateTime::currentMSecsSinceEpoch());
    if (!query.exec()) {
        qWarning() << "[Mitis] Marcadores:" << query.lastError().text();
        return;
    }
    load();
    emit changed();
}

void Bookmarks::remove(const QString &url)
{
    QSqlQuery query(QSqlDatabase::database(m_connection));
    query.prepare(QStringLiteral("DELETE FROM bookmarks WHERE url = ?"));
    query.addBindValue(url);
    if (!query.exec()) {
        qWarning() << "[Mitis] Marcadores:" << query.lastError().text();
        return;
    }
    load();
    emit changed();
}

QVariantList Bookmarks::search(const QString &text, int limit) const
{
    const QString needle = text.trimmed();
    QVariantList found;
    for (const QVariant &item : m_items) {
        if (limit >= 0 && found.size() >= limit)
            break;
        const QVariantMap bookmark = item.toMap();
        if (needle.isEmpty()
            || bookmark.value(QStringLiteral("url")).toString().contains(needle, Qt::CaseInsensitive)
            || bookmark.value(QStringLiteral("title")).toString().contains(needle, Qt::CaseInsensitive))
            found.append(item);
    }
    return found;
}

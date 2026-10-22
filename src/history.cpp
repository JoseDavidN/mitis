#include "history.h"

#include <QDateTime>
#include <QDir>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QUrl>
#include <QtDebug>

namespace {

// Solo páginas web: ni file://, ni about:, ni las internas del motor
bool recordable(const QString &url)
{
    return url.startsWith(QLatin1String("https://")) || url.startsWith(QLatin1String("http://"));
}

QSqlDatabase open(const QString &connection, const QString &path)
{
    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connection);
    db.setDatabaseName(path);
    if (!db.open())
        qWarning() << "[Mitis] No se pudo abrir el historial:" << db.lastError().text();
    QSqlQuery query(db);
    // WAL: la interfaz puede leer mientras el hilo escribe
    query.exec(QStringLiteral("PRAGMA journal_mode=WAL"));
    query.exec(QStringLiteral("PRAGMA busy_timeout=2000"));
    return db;
}

// Una cadena nula se guardaría como NULL: el título va siempre como texto
QString text(const QString &value)
{
    return value.isNull() ? QStringLiteral("") : value;
}

// Para LIKE: el texto buscado tal cual, sin comodines
QString likePattern(const QString &text)
{
    QString escaped = text;
    escaped.replace(QLatin1Char('\\'), QLatin1String("\\\\"))
           .replace(QLatin1Char('%'), QLatin1String("\\%"))
           .replace(QLatin1Char('_'), QLatin1String("\\_"));
    return QLatin1Char('%') + escaped + QLatin1Char('%');
}

} // namespace

// Vive en el hilo de escritura, con su propia conexión
class HistoryWriter : public QObject
{
    Q_OBJECT

public:
    HistoryWriter(const QString &path, const QString &connection)
        : m_path(path), m_connection(connection)
    {
    }

    ~HistoryWriter() override
    {
        {
            QSqlDatabase db = QSqlDatabase::database(m_connection, false);
            db.close();
        }
        QSqlDatabase::removeDatabase(m_connection);
    }

public slots:
    void visit(const QString &url, const QString &title, qint64 when)
    {
        QSqlQuery query(db());
        query.prepare(QStringLiteral(
            "INSERT INTO history (url, title, last_visit, visits) VALUES (?, ?, ?, 1) "
            "ON CONFLICT(url) DO UPDATE SET last_visit = excluded.last_visit, visits = visits + 1, "
            "title = CASE WHEN excluded.title <> '' THEN excluded.title ELSE title END"));
        query.addBindValue(url);
        query.addBindValue(text(title));
        query.addBindValue(when);
        run(query);
    }

    void title(const QString &url, const QString &title)
    {
        QSqlQuery query(db());
        query.prepare(QStringLiteral("UPDATE history SET title = ? WHERE url = ?"));
        query.addBindValue(text(title));
        query.addBindValue(url);
        run(query);
    }

    void remove(const QString &url)
    {
        QSqlQuery query(db());
        query.prepare(QStringLiteral("DELETE FROM history WHERE url = ?"));
        query.addBindValue(url);
        run(query);
    }

    void clear(qint64 since)
    {
        QSqlQuery query(db());
        query.prepare(QStringLiteral("DELETE FROM history WHERE last_visit >= ?"));
        query.addBindValue(since);
        run(query);
    }

signals:
    void written();

private:
    QSqlDatabase db()
    {
        // La conexión se abre en este hilo, en la primera escritura
        if (!QSqlDatabase::contains(m_connection))
            return open(m_connection, m_path);
        return QSqlDatabase::database(m_connection);
    }

    void run(QSqlQuery &query)
    {
        if (!query.exec())
            qWarning() << "[Mitis] Historial:" << query.lastError().text();
        emit written();
    }

    QString m_path;
    QString m_connection;
};

History::History(QObject *parent)
    : QObject(parent)
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    m_path = dir + QStringLiteral("/history.sqlite");
    // En --dev hay un motor QML (y un History) nuevo en cada recarga:
    // conexiones con nombre propio de cada instancia
    const QString id = QString::number(reinterpret_cast<quintptr>(this), 16);
    m_connection = QStringLiteral("history-read-") + id;

    QSqlDatabase db = open(m_connection, m_path);
    QSqlQuery query(db);
    query.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS history ("
        "url TEXT PRIMARY KEY, title TEXT NOT NULL DEFAULT '', "
        "last_visit INTEGER NOT NULL, visits INTEGER NOT NULL DEFAULT 1)"));
    query.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS history_last_visit ON history (last_visit)"));

    m_writer = new HistoryWriter(m_path, QStringLiteral("history-write-") + id);
    m_writer->moveToThread(&m_thread);
    connect(&m_thread, &QThread::finished, m_writer, &QObject::deleteLater);
    connect(this, &History::writeVisit, m_writer, &HistoryWriter::visit);
    connect(this, &History::writeTitle, m_writer, &HistoryWriter::title);
    connect(this, &History::writeRemove, m_writer, &HistoryWriter::remove);
    connect(this, &History::writeClear, m_writer, &HistoryWriter::clear);
    connect(m_writer, &HistoryWriter::written, this, &History::changed);
    m_thread.setObjectName(QStringLiteral("Historial"));
    m_thread.start(QThread::LowPriority);
}

History::~History()
{
    // Termina lo pendiente y cierra la conexión de escritura en su hilo
    m_thread.quit();
    m_thread.wait();
    {
        QSqlDatabase db = QSqlDatabase::database(m_connection, false);
        db.close();
    }
    QSqlDatabase::removeDatabase(m_connection);
}

void History::addVisit(const QString &url, const QString &title)
{
    if (recordable(url))
        emit writeVisit(url, title, QDateTime::currentMSecsSinceEpoch());
}

void History::updateTitle(const QString &url, const QString &title)
{
    if (recordable(url) && !title.isEmpty())
        emit writeTitle(url, title);
}

void History::remove(const QString &url)
{
    emit writeRemove(url);
}

void History::clear(double sinceMs)
{
    emit writeClear(static_cast<qint64>(sinceMs));
}

QVariantList History::recent(int limit, const QString &filter) const
{
    if (filter.trimmed().isEmpty()) {
        return query(QStringLiteral("SELECT url, title, last_visit, visits FROM history "
                                    "ORDER BY last_visit DESC LIMIT ?"),
                     { limit });
    }
    const QString pattern = likePattern(filter.trimmed());
    return query(QStringLiteral("SELECT url, title, last_visit, visits FROM history "
                                "WHERE url LIKE ? ESCAPE '\\' OR title LIKE ? ESCAPE '\\' "
                                "ORDER BY last_visit DESC LIMIT ?"),
                 { pattern, pattern, limit });
}

QVariantList History::suggest(const QString &text, int limit) const
{
    const QString trimmed = text.trimmed();
    if (trimmed.isEmpty())
        return {};
    const QString pattern = likePattern(trimmed);
    // Primero las que empiezan por lo escrito (sin esquema ni www.)
    const QString prefix = likePattern(trimmed).mid(1);
    return query(QStringLiteral(
                     "SELECT url, title, last_visit, visits FROM history "
                     "WHERE url LIKE ? ESCAPE '\\' OR title LIKE ? ESCAPE '\\' "
                     "ORDER BY (replace(replace(replace(url, 'https://', ''), 'http://', ''), 'www.', '') "
                     "LIKE ? ESCAPE '\\') DESC, visits DESC, last_visit DESC LIMIT ?"),
                 { pattern, pattern, prefix, limit });
}

QVariantList History::query(const QString &sql, const QVariantList &values) const
{
    QSqlQuery query(QSqlDatabase::database(m_connection));
    query.prepare(sql);
    for (const QVariant &value : values)
        query.addBindValue(value);
    QVariantList rows;
    if (!query.exec()) {
        qWarning() << "[Mitis] Historial:" << query.lastError().text();
        return rows;
    }
    while (query.next()) {
        rows.append(QVariantMap{
            { QStringLiteral("url"), query.value(0) },
            { QStringLiteral("title"), query.value(1) },
            { QStringLiteral("lastVisit"), query.value(2).toDouble() },
            { QStringLiteral("visits"), query.value(3) },
        });
    }
    return rows;
}

#include "history.moc"

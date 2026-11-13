#include "contentblocker.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkProxy>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QStandardPaths>
#include <QThread>
#include <QTimer>
#include <QUrlQuery>

#include <iterator>

namespace {

struct FilterList {
    const char *file;
    const char *url;
    // Cada cuánto se renueva
    qint64 maxAgeSecs;
};

// Como EasyList («Expires: 4 days»)
constexpr qint64 MaxAgeSecs = 4 * 24 * 3600;

// El orden no importa: las excepciones de una lista valen para todas
constexpr FilterList Lists[] = {
    { "easylist.txt", "https://easylist.to/easylist/easylist.txt", MaxAgeSecs },
    { "easyprivacy.txt", "https://easylist.to/easylist/easyprivacy.txt", MaxAgeSecs },
    { "easylist-es.txt", "https://easylist-downloads.adblockplus.org/easylistspanish.txt", MaxAgeSecs },
    { "hagezi-pro.txt", "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt", MaxAgeSecs },
    { "ublock-unbreak.txt", "https://ublockorigin.github.io/uAssets/filters/unbreak.txt", MaxAgeSecs },
    // Con «!#include» de filters-general.txt, filters-2020.txt…: se guardan dentro
    { "ublock-filters.txt", "https://ublockorigin.github.io/uAssets/filters/filters.txt", MaxAgeSecs },
    // Arreglos del día (YouTube cambia a menudo): «Expires: 8 hours»
    { "ublock-quick-fixes.txt", "https://ublockorigin.github.io/uAssets/filters/quick-fixes.txt", 8 * 3600 },
};
// Para sesiones largas: cada cuánto se mira si toca renovar
constexpr int CheckIntervalMs = 6 * 3600 * 1000;

// Parámetros que solo sirven para seguir al usuario de un sitio a otro.
// Además, todos los que empiezan por «utm_».
const QSet<QString> &trackingParams()
{
    static const QSet<QString> params = {
        QStringLiteral("fbclid"), QStringLiteral("gclid"), QStringLiteral("gclsrc"), QStringLiteral("dclid"),
        QStringLiteral("gbraid"), QStringLiteral("wbraid"), QStringLiteral("msclkid"), QStringLiteral("mc_eid"),
        QStringLiteral("igshid"), QStringLiteral("yclid"), QStringLiteral("twclid"), QStringLiteral("ttclid"),
        QStringLiteral("li_fat_id"), QStringLiteral("_hsenc"), QStringLiteral("_hsmi"), QStringLiteral("mkt_tok"),
        QStringLiteral("oly_enc_id"), QStringLiteral("oly_anon_id"), QStringLiteral("vero_id"),
        QStringLiteral("__hstc"), QStringLiteral("__hssc"), QStringLiteral("__hsfp"),
    };
    return params;
}

bool isSameOrSubdomain(const QByteArray &host, const QByteArray &domain)
{
    return host == domain || (host.endsWith(domain) && host.size() > domain.size()
                              && host.at(host.size() - domain.size() - 1) == '.');
}

QByteArray hostOf(const QUrl &url)
{
    return url.host(QUrl::FullyEncoded).toLower().toLatin1();
}

} // namespace

ContentBlocker::ContentBlocker(QObject *parent)
    : QObject(parent)
{
    auto *timer = new QTimer(this);
    timer->setInterval(CheckIntervalMs);
    connect(timer, &QTimer::timeout, this, [this] {
        if ((m_enabled || m_privateActive) && !updating() && listsStale())
            update(true);
    });
    timer->start();
    // Una descarga a medias se corta antes de que la aplicación desaparezca
    if (QCoreApplication::instance()) {
        connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, this, [this] {
            delete m_network;
            m_network = nullptr;
        });
    }
}

ContentBlocker::~ContentBlocker()
{
    if (m_thread)
        m_thread->wait();
}

QString ContentBlocker::filterDir() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/filtros");
}

void ContentBlocker::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    m_enabled = enabled;
    if (enabled && !m_engine && !m_compiling)
        compile();
}

void ContentBlocker::setPrivateActive(bool active)
{
    m_privateActive = active;
    if (active && !m_engine && !m_compiling)
        compile();
}

void ContentBlocker::setAllowedSites(const QStringList &sites)
{
    m_allowedSites.clear();
    for (const QString &site : sites)
        m_allowedSites.insert(site.toLower().toLatin1());
}

bool ContentBlocker::allowedSite(const QByteArray &pageHost) const
{
    for (const QByteArray &site : m_allowedSites) {
        if (isSameOrSubdomain(pageHost, site))
            return true;
    }
    return false;
}

QString ContentBlocker::siteOf(const QUrl &url)
{
    return QString::fromLatin1(FilterEngine::baseDomain(hostOf(url)));
}

bool ContentBlocker::shouldBlock(const QUrl &url, const QUrl &page, FilterEngine::Type type, bool strict)
{
    if ((!m_enabled && !strict) || !m_engine)
        return false;
    const QString scheme = url.scheme();
    if (scheme != QLatin1String("https") && scheme != QLatin1String("http")
        && scheme != QLatin1String("wss") && scheme != QLatin1String("ws"))
        return false;

    FilterEngine::Request request;
    request.url = url.toEncoded().toLower();
    request.host = hostOf(url);
    // Sin página (peticiones del propio motor): la petición es su propia página
    request.pageUrl = page.isEmpty() ? request.url : page.toEncoded().toLower();
    request.pageHost = page.isEmpty() ? request.host : hostOf(page);
    request.type = type;
    request.thirdParty = FilterEngine::baseDomain(request.host) != FilterEngine::baseDomain(request.pageHost);

    if (!strict && allowedSite(request.pageHost))
        return false;
    if (request.pageUrl != m_lastPageUrl) {
        m_lastPageUrl = request.pageUrl;
        m_lastPageAllowed = m_engine->documentAllowed(request.pageUrl, request.pageHost);
    }
    if (m_lastPageAllowed || !m_engine->shouldBlock(request))
        return false;

    ++m_blocked;
    if (!m_blockedNotifyPending) {
        m_blockedNotifyPending = true;
        QTimer::singleShot(1000, this, [this] {
            m_blockedNotifyPending = false;
            emit blockedCountChanged();
        });
    }
    return true;
}

QUrl ContentBlocker::withoutTrackingParams(const QUrl &url, bool strict) const
{
    if ((!stripTracking && !strict) || !url.hasQuery())
        return url;
    const QUrlQuery query(url);
    QUrlQuery kept;
    bool removed = false;
    const auto items = query.queryItems(QUrl::FullyEncoded);
    for (const auto &item : items) {
        const QString name = item.first.toLower();
        if (name.startsWith(QLatin1String("utm_")) || trackingParams().contains(name)) {
            removed = true;
            continue;
        }
        kept.addQueryItem(item.first, item.second);
    }
    if (!removed)
        return url;
    QUrl clean = url;
    if (kept.isEmpty())
        clean.setQuery(QString());
    else
        clean.setQuery(kept.query(QUrl::FullyEncoded), QUrl::StrictMode);
    return clean;
}

QString ContentBlocker::cosmeticCss(const QUrl &page, bool strict) const
{
    if ((!m_enabled && !strict) || !m_engine)
        return QString();
    const QByteArray host = hostOf(page);
    if (host.isEmpty() || (!strict && allowedSite(host)))
        return QString();
    return QString::fromUtf8(m_engine->cosmeticCss(page.toEncoded().toLower(), host));
}

QByteArray ContentBlocker::scriptlets(const QUrl &page, bool strict) const
{
    if ((!m_enabled && !strict) || !m_engine)
        return QByteArray();
    const QByteArray host = hostOf(page);
    if (host.isEmpty() || (!strict && allowedSite(host)))
        return QByteArray();
    return m_engine->scriptlets(page.toEncoded().toLower(), host);
}

bool ContentBlocker::listsStale() const
{
    const QDateTime now = QDateTime::currentDateTime();
    for (const FilterList &list : Lists) {
        const QFileInfo info(filterDir() + QLatin1Char('/') + QLatin1String(list.file));
        if (!info.exists() || info.lastModified().secsTo(now) > list.maxAgeSecs)
            return true;
    }
    return false;
}

// Lee las listas guardadas y las compila en otro hilo; al terminar, el
// motor nuevo sustituye al anterior (en este hilo: el interceptor no
// necesita cerrojos). Si faltan listas o son viejas, después las descarga.
void ContentBlocker::compile()
{
    if (m_compiling) {
        m_recompile = true;
        return;
    }
    m_compiling = true;
    emit stateChanged();

    QStringList paths;
    QDateTime oldest;
    bool missing = false;
    for (const FilterList &list : Lists) {
        const QString path = filterDir() + QLatin1Char('/') + QLatin1String(list.file);
        const QFileInfo info(path);
        if (!info.exists()) {
            missing = true;
            continue;
        }
        paths.append(path);
        if (!oldest.isValid() || info.lastModified() < oldest)
            oldest = info.lastModified();
    }
    m_updated = oldest;

    auto result = std::make_shared<std::shared_ptr<const FilterEngine>>();
    m_thread = QThread::create([paths, result] {
        QList<QByteArray> texts;
        for (const QString &path : paths) {
            QFile file(path);
            if (file.open(QIODevice::ReadOnly))
                texts.append(file.readAll());
        }
        auto engine = std::make_shared<FilterEngine>();
        engine->build(texts);
        *result = engine;
    });
    connect(m_thread, &QThread::finished, this, [this, result, missing] {
        m_thread->deleteLater();
        m_thread = nullptr;
        m_compiling = false;
        m_engine = *result;
        m_lastPageUrl.clear();
        if (m_recompile) {
            m_recompile = false;
            compile();
            return;
        }
        emit stateChanged();
        if ((m_enabled || m_privateActive) && (missing || listsStale()) && !m_network && !m_autoUpdated) {
            m_autoUpdated = true;
            update(true);
        }
    });
    m_thread->start(QThread::LowPriority);
}

void ContentBlocker::update(bool onlyStale)
{
    if (m_network)
        return;
    QDir().mkpath(filterDir());
    m_downloadQueue.clear();
    const QDateTime now = QDateTime::currentDateTime();
    for (int i = 0; i < int(std::size(Lists)); ++i) {
        const QFileInfo info(filterDir() + QLatin1Char('/') + QLatin1String(Lists[i].file));
        if (!onlyStale || !info.exists() || info.lastModified().secsTo(now) > Lists[i].maxAgeSecs)
            m_downloadQueue.append(i);
    }
    if (m_downloadQueue.isEmpty())
        return;
    m_network = new QNetworkAccessManager(this);
    // Sin el proxy de las páginas (EngineBridge::applyProxy)
    m_network->setProxy(QNetworkProxy::NoProxy);
    emit stateChanged();
    downloadNext();
}

namespace {

// Una página de error (HTML) o una respuesta vacía no es una lista
bool looksLikeList(const QNetworkReply *reply, const QByteArray &data, qsizetype minSize)
{
    return reply->error() == QNetworkReply::NoError && data.size() > minSize && !data.trimmed().startsWith('<');
}

QNetworkRequest listRequest(const QUrl &url)
{
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(60 * 1000);
    return request;
}

// «!#include archivo» de una lista: archivos de la misma carpeta (como
// uBlock Origin, ni direcciones ni «..»)
QList<QByteArray> includesOf(const QByteArray &text)
{
    QList<QByteArray> names;
    if (!text.contains("!#include "))
        return names;
    for (const QByteArray &raw : text.split('\n')) {
        const QByteArray line = raw.trimmed();
        if (!line.startsWith("!#include "))
            continue;
        const QByteArray name = line.mid(10).trimmed().split(' ').first();
        if (!name.isEmpty() && !name.contains(':') && !name.contains("..") && !name.startsWith('/')
            && !names.contains(name))
            names.append(name);
    }
    return names;
}

} // namespace

// Una lista tras otra; la que falle se queda como estaba
void ContentBlocker::downloadNext()
{
    if (!m_network)
        return;
    if (m_downloadQueue.isEmpty()) {
        m_network->deleteLater();
        m_network = nullptr;
        compile();
        return;
    }
    const FilterList &list = Lists[m_downloadQueue.takeFirst()];
    QNetworkReply *reply = m_network->get(listRequest(QUrl(QString::fromLatin1(list.url))));
    const QString path = filterDir() + QLatin1Char('/') + QLatin1String(list.file);
    connect(reply, &QNetworkReply::finished, this, [this, reply, path] {
        reply->deleteLater();
        const QByteArray data = reply->readAll();
        if (!looksLikeList(reply, data, 1000)) {
            qWarning("[Mitis] No se pudo descargar la lista de filtros %s: %s", qPrintable(reply->url().toString()),
                     qPrintable(reply->errorString()));
            downloadNext();
            return;
        }
        if (includesOf(data).isEmpty()) {
            saveList(path, data);
            downloadNext();
        } else {
            downloadIncludes(path, reply->url(), data);
        }
    });
}

struct ContentBlocker::PendingList {
    QString path;
    QUrl base;
    QByteArray text;
    QList<QByteArray> names;
    QHash<QByteArray, QByteArray> parts;
};

// Los «!#include» se descargan uno tras otro y se ponen en el lugar de su
// línea (los «!#if» que los rodean siguen valiendo al compilar). Si falla
// uno, la lista entera se queda como estaba: a medias perdería reglas.
void ContentBlocker::downloadIncludes(const QString &path, const QUrl &base, const QByteArray &text)
{
    auto pending = std::make_shared<PendingList>();
    pending->path = path;
    pending->base = base;
    pending->text = text;
    pending->names = includesOf(text);
    downloadNextInclude(pending);
}

void ContentBlocker::downloadNextInclude(const std::shared_ptr<PendingList> &pending)
{
    if (!m_network)
        return;
    if (pending->parts.size() == pending->names.size()) {
        QByteArray merged;
        qsizetype total = pending->text.size();
        for (const QByteArray &part : std::as_const(pending->parts))
            total += part.size() + 1;
        merged.reserve(total);
        for (const QByteArray &raw : pending->text.split('\n')) {
            const QByteArray line = raw.trimmed();
            const QByteArray name = line.startsWith("!#include ") ? line.mid(10).trimmed().split(' ').first() : QByteArray();
            merged += pending->parts.contains(name) ? pending->parts.value(name) : raw;
            merged += '\n';
        }
        saveList(pending->path, merged);
        downloadNext();
        return;
    }
    const QByteArray name = pending->names.at(pending->parts.size());
    QNetworkReply *reply = m_network->get(listRequest(pending->base.resolved(QUrl(QString::fromUtf8(name)))));
    connect(reply, &QNetworkReply::finished, this, [this, reply, pending, name] {
        reply->deleteLater();
        const QByteArray data = reply->readAll();
        if (!looksLikeList(reply, data, 0)) {
            qWarning("[Mitis] No se pudo descargar la lista de filtros %s: %s", qPrintable(reply->url().toString()),
                     qPrintable(reply->errorString()));
            downloadNext();
            return;
        }
        pending->parts.insert(name, data);
        downloadNextInclude(pending);
    });
}

void ContentBlocker::saveList(const QString &path, const QByteArray &data)
{
    QSaveFile file(path);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(data);
        if (!file.commit())
            qWarning("[Mitis] No se pudo guardar la lista de filtros %s", qPrintable(path));
    }
}

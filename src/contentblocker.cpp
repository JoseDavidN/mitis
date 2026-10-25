#include "contentblocker.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QStandardPaths>
#include <QThread>
#include <QTimer>
#include <QUrlQuery>

namespace {

struct FilterList {
    const char *file;
    const char *url;
};

// El orden no importa: las excepciones de una lista valen para todas
constexpr FilterList Lists[] = {
    { "easylist.txt", "https://easylist.to/easylist/easylist.txt" },
    { "easyprivacy.txt", "https://easylist.to/easylist/easyprivacy.txt" },
    { "easylist-es.txt", "https://easylist-downloads.adblockplus.org/easylistspanish.txt" },
    { "hagezi-pro.txt", "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt" },
    { "ublock-unbreak.txt", "https://ublockorigin.github.io/uAssets/filters/unbreak.txt" },
};
constexpr int ListCount = int(sizeof(Lists) / sizeof(Lists[0]));

// Como EasyList («Expires: 4 days»)
constexpr qint64 MaxAgeSecs = 4 * 24 * 3600;
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
        if ((m_enabled || m_privateActive) && !updating() && (!m_updated.isValid() || m_updated.secsTo(QDateTime::currentDateTime()) > MaxAgeSecs))
            update();
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
    connect(m_thread, &QThread::finished, this, [this, result, missing, oldest] {
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
        const bool old = !oldest.isValid() || oldest.secsTo(QDateTime::currentDateTime()) > MaxAgeSecs;
        if ((m_enabled || m_privateActive) && (missing || old) && !m_network && !m_autoUpdated) {
            m_autoUpdated = true;
            update();
        }
    });
    m_thread->start(QThread::LowPriority);
}

void ContentBlocker::update()
{
    if (m_network)
        return;
    QDir().mkpath(filterDir());
    m_network = new QNetworkAccessManager(this);
    m_downloadIndex = 0;
    emit stateChanged();
    downloadNext();
}

// Una lista tras otra; la que falle se queda como estaba
void ContentBlocker::downloadNext()
{
    if (!m_network)
        return;
    if (m_downloadIndex >= ListCount) {
        m_network->deleteLater();
        m_network = nullptr;
        compile();
        return;
    }
    const FilterList &list = Lists[m_downloadIndex++];
    QNetworkRequest request(QUrl(QString::fromLatin1(list.url)));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(60 * 1000);
    QNetworkReply *reply = m_network->get(request);
    const QString path = filterDir() + QLatin1Char('/') + QLatin1String(list.file);
    connect(reply, &QNetworkReply::finished, this, [this, reply, path] {
        reply->deleteLater();
        const QByteArray data = reply->readAll();
        // Una página de error (HTML) o una respuesta vacía no es una lista
        if (reply->error() == QNetworkReply::NoError && data.size() > 1000 && !data.trimmed().startsWith('<')) {
            QSaveFile file(path);
            if (file.open(QIODevice::WriteOnly)) {
                file.write(data);
                if (!file.commit())
                    qWarning("[Mitis] No se pudo guardar la lista de filtros %s", qPrintable(path));
            }
        } else {
            qWarning("[Mitis] No se pudo descargar la lista de filtros %s: %s", qPrintable(reply->url().toString()),
                     qPrintable(reply->errorString()));
        }
        downloadNext();
    });
}

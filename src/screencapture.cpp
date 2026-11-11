#include "screencapture.h"

#include <QBuffer>
#include <QDateTime>
#include <QImage>
#include <QMetaObject>
#include <QRandomGenerator>
#include <QThread>
#include <QThreadPool>
#include <QTimer>
#include <QWebEngineUrlRequestJob>
#include <QWebEngineUrlScheme>
#include <QtEndian>

#ifdef MITIS_WAYLAND_CAPTURE
#include "waylandcapture.h"
#endif

const QByteArray ScreenCapture::Scheme = QByteArrayLiteral("mitis-captura");

namespace {
// Fotogramas por segundo como mucho (lo normal al compartir pantalla; con la
// pantalla quieta, ninguno) y ancho máximo (más no se ve en una llamada y
// cuesta más de comprimir)
constexpr int MaxFps = 15;
constexpr int MaxWidth = 1920;
// Una petición sin fotograma nuevo espera esto y se responde con el último:
// quien se una a la llamada recibe imagen aunque la pantalla esté quieta
constexpr int WaitMs = 1000;
// Sin peticiones de la página en este tiempo (se cerró, navegó, se cayó),
// la captura termina
constexpr int IdleMs = 6000;

// «https://meet.google.com» (con puerto si no es el de siempre)
QString originOf(const QUrl &url)
{
    QString origin = url.scheme() + QStringLiteral("://") + url.host();
    if (url.port() != -1)
        origin += u':' + QString::number(url.port());
    return origin.toLower();
}
} // namespace

void ScreenCapture::registerScheme()
{
    QWebEngineUrlScheme scheme(Scheme);
    scheme.setSyntax(QWebEngineUrlScheme::Syntax::Host);
    // Lo pide fetch() desde páginas https (segura, con CORS) y no lo frena
    // su política de contenido: la protección es la clave de cada sesión y
    // el origen que se comprueba en requestStarted
    scheme.setFlags(QWebEngineUrlScheme::SecureScheme | QWebEngineUrlScheme::CorsEnabled
                    | QWebEngineUrlScheme::FetchApiAllowed | QWebEngineUrlScheme::ContentSecurityPolicyIgnored);
    QWebEngineUrlScheme::registerScheme(scheme);
}

ScreenCapture::ScreenCapture(QObject *parent)
    : QWebEngineUrlSchemeHandler(parent)
{
}

ScreenCapture::~ScreenCapture()
{
    for (Session *session : std::as_const(m_sessions))
        delete session;
    m_sessions.clear();
#ifdef MITIS_WAYLAND_CAPTURE
    if (m_thread) {
        // WaylandCapture se destruye en su hilo (finished → deleteLater)
        m_thread->quit();
        m_thread->wait();
    }
#endif
}

bool ScreenCapture::available()
{
#ifdef MITIS_WAYLAND_CAPTURE
    if (m_available >= 0)
        return m_available == 1;
    m_thread = new QThread(this);
    m_thread->setObjectName(QStringLiteral("Captura de pantalla"));
    m_capture = new WaylandCapture;
    m_capture->moveToThread(m_thread);
    connect(m_thread, &QThread::finished, m_capture, &QObject::deleteLater);
    connect(m_capture, &WaylandCapture::frame, this, &ScreenCapture::frame, Qt::QueuedConnection);
    connect(m_capture, &WaylandCapture::ended, this, &ScreenCapture::captureEnded, Qt::QueuedConnection);
    m_thread->start();
    bool open = false;
    // Un par de idas y vueltas con el compositor: unos milisegundos
    QMetaObject::invokeMethod(m_capture, &WaylandCapture::open, Qt::BlockingQueuedConnection, &open);
    m_available = open ? 1 : 0;
    if (!open) {
        m_thread->quit();
        m_thread->wait();
        m_thread->deleteLater();
        m_thread = nullptr;
        m_capture = nullptr;
    } else {
        qInfo("Compartir pantalla: captura propia (Wayland, ext-image-copy-capture)");
    }
    return open;
#else
    return false;
#endif
}

QVariantMap ScreenCapture::sources()
{
    QVariantList screens;
    QVariantList windows;
#ifdef MITIS_WAYLAND_CAPTURE
    if (available()) {
        for (const WaylandCapture::Source &source : m_capture->sources()) {
            const QVariantMap item{ { QStringLiteral("id"), source.id },
                                    { QStringLiteral("name"), source.name },
                                    { QStringLiteral("detail"), source.detail } };
            (source.kind == QLatin1String("screen") ? screens : windows).append(item);
        }
    }
#endif
    return { { QStringLiteral("screens"), screens }, { QStringLiteral("windows"), windows } };
}

QString ScreenCapture::start(const QString &kind, quint32 id, const QUrl &page)
{
#ifdef MITIS_WAYLAND_CAPTURE
    if (!available() || page.host().isEmpty())
        return {};
    auto *session = new Session;
    session->id = m_nextId++;
    // 128 bits al azar: la página que la recibe es la única que la conoce
    session->token = QString::fromLatin1(QByteArray::number(QRandomGenerator::system()->generate64(), 16)
                                         + QByteArray::number(QRandomGenerator::system()->generate64(), 16));
    session->origin = originOf(page);
    session->lastRequest = QDateTime::currentMSecsSinceEpoch();
    session->lastCapture = session->lastRequest;
    m_sessions.insert(session->id, session);
    QMetaObject::invokeMethod(m_capture, "start", Qt::QueuedConnection, Q_ARG(int, session->id),
                              Q_ARG(QString, kind), Q_ARG(quint32, id));
    if (!m_watchdog) {
        m_watchdog = new QTimer(this);
        m_watchdog->setInterval(2000);
        connect(m_watchdog, &QTimer::timeout, this, &ScreenCapture::watch);
    }
    m_watchdog->start();
    return session->token;
#else
    Q_UNUSED(kind)
    Q_UNUSED(id)
    Q_UNUSED(page)
    return {};
#endif
}

void ScreenCapture::stop(const QString &token)
{
    if (Session *session = byToken(token))
        finish(session, false);
}

ScreenCapture::Session *ScreenCapture::byToken(const QString &token) const
{
    for (Session *session : m_sessions) {
        if (session->token == token)
            return session;
    }
    return nullptr;
}

void ScreenCapture::frame(int id, const QImage &image)
{
    Session *session = m_sessions.value(id);
    if (!session)
        return;
    session->encoding = true;
    // JPEG fuera del hilo de la interfaz (decenas de ms en un equipo lento)
    const QPointer<ScreenCapture> self(this);
    QThreadPool::globalInstance()->start([self, id, image] {
        QImage scaled = image.width() > MaxWidth ? image.scaledToWidth(MaxWidth, Qt::SmoothTransformation) : image;
        QByteArray jpeg;
        QBuffer buffer(&jpeg);
        buffer.open(QIODevice::WriteOnly);
        scaled.save(&buffer, "JPG", 80);
        if (self)
            QMetaObject::invokeMethod(self, [self, id, jpeg] {
                if (self)
                    self->encoded(id, jpeg);
            }, Qt::QueuedConnection);
    });
}

void ScreenCapture::encoded(int id, const QByteArray &jpeg)
{
    Session *session = m_sessions.value(id);
    if (!session)
        return;
    session->encoding = false;
    if (!jpeg.isEmpty()) {
        session->jpeg = jpeg;
        ++session->sequence;
        const auto waiting = session->waiting;
        session->waiting.clear();
        for (const QPointer<QWebEngineUrlRequestJob> &job : waiting) {
            if (job)
                answer(session, job);
        }
    }
    // El siguiente, sin pasar de MaxFps
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const int wait = int(qMax<qint64>(0, 1000 / MaxFps - (now - session->lastCapture)));
    QTimer::singleShot(wait, this, [this, id] {
        Session *session = m_sessions.value(id);
        if (!session)
            return;
        session->lastCapture = QDateTime::currentMSecsSinceEpoch();
#ifdef MITIS_WAYLAND_CAPTURE
        QMetaObject::invokeMethod(m_capture, "next", Qt::QueuedConnection, Q_ARG(int, id));
#endif
    });
}

void ScreenCapture::captureEnded(int id)
{
    if (Session *session = m_sessions.value(id))
        finish(session, true);
}

void ScreenCapture::finish(Session *session, bool notify)
{
    m_sessions.remove(session->id);
#ifdef MITIS_WAYLAND_CAPTURE
    if (m_capture)
        QMetaObject::invokeMethod(m_capture, "stop", Qt::QueuedConnection, Q_ARG(int, session->id));
#endif
    // Las peticiones que esperaban fallan: la página cierra la pista
    for (const QPointer<QWebEngineUrlRequestJob> &job : std::as_const(session->waiting)) {
        if (job)
            job->fail(QWebEngineUrlRequestJob::UrlNotFound);
    }
    const QString token = session->token;
    delete session;
    if (m_sessions.isEmpty() && m_watchdog)
        m_watchdog->stop();
    if (notify)
        emit ended(token);
}

void ScreenCapture::watch()
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const QList<Session *> sessions = m_sessions.values();
    for (Session *session : sessions) {
        // Peticiones que la página ya canceló (se cerró, navegó)
        session->waiting.removeAll(QPointer<QWebEngineUrlRequestJob>());
        if (session->waiting.isEmpty() && now - session->lastRequest > IdleMs)
            finish(session, true);
    }
}

void ScreenCapture::requestStarted(QWebEngineUrlRequestJob *job)
{
    // mitis-captura://<clave>/<último fotograma recibido>
    const QUrl url = job->requestUrl();
    Session *session = byToken(url.host());
    if (!session) {
        job->fail(QWebEngineUrlRequestJob::UrlNotFound);
        return;
    }
    if (originOf(job->initiator()) != session->origin) {
        job->fail(QWebEngineUrlRequestJob::RequestDenied);
        return;
    }
    session->lastRequest = QDateTime::currentMSecsSinceEpoch();
    const quint64 after = url.path().mid(1).toULongLong();
    if (session->sequence > after) {
        answer(session, job);
        return;
    }
    // Sin nada nuevo: espera al siguiente fotograma o, como mucho, WaitMs
    session->waiting.append(job);
    const int id = session->id;
    const QPointer<QWebEngineUrlRequestJob> guarded(job);
    QTimer::singleShot(WaitMs, this, [this, id, guarded] {
        Session *session = m_sessions.value(id);
        if (!session || !guarded || !session->waiting.contains(guarded) || session->jpeg.isEmpty())
            return;
        session->waiting.removeAll(guarded);
        answer(session, guarded);
    });
}

void ScreenCapture::answer(Session *session, QWebEngineUrlRequestJob *job)
{
    session->lastRequest = QDateTime::currentMSecsSinceEpoch();
    // 8 bytes con el número del fotograma y, detrás, el JPEG
    QByteArray body(8, Qt::Uninitialized);
    qToLittleEndian<quint64>(session->sequence, body.data());
    body.append(session->jpeg);
    auto *buffer = new QBuffer(job);
    buffer->setData(body);
    QMultiMap<QByteArray, QByteArray> headers;
    headers.insert(QByteArrayLiteral("Access-Control-Allow-Origin"), session->origin.toUtf8());
    headers.insert(QByteArrayLiteral("Cache-Control"), QByteArrayLiteral("no-store"));
    job->setAdditionalResponseHeaders(headers);
    job->reply(QByteArrayLiteral("application/octet-stream"), buffer);
}

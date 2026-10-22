#include "links.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFileOpenEvent>
#include <QLocalServer>
#include <QLocalSocket>
#include <QQmlEngine>
#include <QStandardPaths>
#include <QUrl>

namespace {
// Tiempo máximo para hablar con el Mitis abierto
constexpr int TimeoutMs = 2000;
}

Links::Links(QObject *parent)
    : QObject(parent)
{
    // macOS no pasa los enlaces como argumentos: llegan como FileOpen
    if (QCoreApplication::instance())
        QCoreApplication::instance()->installEventFilter(this);
}

Links *Links::instance()
{
    static Links *links = new Links(QCoreApplication::instance());
    return links;
}

Links *Links::create(QQmlEngine *, QJSEngine *)
{
    Links *links = instance();
    // Es de la app, no del motor QML (en --dev hay uno nuevo en cada recarga)
    QQmlEngine::setObjectOwnership(links, QQmlEngine::CppOwnership);
    return links;
}

QString Links::serverName()
{
    // Uno por usuario y carpeta de datos (= perfil de Mitis)
    const QByteArray data = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation).toUtf8();
    return QStringLiteral("mitis-")
        + QString::fromLatin1(QCryptographicHash::hash(data, QCryptographicHash::Sha1).toHex().left(16));
}

QStringList Links::fromArguments(const QStringList &arguments)
{
    QStringList urls;
    // El primero es el propio ejecutable; las opciones empiezan por «-»
    for (qsizetype i = 1; i < arguments.size(); ++i) {
        const QString &argument = arguments.at(i);
        if (argument.isEmpty() || argument.startsWith(QLatin1Char('-')))
            continue;
        const QUrl url = QUrl::fromUserInput(argument, QDir::currentPath(), QUrl::AssumeLocalFile);
        if (url.isValid())
            urls.append(url.toString(QUrl::FullyEncoded));
    }
    return urls;
}

bool Links::forwardToRunning(const QStringList &urls)
{
    QLocalSocket socket;
    socket.connectToServer(serverName());
    if (!socket.waitForConnected(TimeoutMs))
        return false;
    // Una dirección por línea; nada = solo mostrar la ventana
    socket.write(urls.join(QLatin1Char('\n')).toUtf8() + '\n');
    socket.waitForBytesWritten(TimeoutMs);
    socket.disconnectFromServer();
    if (socket.state() != QLocalSocket::UnconnectedState)
        socket.waitForDisconnected(TimeoutMs);
    return true;
}

void Links::listen()
{
    if (m_server)
        return;
    m_server = new QLocalServer(this);
    // Solo el propio usuario puede mandarle enlaces
    m_server->setSocketOptions(QLocalServer::UserAccessOption);
    // Un canal que quedó de un Mitis que se cerró mal (Linux, macOS)
    QLocalServer::removeServer(serverName());
    if (!m_server->listen(serverName())) {
        qWarning("[Mitis] No se pudo escuchar los enlaces de otros Mitis: %s", qPrintable(m_server->errorString()));
        return;
    }
    connect(m_server, &QLocalServer::newConnection, this, [this] {
        while (QLocalSocket *socket = m_server->nextPendingConnection()) {
            connect(socket, &QLocalSocket::disconnected, socket, &QObject::deleteLater);
            // Se lee todo al desconectarse el otro Mitis (el mensaje es corto)
            connect(socket, &QLocalSocket::readChannelFinished, this, [this, socket] {
                QStringList urls;
                for (const QByteArray &line : socket->readAll().split('\n')) {
                    if (!line.trimmed().isEmpty())
                        urls.append(QString::fromUtf8(line.trimmed()));
                }
                add(urls);
            });
        }
    });
}

void Links::add(const QStringList &urls)
{
    m_pending += urls;
    emit received();
}

QStringList Links::takePending()
{
    QStringList urls;
    urls.swap(m_pending);
    return urls;
}

bool Links::eventFilter(QObject *watched, QEvent *event)
{
    if (event->type() == QEvent::FileOpen) {
        const QUrl url = static_cast<QFileOpenEvent *>(event)->url();
        if (url.isValid()) {
            add({ url.toString(QUrl::FullyEncoded) });
            return true;
        }
    }
    return QObject::eventFilter(watched, event);
}

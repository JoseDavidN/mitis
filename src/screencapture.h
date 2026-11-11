#pragma once

#include <QByteArray>
#include <QHash>
#include <QList>
#include <QObject>
#include <QPointer>
#include <QUrl>
#include <QVariantMap>
#include <QWebEngineUrlSchemeHandler>

class QThread;
class QTimer;
class QWebEngineUrlRequestJob;
class WaylandCapture;

// Compartir pantalla propio (Wayland con ext-image-copy-capture: Hyprland,
// Sway, niri, COSMIC), sin el portal del escritorio. WaylandCapture captura
// en su hilo; aquí cada fotograma se comprime a JPEG (en otro hilo) y se
// sirve a la página por el esquema mitis-captura:// (sin red), con una clave
// por sesión que solo vale para el origen que la pidió. La página lo
// convierte en una pista de vídeo (assets/scripts/screenshare.js). Sin
// Wayland o sin esos protocolos, available() es falso y las páginas usan el
// getDisplayMedia del motor (con ScreenShareDialog o el portal).
class ScreenCapture : public QWebEngineUrlSchemeHandler
{
    Q_OBJECT

public:
    explicit ScreenCapture(QObject *parent = nullptr);
    ~ScreenCapture() override;

    // Antes de iniciar el motor (main.cpp)
    static void registerScheme();
    static const QByteArray Scheme;

    // Conecta con el compositor la primera vez
    bool available();
    // { screens: [{ id, name, detail }], windows: [...] }
    QVariantMap sources();
    // Empieza a capturar para la página `page`: la clave de la sesión ("" si no se pudo)
    QString start(const QString &kind, quint32 id, const QUrl &page);
    void stop(const QString &token);

    void requestStarted(QWebEngineUrlRequestJob *job) override;

signals:
    // La captura terminó sin que la página la parara (se cerró la ventana,
    // la página dejó de pedir fotogramas…)
    void ended(const QString &token);

private:
    struct Session {
        int id = 0;
        QString token;
        QString origin;
        QByteArray jpeg;
        quint64 sequence = 0;
        bool encoding = false;
        qint64 lastCapture = 0;
        qint64 lastRequest = 0;
        QList<QPointer<QWebEngineUrlRequestJob>> waiting;
    };

    void frame(int id, const QImage &image);
    void encoded(int id, const QByteArray &jpeg);
    void captureEnded(int id);
    void answer(Session *session, QWebEngineUrlRequestJob *job);
    void finish(Session *session, bool notify);
    void watch();
    Session *byToken(const QString &token) const;

    QThread *m_thread = nullptr;
    WaylandCapture *m_capture = nullptr;
    int m_available = -1;
    int m_nextId = 1;
    QHash<int, Session *> m_sessions;
    QTimer *m_watchdog = nullptr;
};

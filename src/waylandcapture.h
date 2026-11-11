#pragma once

#include <QHash>
#include <QImage>
#include <QList>
#include <QMutex>
#include <QObject>
#include <QString>

struct wl_display;
struct wl_registry;
struct wl_shm;
struct wl_output;
struct ext_image_copy_capture_manager_v1;
struct ext_output_image_capture_source_manager_v1;
struct ext_foreign_toplevel_image_capture_source_manager_v1;
struct ext_foreign_toplevel_list_v1;
struct ext_foreign_toplevel_handle_v1;
class QSocketNotifier;

// Captura de pantallas y ventanas en Wayland con los protocolos estándar
// (ext-image-copy-capture, ext-foreign-toplevel-list; Hyprland, Sway, niri,
// COSMIC), sin el portal del escritorio ni su selector. Su propia conexión
// con el compositor, en su propio hilo (la crea ScreenCapture). Un fotograma
// por vez: pide el siguiente cuando ScreenCapture llama a next(), así nunca
// se acumulan. Fotogramas en memoria compartida (wl_shm), copiados a QImage.
class WaylandCapture : public QObject
{
    Q_OBJECT

public:
    struct Source {
        QString kind;   // "screen" o "window"
        quint32 id = 0;
        QString name;   // pantalla: descripción; ventana: título
        QString detail; // pantalla: «1920 × 1080»; ventana: aplicación
    };

    ~WaylandCapture() override;

    // En su hilo. Conecta con el compositor: false si no hay Wayland o le
    // faltan los protocolos (GNOME, KDE): entonces, el portal de siempre
    Q_INVOKABLE bool open();
    // Pantallas y ventanas que se pueden compartir (desde cualquier hilo)
    QList<Source> sources() const;

    // Llamadas encoladas a su hilo
    Q_INVOKABLE void start(int session, const QString &kind, quint32 id);
    Q_INVOKABLE void stop(int session);
    Q_INVOKABLE void next(int session);

signals:
    void frame(int session, const QImage &image);
    // La sesión terminó por su cuenta: se cerró la ventana, se desconectó la
    // pantalla o el compositor la cortó
    void ended(int session);

public:
    // Para las funciones de los protocolos (C): no usar desde fuera
    struct Output;
    struct Toplevel;
    struct Session;
    void handleGlobal(wl_registry *registry, uint32_t name, const char *interface, uint32_t version);
    void handleGlobalRemove(uint32_t name);
    void handleToplevel(ext_foreign_toplevel_handle_v1 *handle);
    void toplevelClosed(Toplevel *toplevel);
    void publishSources();
    void sessionReady(Session *session);
    void frameReady(Session *session);
    void frameFailed(Session *session, uint32_t reason);
    void endSession(Session *session, bool notify);

private:
    void readEvents();
    void flush();
    void capture(Session *session);
    bool ensureBuffer(Session *session);
    void releaseBuffer(Session *session);
    void closeAll();

    wl_display *m_display = nullptr;
    wl_registry *m_registry = nullptr;
    wl_shm *m_shm = nullptr;
    ext_image_copy_capture_manager_v1 *m_copyManager = nullptr;
    ext_output_image_capture_source_manager_v1 *m_outputSources = nullptr;
    ext_foreign_toplevel_image_capture_source_manager_v1 *m_toplevelSources = nullptr;
    ext_foreign_toplevel_list_v1 *m_toplevelList = nullptr;
    QSocketNotifier *m_notifier = nullptr;

    QList<Output *> m_outputs;
    QList<Toplevel *> m_toplevels;
    quint32 m_nextToplevelId = 1;
    QHash<int, Session *> m_sessions;

    mutable QMutex m_sourcesMutex;
    QList<Source> m_sources;
};

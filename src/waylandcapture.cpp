#include "waylandcapture.h"

#include <QSocketNotifier>
#include <QTimer>
#include <QTransform>
#include <QtDebug>

#include <wayland-client.h>

#include "ext-foreign-toplevel-list-v1-client-protocol.h"
#include "ext-image-capture-source-v1-client-protocol.h"
#include "ext-image-copy-capture-v1-client-protocol.h"

#include <cerrno>
#include <cstring>
#include <sys/mman.h>
#include <unistd.h>

struct WaylandCapture::Output {
    WaylandCapture *owner = nullptr;
    uint32_t globalName = 0;
    wl_output *output = nullptr;
    QString name;        // «DP-1»
    QString description; // «Dell Inc. U2419H (DP-1)»
    int width = 0;
    int height = 0;
};

struct WaylandCapture::Toplevel {
    WaylandCapture *owner = nullptr;
    quint32 id = 0;
    ext_foreign_toplevel_handle_v1 *handle = nullptr;
    QString title;
    QString appId;
};

struct WaylandCapture::Session {
    WaylandCapture *owner = nullptr;
    int id = 0;
    ext_image_capture_source_v1 *source = nullptr;
    ext_image_copy_capture_session_v1 *session = nullptr;
    ext_image_copy_capture_frame_v1 *frame = nullptr;
    // Lo que pide el compositor (session: buffer_size, shm_format, done)
    int width = 0;
    int height = 0;
    QList<uint32_t> formats;
    // Los formatos llegan uno a uno antes de «done», en cualquier orden con el tamaño
    QList<uint32_t> pendingFormats;
    bool constraintsKnown = false;
    // El búfer actual
    wl_buffer *buffer = nullptr;
    void *data = nullptr;
    size_t size = 0;
    int bufferWidth = 0;
    int bufferHeight = 0;
    uint32_t bufferFormat = 0;
    uint32_t transform = WL_OUTPUT_TRANSFORM_NORMAL;
    // ScreenCapture quiere otro fotograma (next) y aún no se ha pedido
    bool wanted = true;
};

namespace {

// ── Registro y pantallas ──────────────────────────────────────────────

void registryGlobal(void *data, wl_registry *registry, uint32_t name, const char *interface, uint32_t version)
{
    static_cast<WaylandCapture *>(data)->handleGlobal(registry, name, interface, version);
}

void registryGlobalRemove(void *data, wl_registry *, uint32_t name)
{
    static_cast<WaylandCapture *>(data)->handleGlobalRemove(name);
}

const wl_registry_listener registryListener = { registryGlobal, registryGlobalRemove };

void outputGeometry(void *, wl_output *, int32_t, int32_t, int32_t, int32_t, int32_t, const char *, const char *, int32_t) {}

void outputMode(void *data, wl_output *, uint32_t flags, int32_t width, int32_t height, int32_t)
{
    if (!(flags & WL_OUTPUT_MODE_CURRENT))
        return;
    auto *output = static_cast<WaylandCapture::Output *>(data);
    output->width = width;
    output->height = height;
}

void outputDone(void *data, wl_output *)
{
    static_cast<WaylandCapture::Output *>(data)->owner->publishSources();
}

void outputScale(void *, wl_output *, int32_t) {}

void outputName(void *data, wl_output *, const char *name)
{
    static_cast<WaylandCapture::Output *>(data)->name = QString::fromUtf8(name);
}

void outputDescription(void *data, wl_output *, const char *description)
{
    static_cast<WaylandCapture::Output *>(data)->description = QString::fromUtf8(description);
}

const wl_output_listener outputListener = { outputGeometry, outputMode, outputDone, outputScale, outputName, outputDescription };

// ── Ventanas ──────────────────────────────────────────────────────────

void listToplevel(void *data, ext_foreign_toplevel_list_v1 *, ext_foreign_toplevel_handle_v1 *handle)
{
    static_cast<WaylandCapture *>(data)->handleToplevel(handle);
}

void listFinished(void *, ext_foreign_toplevel_list_v1 *) {}

const ext_foreign_toplevel_list_v1_listener listListener = { listToplevel, listFinished };

void toplevelClosed(void *data, ext_foreign_toplevel_handle_v1 *)
{
    auto *toplevel = static_cast<WaylandCapture::Toplevel *>(data);
    toplevel->owner->toplevelClosed(toplevel);
}

void toplevelDone(void *data, ext_foreign_toplevel_handle_v1 *)
{
    static_cast<WaylandCapture::Toplevel *>(data)->owner->publishSources();
}

void toplevelTitle(void *data, ext_foreign_toplevel_handle_v1 *, const char *title)
{
    static_cast<WaylandCapture::Toplevel *>(data)->title = QString::fromUtf8(title);
}

void toplevelAppId(void *data, ext_foreign_toplevel_handle_v1 *, const char *appId)
{
    static_cast<WaylandCapture::Toplevel *>(data)->appId = QString::fromUtf8(appId);
}

void toplevelIdentifier(void *, ext_foreign_toplevel_handle_v1 *, const char *) {}

const ext_foreign_toplevel_handle_v1_listener toplevelListener = {
    toplevelClosed, toplevelDone, toplevelTitle, toplevelAppId, toplevelIdentifier
};

// ── Sesión de captura ─────────────────────────────────────────────────

void sessionBufferSize(void *data, ext_image_copy_capture_session_v1 *, uint32_t width, uint32_t height)
{
    auto *session = static_cast<WaylandCapture::Session *>(data);
    session->width = int(width);
    session->height = int(height);
}

void sessionShmFormat(void *data, ext_image_copy_capture_session_v1 *, uint32_t format)
{
    static_cast<WaylandCapture::Session *>(data)->pendingFormats.append(format);
}

void sessionDmabufDevice(void *, ext_image_copy_capture_session_v1 *, wl_array *) {}
void sessionDmabufFormat(void *, ext_image_copy_capture_session_v1 *, uint32_t, wl_array *) {}

void sessionDone(void *data, ext_image_copy_capture_session_v1 *)
{
    auto *session = static_cast<WaylandCapture::Session *>(data);
    session->formats = session->pendingFormats;
    session->pendingFormats.clear();
    session->constraintsKnown = true;
    session->owner->sessionReady(session);
}

void sessionStopped(void *data, ext_image_copy_capture_session_v1 *)
{
    auto *session = static_cast<WaylandCapture::Session *>(data);
    session->owner->endSession(session, true);
}

const ext_image_copy_capture_session_v1_listener sessionListener = {
    sessionBufferSize, sessionShmFormat, sessionDmabufDevice, sessionDmabufFormat, sessionDone, sessionStopped
};

void frameTransform(void *data, ext_image_copy_capture_frame_v1 *, uint32_t transform)
{
    static_cast<WaylandCapture::Session *>(data)->transform = transform;
}

void frameDamage(void *, ext_image_copy_capture_frame_v1 *, int32_t, int32_t, int32_t, int32_t) {}
void framePresentationTime(void *, ext_image_copy_capture_frame_v1 *, uint32_t, uint32_t, uint32_t) {}

void frameReadyEvent(void *data, ext_image_copy_capture_frame_v1 *)
{
    auto *session = static_cast<WaylandCapture::Session *>(data);
    session->owner->frameReady(session);
}

void frameFailedEvent(void *data, ext_image_copy_capture_frame_v1 *, uint32_t reason)
{
    auto *session = static_cast<WaylandCapture::Session *>(data);
    session->owner->frameFailed(session, reason);
}

const ext_image_copy_capture_frame_v1_listener frameListener = {
    frameTransform, frameDamage, framePresentationTime, frameReadyEvent, frameFailedEvent
};

// Formatos de memoria compartida que entiende QImage sin convertir
// (en memoria, little-endian): XRGB/ARGB = B,G,R,X; XBGR/ABGR = R,G,B,X
QImage::Format imageFormat(uint32_t format)
{
    switch (format) {
    case WL_SHM_FORMAT_XRGB8888:
    case WL_SHM_FORMAT_ARGB8888:
        return QImage::Format_RGB32;
    case WL_SHM_FORMAT_XBGR8888:
    case WL_SHM_FORMAT_ABGR8888:
        return QImage::Format_RGBX8888;
    default:
        return QImage::Format_Invalid;
    }
}

} // namespace

WaylandCapture::~WaylandCapture()
{
    closeAll();
}

bool WaylandCapture::open()
{
    if (m_display)
        return m_copyManager && m_outputSources && m_shm;
    // Sin sesión de Wayland, wl_display_connect probaría «wayland-0»
    if (qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY") && qEnvironmentVariableIsEmpty("WAYLAND_SOCKET"))
        return false;
    m_display = wl_display_connect(nullptr);
    if (!m_display)
        return false;
    m_registry = wl_display_get_registry(m_display);
    wl_registry_add_listener(m_registry, &registryListener, this);
    // Primero los globales; después, los datos de pantallas y ventanas
    wl_display_roundtrip(m_display);
    wl_display_roundtrip(m_display);
    if (!m_copyManager || !m_outputSources || !m_shm) {
        closeAll();
        return false;
    }
    publishSources();
    m_notifier = new QSocketNotifier(wl_display_get_fd(m_display), QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &WaylandCapture::readEvents);
    return true;
}

void WaylandCapture::handleGlobal(wl_registry *registry, uint32_t name, const char *interface, uint32_t version)
{
    const QByteArray id(interface);
    if (id == wl_shm_interface.name) {
        m_shm = static_cast<wl_shm *>(wl_registry_bind(registry, name, &wl_shm_interface, 1));
    } else if (id == wl_output_interface.name && version >= 4) {
        // v4: nombre y descripción de la pantalla
        auto *output = new Output;
        output->owner = this;
        output->globalName = name;
        output->output = static_cast<wl_output *>(wl_registry_bind(registry, name, &wl_output_interface, 4));
        wl_output_add_listener(output->output, &outputListener, output);
        m_outputs.append(output);
    } else if (id == ext_image_copy_capture_manager_v1_interface.name) {
        m_copyManager = static_cast<ext_image_copy_capture_manager_v1 *>(
            wl_registry_bind(registry, name, &ext_image_copy_capture_manager_v1_interface, 1));
    } else if (id == ext_output_image_capture_source_manager_v1_interface.name) {
        m_outputSources = static_cast<ext_output_image_capture_source_manager_v1 *>(
            wl_registry_bind(registry, name, &ext_output_image_capture_source_manager_v1_interface, 1));
    } else if (id == ext_foreign_toplevel_image_capture_source_manager_v1_interface.name) {
        m_toplevelSources = static_cast<ext_foreign_toplevel_image_capture_source_manager_v1 *>(
            wl_registry_bind(registry, name, &ext_foreign_toplevel_image_capture_source_manager_v1_interface, 1));
    } else if (id == ext_foreign_toplevel_list_v1_interface.name) {
        m_toplevelList = static_cast<ext_foreign_toplevel_list_v1 *>(
            wl_registry_bind(registry, name, &ext_foreign_toplevel_list_v1_interface, 1));
        ext_foreign_toplevel_list_v1_add_listener(m_toplevelList, &listListener, this);
    }
}

void WaylandCapture::handleGlobalRemove(uint32_t name)
{
    for (qsizetype i = 0; i < m_outputs.size(); ++i) {
        Output *output = m_outputs.at(i);
        if (output->globalName != name)
            continue;
        // Las sesiones de esa pantalla reciben «stopped» del compositor
        wl_output_release(output->output);
        delete output;
        m_outputs.removeAt(i);
        publishSources();
        return;
    }
}

void WaylandCapture::handleToplevel(ext_foreign_toplevel_handle_v1 *handle)
{
    auto *toplevel = new Toplevel;
    toplevel->owner = this;
    toplevel->id = m_nextToplevelId++;
    toplevel->handle = handle;
    ext_foreign_toplevel_handle_v1_add_listener(handle, &toplevelListener, toplevel);
    m_toplevels.append(toplevel);
}

void WaylandCapture::toplevelClosed(Toplevel *toplevel)
{
    m_toplevels.removeOne(toplevel);
    ext_foreign_toplevel_handle_v1_destroy(toplevel->handle);
    delete toplevel;
    publishSources();
}

void WaylandCapture::publishSources()
{
    QList<Source> list;
    for (const Output *output : std::as_const(m_outputs)) {
        Source source;
        source.kind = QStringLiteral("screen");
        source.id = output->globalName;
        source.name = output->description.isEmpty() ? output->name : output->description;
        if (output->width > 0)
            source.detail = QStringLiteral("%1 × %2").arg(output->width).arg(output->height);
        list.append(source);
    }
    if (m_toplevelSources) {
        for (const Toplevel *toplevel : std::as_const(m_toplevels)) {
            if (toplevel->title.isEmpty() && toplevel->appId.isEmpty())
                continue;
            Source source;
            source.kind = QStringLiteral("window");
            source.id = toplevel->id;
            source.name = toplevel->title.isEmpty() ? toplevel->appId : toplevel->title;
            source.detail = toplevel->appId;
            list.append(source);
        }
    }
    const QMutexLocker lock(&m_sourcesMutex);
    m_sources = list;
}

QList<WaylandCapture::Source> WaylandCapture::sources() const
{
    const QMutexLocker lock(&m_sourcesMutex);
    return m_sources;
}

void WaylandCapture::start(int id, const QString &kind, quint32 sourceId)
{
    ext_image_capture_source_v1 *source = nullptr;
    if (kind == QLatin1String("screen")) {
        for (const Output *output : std::as_const(m_outputs)) {
            if (output->globalName == sourceId)
                source = ext_output_image_capture_source_manager_v1_create_source(m_outputSources, output->output);
        }
    } else if (kind == QLatin1String("window") && m_toplevelSources) {
        for (const Toplevel *toplevel : std::as_const(m_toplevels)) {
            if (toplevel->id == sourceId)
                source = ext_foreign_toplevel_image_capture_source_manager_v1_create_source(m_toplevelSources, toplevel->handle);
        }
    }
    if (!source) {
        emit ended(id);
        return;
    }
    auto *session = new Session;
    session->owner = this;
    session->id = id;
    session->source = source;
    // Con el puntero dibujado, como al compartir en Chrome
    session->session = ext_image_copy_capture_manager_v1_create_session(
        m_copyManager, source, EXT_IMAGE_COPY_CAPTURE_MANAGER_V1_OPTIONS_PAINT_CURSORS);
    ext_image_copy_capture_session_v1_add_listener(session->session, &sessionListener, session);
    m_sessions.insert(id, session);
    flush();
}

void WaylandCapture::stop(int id)
{
    if (Session *session = m_sessions.value(id))
        endSession(session, false);
}

void WaylandCapture::next(int id)
{
    Session *session = m_sessions.value(id);
    if (!session)
        return;
    session->wanted = true;
    if (session->constraintsKnown && !session->frame)
        capture(session);
}

void WaylandCapture::sessionReady(Session *session)
{
    // Las condiciones cambiaron (p. ej., la ventana cambió de tamaño): el
    // búfer se rehace al pedir el siguiente
    if (session->wanted && !session->frame)
        capture(session);
}

bool WaylandCapture::ensureBuffer(Session *session)
{
    uint32_t format = 0;
    bool found = false;
    for (const uint32_t preferred : { WL_SHM_FORMAT_XRGB8888, WL_SHM_FORMAT_ARGB8888,
                                      WL_SHM_FORMAT_XBGR8888, WL_SHM_FORMAT_ABGR8888 }) {
        if (session->formats.contains(preferred)) {
            format = preferred;
            found = true;
            break;
        }
    }
    if (!found || session->width <= 0 || session->height <= 0)
        return false;
    if (session->buffer && session->bufferWidth == session->width && session->bufferHeight == session->height
        && session->bufferFormat == format)
        return true;
    releaseBuffer(session);

    const int stride = session->width * 4;
    const size_t size = size_t(stride) * size_t(session->height);
    const int fd = memfd_create("mitis-captura", MFD_CLOEXEC);
    if (fd < 0)
        return false;
    if (ftruncate(fd, off_t(size)) < 0) {
        close(fd);
        return false;
    }
    void *data = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (data == MAP_FAILED) {
        close(fd);
        return false;
    }
    wl_shm_pool *pool = wl_shm_create_pool(m_shm, fd, int32_t(size));
    session->buffer = wl_shm_pool_create_buffer(pool, 0, session->width, session->height, stride, format);
    wl_shm_pool_destroy(pool);
    close(fd);
    session->data = data;
    session->size = size;
    session->bufferWidth = session->width;
    session->bufferHeight = session->height;
    session->bufferFormat = format;
    return true;
}

void WaylandCapture::releaseBuffer(Session *session)
{
    if (session->buffer)
        wl_buffer_destroy(session->buffer);
    if (session->data)
        munmap(session->data, session->size);
    session->buffer = nullptr;
    session->data = nullptr;
    session->size = 0;
}

void WaylandCapture::capture(Session *session)
{
    if (!ensureBuffer(session)) {
        QStringList offered;
        for (const uint32_t format : std::as_const(session->formats))
            offered.append(QStringLiteral("0x%1").arg(format, 0, 16));
        qWarning("Compartir pantalla: el compositor no ofrece un formato que Mitis entienda (%dx%d; %s)",
                 session->width, session->height, qPrintable(offered.join(u' ')));
        endSession(session, true);
        return;
    }
    session->wanted = false;
    session->transform = WL_OUTPUT_TRANSFORM_NORMAL;
    session->frame = ext_image_copy_capture_session_v1_create_frame(session->session);
    ext_image_copy_capture_frame_v1_add_listener(session->frame, &frameListener, session);
    ext_image_copy_capture_frame_v1_attach_buffer(session->frame, session->buffer);
    ext_image_copy_capture_frame_v1_damage_buffer(session->frame, 0, 0, session->bufferWidth, session->bufferHeight);
    // El compositor responde cuando hay algo nuevo que enseñar: con la
    // pantalla quieta no llegan fotogramas (ni se gasta nada)
    ext_image_copy_capture_frame_v1_capture(session->frame);
    flush();
}

void WaylandCapture::frameReady(Session *session)
{
    ext_image_copy_capture_frame_v1_destroy(session->frame);
    session->frame = nullptr;
    QImage image = QImage(static_cast<const uchar *>(session->data), session->bufferWidth, session->bufferHeight,
                          session->bufferWidth * 4, imageFormat(session->bufferFormat))
                       .copy();
    // Pantallas giradas o volteadas: como las ve quien las usa (sin probar
    // en una pantalla girada)
    if (session->transform != WL_OUTPUT_TRANSFORM_NORMAL) {
        QTransform transform;
        if (session->transform >= WL_OUTPUT_TRANSFORM_FLIPPED)
            transform.scale(-1, 1);
        transform.rotate(-90.0 * (int(session->transform) % 4));
        image = image.transformed(transform);
    }
    emit frame(session->id, image);
}

void WaylandCapture::frameFailed(Session *session, uint32_t reason)
{
    ext_image_copy_capture_frame_v1_destroy(session->frame);
    session->frame = nullptr;
    if (reason == EXT_IMAGE_COPY_CAPTURE_FRAME_V1_FAILURE_REASON_STOPPED) {
        endSession(session, true);
        return;
    }
    // Cambió el tamaño: llegan otras condiciones (done) y se vuelve a pedir
    session->wanted = true;
    if (reason == EXT_IMAGE_COPY_CAPTURE_FRAME_V1_FAILURE_REASON_UNKNOWN) {
        const int id = session->id;
        QTimer::singleShot(100, this, [this, id] { next(id); });
    }
}

void WaylandCapture::endSession(Session *session, bool notify)
{
    m_sessions.remove(session->id);
    if (session->frame)
        ext_image_copy_capture_frame_v1_destroy(session->frame);
    ext_image_copy_capture_session_v1_destroy(session->session);
    ext_image_capture_source_v1_destroy(session->source);
    releaseBuffer(session);
    flush();
    const int id = session->id;
    delete session;
    if (notify)
        emit ended(id);
}

void WaylandCapture::readEvents()
{
    if (wl_display_prepare_read(m_display) == 0)
        wl_display_read_events(m_display);
    wl_display_dispatch_pending(m_display);
    flush();
    // Se cerró el compositor (o la conexión falló): todo termina
    if (wl_display_get_error(m_display) != 0) {
        qWarning("Compartir pantalla: se perdió la conexión con el compositor (%s)", strerror(wl_display_get_error(m_display)));
        const QList<int> ids = m_sessions.keys();
        closeAll();
        for (const int id : ids)
            emit ended(id);
    }
}

void WaylandCapture::flush()
{
    if (m_display)
        wl_display_flush(m_display);
}

void WaylandCapture::closeAll()
{
    if (!m_display)
        return;
    delete m_notifier;
    m_notifier = nullptr;
    for (Session *session : m_sessions.values())
        endSession(session, false);
    for (Toplevel *toplevel : std::as_const(m_toplevels)) {
        ext_foreign_toplevel_handle_v1_destroy(toplevel->handle);
        delete toplevel;
    }
    m_toplevels.clear();
    for (Output *output : std::as_const(m_outputs)) {
        wl_output_release(output->output);
        delete output;
    }
    m_outputs.clear();
    if (m_toplevelList)
        ext_foreign_toplevel_list_v1_destroy(m_toplevelList);
    if (m_toplevelSources)
        ext_foreign_toplevel_image_capture_source_manager_v1_destroy(m_toplevelSources);
    if (m_outputSources)
        ext_output_image_capture_source_manager_v1_destroy(m_outputSources);
    if (m_copyManager)
        ext_image_copy_capture_manager_v1_destroy(m_copyManager);
    if (m_shm)
        wl_shm_destroy(m_shm);
    wl_registry_destroy(m_registry);
    wl_display_disconnect(m_display);
    m_display = nullptr;
    m_registry = nullptr;
    m_shm = nullptr;
    m_copyManager = nullptr;
    m_outputSources = nullptr;
    m_toplevelSources = nullptr;
    m_toplevelList = nullptr;
    const QMutexLocker lock(&m_sourcesMutex);
    m_sources.clear();
}

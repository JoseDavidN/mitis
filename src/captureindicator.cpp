#include "captureindicator.h"

#include <QFile>
#include <QGuiApplication>
#include <QPainter>
#include <QPixmap>
#include <QSvgRenderer>
#include <QWindow>

#include <algorithm>

namespace {
// Icono de la aplicación (main.cpp) e iconos de la marca (assets/icons)
const QString BaseIcon = QStringLiteral(":/branding/mitis.png");
// Rojo de aviso: el `dangerStrong` de Nocturno (Theme.qml). El icono de la
// barra de tareas no cambia con el tema
const QColor MarkColor(0xf4, 0x3f, 0x5e);
// Tamaños a los que se dibuja: el sistema elige el que necesita
constexpr int Sizes[] = { 16, 20, 24, 32, 40, 48, 64, 128, 256 };
// Parpadeo: tiempo que dura cada fase (con la marca y sin ella)
constexpr int BlinkMs = 700;
}

CaptureIndicator::CaptureIndicator(QObject *parent)
    : QObject(parent)
    , m_base(BaseIcon)
{
    m_blink.setInterval(BlinkMs);
    connect(&m_blink, &QTimer::timeout, this, [this] { showMarked(!m_markShown); });
}

CaptureIndicator::~CaptureIndicator()
{
    // En --dev se crea otro con cada recarga: que no quede la marca puesta
    if (m_markShown)
        showMarked(false);
}

void CaptureIndicator::report(QObject *source, int microphone, int camera)
{
    if (!source)
        return;
    microphone = std::clamp(microphone, int(Off), int(Active));
    camera = std::clamp(camera, int(Off), int(Active));

    if (microphone == Off && camera == Off) {
        if (m_sources.remove(source))
            disconnect(source, &QObject::destroyed, this, nullptr);
    } else {
        if (!m_sources.contains(source)) {
            // Una pestaña que se cierra deja de usar lo que usara
            connect(source, &QObject::destroyed, this, [this, source] {
                m_sources.remove(source);
                update();
            });
        }
        m_sources.insert(source, { microphone, camera });
    }
    update();
}

void CaptureIndicator::update()
{
    int microphone = Off;
    int camera = Off;
    for (const auto &state : std::as_const(m_sources)) {
        microphone = std::max(microphone, state.first);
        camera = std::max(camera, state.second);
    }

    if (microphone != m_microphone || camera != m_camera) {
        m_microphone = microphone;
        m_camera = camera;
        emit changed();
    }

    if (microphone == Off && camera == Off) {
        m_blink.stop();
        showMarked(false);
        return;
    }

    const QString glyph = microphone != Off && camera != Off ? QStringLiteral("camera-microphone")
                          : camera != Off                    ? QStringLiteral("camera")
                                                             : QStringLiteral("microphone");
    if (glyph != m_markedGlyph) {
        m_marked = markedIcon(glyph);
        m_markedGlyph = glyph;
        m_markShown = false; // para que showMarked lo vuelva a poner
    }

    // Parpadea mientras algo está en uso; silenciado, la marca queda fija
    if (microphone == Active || camera == Active) {
        if (!m_blink.isActive()) {
            showMarked(true);
            m_blink.start();
        }
    } else {
        m_blink.stop();
        showMarked(true);
    }
}

void CaptureIndicator::showMarked(bool marked)
{
    if (marked == m_markShown)
        return;
    m_markShown = marked;
    const QIcon &icon = marked ? m_marked : m_base;
    // El de la aplicación (ventanas que se abran ahora) y el de cada ventana
    // abierta: cambiar solo el de la aplicación no siempre llega a las que ya
    // existen
    QGuiApplication::setWindowIcon(icon);
    const auto windows = QGuiApplication::topLevelWindows();
    for (QWindow *window : windows)
        window->setIcon(icon);
}

QIcon CaptureIndicator::markedIcon(const QString &glyph) const
{
    // Silueta blanca de assets/icons (Lucide, trazo en currentColor)
    QByteArray svg;
    QFile file(QStringLiteral(":/icons/%1.svg").arg(glyph));
    if (file.open(QIODevice::ReadOnly))
        svg = file.readAll().replace("currentColor", "#ffffff");
    QSvgRenderer renderer(svg);

    const QPixmap source(BaseIcon);
    QIcon icon;
    for (const int size : Sizes) {
        QPixmap pixmap = source.scaled(size, size, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        QPainter painter(&pixmap);
        painter.setRenderHint(QPainter::Antialiasing);

        // Círculo rojo abajo a la derecha, más de la mitad del icono para que
        // se vea a 16 px, con el símbolo dentro
        const qreal diameter = size * 0.62;
        const QRectF circle(size - diameter, size - diameter, diameter, diameter);
        painter.setPen(Qt::NoPen);
        painter.setBrush(MarkColor);
        painter.drawEllipse(circle);
        if (renderer.isValid() && size >= 20) {
            const qreal inset = diameter * 0.2;
            renderer.render(&painter, circle.adjusted(inset, inset, -inset, -inset));
        }
        painter.end();
        icon.addPixmap(pixmap);
    }
    return icon;
}

#include "navigationgestures.h"

#include <QGuiApplication>
#include <QMouseEvent>
#include <QNativeGestureEvent>
#include <QWheelEvent>
#include <QWindow>

#include <algorithm>
#include <cmath>

namespace {
// Recorrido (en puntos) antes de decidir si el gesto es horizontal: los
// primeros eventos casi nunca son rectos
constexpr qreal LockDistance = 12;
// Horizontal si lo es al menos tanto más que vertical
constexpr qreal HorizontalRatio = 1.5;
// Recorrido horizontal con el que soltar ya navega
constexpr qreal NavigateDistance = 140;
}

NavigationGestures::NavigationGestures(QObject *parent)
    : QObject(parent)
{
    // Se quita solo al destruirse (en --dev, con cada recarga)
    qApp->installEventFilter(this);
}

bool NavigationGestures::eventFilter(QObject *watched, QEvent *event)
{
    // Cada evento pasa por el filtro al llegar a la ventana y otra vez al
    // repartirlo esta entre sus elementos: solo cuenta el primero
    if (!watched->isWindowType())
        return false;
    auto *window = static_cast<QWindow *>(watched);

    switch (event->type()) {
    case QEvent::MouseButtonRelease: {
        const auto button = static_cast<QMouseEvent *>(event)->button();
        if (button == Qt::BackButton)
            emit navigateRequested(window, -1);
        else if (button == Qt::ForwardButton)
            emit navigateRequested(window, 1);
        break;
    }
#if QT_CONFIG(gestures)
    case QEvent::NativeGesture: {
        // Tres dedos (macOS): Qt da el ángulo; 180 es hacia la izquierda, que
        // en el sistema es atrás
        auto *gesture = static_cast<QNativeGestureEvent *>(event);
        if (gesture->gestureType() != Qt::SwipeNativeGesture)
            break;
        if (qFuzzyCompare(gesture->value(), 180.0))
            emit navigateRequested(window, -1);
        else if (qFuzzyIsNull(gesture->value()))
            emit navigateRequested(window, 1);
        break;
    }
#endif
    case QEvent::Wheel: {
        // Solo los desplazamientos con fases (panel táctil, Magic Mouse): la
        // rueda de un ratón no las tiene
        auto *wheel = static_cast<QWheelEvent *>(event);
        Swipe &swipe = m_swipes[window];
        const Qt::ScrollPhase phase = wheel->phase();
        if (phase == Qt::NoScrollPhase)
            break;
        if (phase == Qt::ScrollBegin) {
            swipe = Swipe();
            swipe.finished = false;
            // Con Ctrl (zoom) o sin el ajuste del sistema, no es para navegar
            swipe.ignored = wheel->modifiers() != Qt::NoModifier || !swipeFromScrollEnabled();
        }
        if (swipe.finished || swipe.ignored)
            break;

        // Al soltar llega la inercia (ScrollMomentum) o el final: decide ahí
        if (phase == Qt::ScrollMomentum || phase == Qt::ScrollEnd) {
            swipe.finished = true;
            if (swipe.direction != 0) {
                const qreal travel = -swipe.direction * swipe.x;
                emit swipeFinished(window, travel >= NavigateDistance);
            }
            break;
        }

        swipe.x += wheel->pixelDelta().x();
        swipe.y += wheel->pixelDelta().y();
        if (swipe.direction == 0) {
            if (std::abs(swipe.x) + std::abs(swipe.y) < LockDistance)
                break;
            if (std::abs(swipe.x) <= HorizontalRatio * std::abs(swipe.y)) {
                swipe.ignored = true;
                break;
            }
            // Positivo: la página se desplazaría hacia la izquierda, hacia
            // donde está lo anterior (como Chrome al pasarse del borde)
            swipe.direction = swipe.x > 0 ? -1 : 1;
        }
        const qreal travel = std::max<qreal>(0, -swipe.direction * swipe.x);
        emit swipeUpdated(window, swipe.direction, travel / NavigateDistance);
        break;
    }
    default:
        break;
    }
    return false;
}

#ifndef Q_OS_MACOS
// Fuera de macOS el panel táctil no da fases fiables (Windows no las da):
// ahí quedan los botones del ratón
bool NavigationGestures::swipeFromScrollEnabled()
{
    return false;
}
#endif

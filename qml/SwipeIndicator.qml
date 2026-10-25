import QtQuick
import Mitis.Core

// Deslizar entre páginas (macOS, dos dedos): un relieve que sale del borde
// del lado hacia el que se va (izquierdo: atrás; derecho: adelante) al ritmo
// del gesto: una cúpula larga y suave con la flecha dentro, con los colores
// de los controles del tema. Cuando soltar ya
// navega, la flecha toma el color de acento. Al soltar vuelve a entrar en el
// borde. Centrado en vertical en su padre, pegado a su borde.
Item {
    id: root

    // -1 atrás (borde izquierdo), 1 adelante (borde derecho)
    property int direction: -1
    // Avance del gesto: con 1, soltar navega
    property real progress: 0
    property bool shown: false
    readonly property bool ready: progress >= 1

    // Cuánto ha salido del borde; al terminar, vuelve con animación
    readonly property real _target: shown ? Math.min(progress, 1) * Theme.swipeBumpDepth : 0
    property real depth: _target
    Behavior on depth {
        enabled: root._target === 0
        NumberAnimation { duration: Theme.durationBase; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
    }

    width: Theme.swipeBumpDepth
    height: Theme.swipeBumpLength
    anchors.verticalCenter: parent.verticalCenter
    x: direction < 0 ? 0 : parent.width - width
    visible: depth > 0.5

    // Una cúpula: sale del borde en vertical, donde se funde con él, y llega
    // a su cima en el centro, también en vertical; sin bordes
    SurfaceShape {
        width: root.depth
        height: parent.height
        x: root.direction < 0 ? 0 : parent.width - width
        fillStart: Colors.controlsStart
        fillEnd: Colors.controlsEnd
        path: {
            const h = height, k = h * Theme.swipeBumpCurve
            // Desde el borde de la ventana (x = edge) hacia dentro (x = out)
            const edge = root.direction < 0 ? 0 : width
            const out = root.direction < 0 ? width : 0
            return `M ${edge} 0 C ${edge} ${k} ${out} ${h / 2 - k} ${out} ${h / 2} `
                 + `C ${out} ${h / 2 + k} ${edge} ${h - k} ${edge} ${h} Z`
        }
    }

    // Flecha gruesa y redondeada: aparece y crece con el gesto, centrada en lo
    // que ya ha salido (así no queda pegada al borde)
    Icon {
        readonly property real shown: Math.max(0, Math.min(1, (root.depth / root.width - 0.3) / 0.5))
        anchors.verticalCenter: parent.verticalCenter
        x: (root.direction < 0 ? root.depth * 0.5 : root.width - root.depth * 0.5) - width / 2
        name: root.direction < 0 ? "swipe-back" : "swipe-forward"
        size: Theme.swipeArrowSize
        opacity: shown
        scale: 0.6 + 0.4 * shown
        color: root.ready ? Colors.brandLight1 : Colors.ink
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }
}

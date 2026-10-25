import QtQuick

// Flecha de deslizar entre páginas (macOS, dos dedos): entra desde el borde
// del lado hacia el que se va, al ritmo del gesto, y cuando soltar ya navega
// se rellena con el degradado de la marca. Centrada en vertical en su padre.
Item {
    id: root

    // -1 atrás (borde izquierdo), 1 adelante (borde derecho)
    property int direction: -1
    // Avance del gesto: con 1, soltar navega
    property real progress: 0
    property bool shown: false
    readonly property bool ready: progress >= 1

    readonly property real _travel: Math.min(progress, 1) * (width + Theme.margin)

    width: Theme.swipeIndicatorSize
    height: width
    anchors.verticalCenter: parent.verticalCenter
    x: direction < 0 ? -width + _travel : parent.width - _travel
    visible: shown && progress > 0
    opacity: Math.min(1, progress * 2)
    scale: ready ? Theme.swipeIndicatorReadyScale : 1
    Behavior on scale { NumberAnimation { duration: Theme.durationFast } }

    Surface {
        id: surface
        anchors.fill: parent
        radius: width / 2
        fillStart: root.ready ? Theme.brand1 : Theme.controlsStart
        fillEnd: root.ready ? Theme.brand2 : Theme.controlsEnd
        Behavior on fillStart { ColorAnimation { duration: Theme.durationFast } }
        Behavior on fillEnd { ColorAnimation { duration: Theme.durationFast } }
    }

    Icon {
        anchors.centerIn: parent
        name: root.direction < 0 ? "back" : "forward"
        // Con el vidrio no se ve el degradado: la flecha toma el color de la marca
        color: !root.ready ? Theme.ink : surface.glassActive ? Theme.brandLight1 : Theme.onBrand
        size: Theme.iconSize
    }
}

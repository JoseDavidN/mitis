import QtQuick
import Mitis.Core

// Fondo de un control o una tarjeta de Mitis: relleno del tema (un color,
// `fill`, o un degradado horizontal, `fillStart` → `fillEnd`) y radio, sin
// borde (solo el anillo de foco de los campos lo pide: border.width). Con la transparencia experimental activa, en lugar
// del relleno se ve el vidrio esmerilado (Glass): todo el vidrio de la
// interfaz pasa por aquí.
//
// Uso:
//     Surface { radius: Theme.radius; fill: Colors.surfaceFloat }
//     Surface { fillStart: Colors.controlsStart; fillEnd: Colors.controlsEnd }
Rectangle {
    id: root

    property color fill: "transparent"
    property color fillStart: fill
    property color fillEnd: fillStart
    // Velo del vidrio (el mini reproductor, de texto blanco, usa siempre el oscuro)
    property alias glassTint: glass.tint
    // Se está viendo el vidrio en lugar del relleno
    readonly property bool glassActive: glass.active

    border.width: 0
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: glass.active ? "transparent" : root.fillStart }
        GradientStop { position: 1.0; color: glass.active ? "transparent" : root.fillEnd }
    }

    Glass {
        id: glass
        z: -1
        anchors.fill: parent
        radius: root.radius
    }
}

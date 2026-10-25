pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Como Surface, para un fondo con forma propia (no un rectángulo): la forma es
// un trazado SVG (`path`, en el tamaño del elemento), rellena con el color o
// el degradado horizontal del tema, sin borde. Con la transparencia
// experimental, el vidrio (Glass) recortado con la forma. Lo usan ControlsTab y SwipeIndicator.
Item {
    id: root

    property string path: ""
    property color fill: "transparent"
    property color fillStart: fill
    property color fillEnd: fillStart

    // Relleno (transparente mientras se ve el vidrio)
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: root.width; y2: 0
                GradientStop { position: 0.0; color: glass.active ? "transparent" : root.fillStart }
                GradientStop { position: 1.0; color: glass.active ? "transparent" : root.fillEnd }
            }
            PathSvg { path: root.path }
        }
    }

    Glass {
        id: glass
        z: -1
        anchors.fill: parent
        shape: mask
    }

    // La forma en opaco, solo como máscara del vidrio
    Shape {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: glass.active
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: "white"
            PathSvg { path: root.path }
        }
    }
}

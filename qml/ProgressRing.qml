import QtQuick
import QtQuick.Shapes
import Mitis.Core

// Anillo de progreso: arco fino sobre una pista tenue, desde arriba y en el
// sentido de las agujas del reloj. Sin total conocido (`indeterminate`), un
// arco corto gira sin parar. Se dibuja dentro de su tamaño (cuadrado).
Item {
    id: root

    // 0..1
    property real value: 0
    property bool indeterminate: false
    property color color: Colors.brandLight1
    property color trackColor: Colors.tintActive
    property int thickness: Theme.progressRingWidth

    implicitWidth: Theme.buttonSize
    implicitHeight: Theme.buttonSize

    // Radio del trazo: el borde exterior coincide con el del elemento
    readonly property real arcRadius: (Math.min(width, height) - thickness) / 2
    readonly property real sweep: 360 * (indeterminate ? Theme.progressIndeterminateSpan
                                                       : Math.max(0, Math.min(1, value)))

    Shape {
        id: shape
        anchors.fill: parent

        // Bordes suaves sin multimuestreo (Qt 6.6+; con 6.5 se queda el normal)
        Component.onCompleted: {
            if (shape.preferredRendererType !== undefined)
                shape.preferredRendererType = Shape.CurveRenderer
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            PathAngleArc {
                centerX: shape.width / 2
                centerY: shape.height / 2
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.sweep > 0 ? root.color : "transparent"
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: shape.width / 2
                centerY: shape.height / 2
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: -90
                sweepAngle: root.sweep

                Behavior on sweepAngle {
                    enabled: !root.indeterminate
                    NumberAnimation { duration: Theme.durationBase }
                }
            }
        }

        // Giro en el hilo de render: no recalcula la forma
        RotationAnimator on rotation {
            running: root.indeterminate && root.visible
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: Theme.durationSpin
            onRunningChanged: if (!running) shape.rotation = 0
        }
    }
}

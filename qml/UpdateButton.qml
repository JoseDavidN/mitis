import QtQuick
import Mitis.Core

// Botón de la barra inferior cuando hay una versión nueva de Mitis: el icono
// de actualizar dentro de un anillo con el degradado de la marca, y cada
// tanto un pulso (el anillo crece y se desvanece) para que se note. Al
// pulsarlo, la ventana de confirmación (UpdatePopup).
Item {
    id: root

    property alias fillStart: button.fillStart
    property alias fillEnd: button.fillEnd
    readonly property alias hovered: button.hovered
    // El del icono de un botón normal (el anillo le quita su ancho)
    property int iconSize: Theme.iconSize

    signal clicked()

    implicitWidth: Theme.buttonSize
    implicitHeight: Theme.buttonSize

    // Pulso: detrás del botón, sin recortar (sale del hueco)
    Rectangle {
        id: pulse
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: Theme.updateRingWidth
        border.color: Colors.brandLight1
        opacity: 0

        SequentialAnimation {
            running: root.visible
            loops: Animation.Infinite
            ParallelAnimation {
                NumberAnimation {
                    target: pulse; property: "scale"
                    from: 1; to: Theme.updatePulseScale
                    duration: Theme.updatePulseDuration; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: pulse; property: "opacity"
                    from: 0.9; to: 0
                    duration: Theme.updatePulseDuration; easing.type: Easing.OutCubic
                }
            }
            PauseAnimation { duration: Theme.updatePulsePause }
        }
    }

    // Anillo: el degradado de la marca asoma alrededor del botón
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        scale: button.pressed ? Theme.pressScale : (button.hovered ? Theme.hoverScale : 1.0)
        Behavior on scale {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeInOut
            }
        }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Colors.brand1 }
            GradientStop { position: 1.0; color: Colors.brand2 }
        }
    }

    IconButton {
        id: button
        anchors.fill: parent
        anchors.margins: Theme.updateRingWidth
        icon: "update"
        iconSize: root.iconSize - Theme.updateRingWidth
        highlighted: true
        tooltip: "Actualizar Mitis"
        onClicked: root.clicked()
    }
}

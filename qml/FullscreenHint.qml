import QtQuick

// Aviso al entrar en pantalla completa («Pulsa Esc para salir…»): píldora
// con el estilo de los controles, centrada arriba. Se queda
// `Theme.fullscreenHintHold` y se desvanece. No recibe clics.
Item {
    id: root

    property bool shown: false
    property string text: ""

    // Muestra `message` y reinicia la cuenta atrás
    function show(message) {
        text = message
        shown = true
        hold.restart()
    }

    function hide() {
        hold.stop()
        shown = false
    }

    implicitWidth: label.implicitWidth + 2 * Theme.margin
    implicitHeight: Theme.controlHeight

    visible: opacity > 0
    opacity: shown ? 1 : 0
    transform: Translate {
        y: root.shown ? 0 : -Theme.spacing
        Behavior on y {
            NumberAnimation { duration: Theme.durationBase; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        }
    }
    Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

    Timer {
        id: hold
        interval: Theme.fullscreenHintHold
        onTriggered: root.shown = false
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        border.width: 1
        border.color: Theme.hairline
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: glass.active ? "transparent" : Theme.controlsStart }
            GradientStop { position: 1.0; color: glass.active ? "transparent" : Theme.controlsEnd }
        }
        Glass {
            id: glass
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Theme.ink
        font.pixelSize: Theme.fontSize
    }
}

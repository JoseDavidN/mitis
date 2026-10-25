import QtQuick
import Mitis.Core

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

    Surface {
        anchors.fill: parent
        radius: height / 2
        fillStart: Colors.controlsStart
        fillEnd: Colors.controlsEnd
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Colors.ink
        font.pixelSize: Theme.fontSize
    }
}

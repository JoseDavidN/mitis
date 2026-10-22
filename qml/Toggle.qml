import QtQuick

// Interruptor de encendido/apagado. Encendido: pista con el degradado de
// marca y bola onBrand; apagado: pista tintActive con borde y bola inkSoft.
Item {
    id: root

    property bool checked: false

    // El usuario lo cambió (checked ya tiene el valor nuevo)
    signal toggled()

    implicitWidth: Theme.toggleWidth
    implicitHeight: Theme.toggleHeight
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true

    function toggle() {
        root.checked = !root.checked
        root.toggled()
    }

    Keys.onSpacePressed: root.toggle()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: hover.hovered ? Theme.tintActive : Theme.tintHover
        border.width: 1
        border.color: root.activeFocus ? Theme.focusRing : (hover.hovered ? Theme.hairlineHover : Theme.hairline)
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    // Encendido: el degradado aparece encima con un fundido
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        opacity: root.checked ? 1 : 0
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.focusRing
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.brand1 }
            GradientStop { position: 1.0; color: Theme.brand2 }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
    }

    Rectangle {
        readonly property int size: root.height - 2 * Theme.toggleKnobInset
        width: size
        height: size
        radius: size / 2
        y: Theme.toggleKnobInset
        x: root.checked ? root.width - size - Theme.toggleKnobInset : Theme.toggleKnobInset
        color: root.checked ? Theme.onBrand : Theme.inkSoft
        Behavior on x {
            NumberAnimation { duration: Theme.durationBase; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeInOut }
        }
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.toggle()
    }
}

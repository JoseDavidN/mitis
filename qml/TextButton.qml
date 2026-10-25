import QtQuick
import Mitis.Core

// Botón con texto, en píldora. `primary` es la acción principal de un
// diálogo: degradado de marca y texto onBrand. `danger` (sin primary) es una
// acción arriesgada y secundaria: texto en danger. Sin borde.
Item {
    id: root

    property string text: ""
    property bool primary: false
    property bool danger: false

    signal clicked()

    implicitWidth: label.implicitWidth + 2 * Theme.margin + Theme.spacing
    implicitHeight: Theme.textButtonHeight
    opacity: enabled ? 1 : 0.45

    readonly property bool hovered: hover.hovered

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        visible: !root.primary
        color: root.hovered ? Colors.tintActive : Colors.tintHover
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        visible: root.primary
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Colors.brand1 }
            GradientStop { position: 1.0; color: Colors.brand2 }
        }

        // Realce al pasar por encima
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.hovered ? Colors.tintActive : "transparent"
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.primary ? Colors.onBrand : root.danger ? Colors.danger : Colors.ink
        font.pixelSize: Theme.fontSize
        font.weight: root.primary ? Font.DemiBold : Font.Normal
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        // Agarre exclusivo: si no, lo que hay debajo recibe también el clic
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }
}

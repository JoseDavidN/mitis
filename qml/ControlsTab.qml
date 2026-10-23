import QtQuick

// Pestaña del borde inferior cuando los controles están ocultos: una
// protuberancia pequeña, centrada, con el título de la página. Al pasar el
// ratón por encima, los controles vuelven (`hovered`, lo atiende Main).
Item {
    id: root

    property string title: ""
    readonly property bool hovered: hover.hovered

    implicitWidth: Math.min(Theme.controlsTabMaxWidth, label.implicitWidth + 2 * Theme.margin)
    implicitHeight: Theme.controlsTabHeight

    // Redondeada solo arriba: un rectángulo redondeado que se sale por abajo
    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            width: parent.width
            height: parent.height + radius
            radius: Theme.radiusSmall
            border.width: 1
            border.color: root.hovered ? Theme.hairlineHover : Theme.hairline
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
    }

    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - 2 * Theme.margin)
        text: root.title !== "" ? root.title : "Mitis"
        color: root.hovered ? Theme.ink : Theme.inkSecondary
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
}

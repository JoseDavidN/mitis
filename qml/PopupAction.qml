import QtQuick

// Fila de acción de una lista desplegable: icono, texto y atajo opcional.
// Uso: PopupAction { icon: "new-tab"; text: "Nueva pestaña"; shortcut: "Ctrl+T" }
Item {
    id: root

    property string icon: ""
    property string text: ""
    property string shortcut: ""

    signal triggered()

    implicitWidth: Theme.popupWidth
    implicitHeight: Theme.popupRowHeight
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: hover.hovered ? Theme.tintHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    Icon {
        id: actionIcon
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        color: Theme.inkSoft
    }

    Text {
        anchors.left: actionIcon.right
        anchors.leftMargin: Theme.spacing
        anchors.right: shortcutText.left
        anchors.rightMargin: Theme.spacing
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Theme.ink
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
    }

    Text {
        id: shortcutText
        anchors.right: parent.right
        anchors.rightMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        text: root.shortcut
        color: Theme.inkMuted
        font.pixelSize: Theme.fontSizeSmall
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        // Agarre exclusivo: si no, lo que hay debajo recibe también el clic
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.triggered()
    }
}

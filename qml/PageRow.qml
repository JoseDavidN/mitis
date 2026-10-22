import QtQuick

import "urls.js" as Urls

// Fila de una página guardada (marcadores, historial): favicon, título y una
// línea de detalle; al pasar por encima, una ✕ para quitarla.
Item {
    id: root

    property string url: ""
    property string title: ""
    // Segunda línea; vacía = la dirección sin esquema
    property string detail: ""
    property string removeTooltip: "Quitar"

    signal clicked()
    signal removeRequested()

    implicitWidth: Theme.popupWidth
    implicitHeight: Theme.pageRowHeight

    readonly property bool hovered: hover.hovered

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.hovered ? Theme.tintHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    // Favicon sobre un círculo claro (muchos son negros); sin él, la inicial
    Rectangle {
        id: faviconBox
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.buttonSizeSmall
        height: Theme.buttonSizeSmall
        radius: width / 2
        color: favicon.visible ? Theme.faviconBackdrop : Theme.tintActive

        Image {
            id: favicon
            anchors.centerIn: parent
            width: Theme.faviconSize
            height: Theme.faviconSize
            sourceSize: Qt.size(2 * Theme.faviconSize, 2 * Theme.faviconSize)
            source: Urls.favicon(root.url)
            asynchronous: true
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
        }
        Text {
            visible: !favicon.visible
            anchors.centerIn: parent
            text: (Urls.host(root.url) || "?").charAt(0).toUpperCase()
            color: Theme.brandLight1
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
        }
    }

    Column {
        anchors.left: faviconBox.right
        anchors.leftMargin: Theme.spacing + Theme.spacing / 2
        anchors.right: removeButton.left
        anchors.rightMargin: Theme.spacing / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing / 4

        Text {
            width: parent.width
            text: root.title || Urls.host(root.url) || root.url
            color: Theme.ink
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.detail || root.url.replace(/^https?:\/\/(www\.)?/, "")
            color: Theme.inkMuted
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }
    }

    IconButton {
        id: removeButton
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.buttonSizeSmall
        height: Theme.buttonSizeSmall
        icon: "close"
        iconSize: Theme.iconSizeSmall
        tooltip: root.removeTooltip
        flat: true
        opacity: root.hovered ? 1 : 0
        onClicked: root.removeRequested()
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

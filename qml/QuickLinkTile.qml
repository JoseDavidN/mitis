import QtQuick

import "urls.js" as Urls
import Mitis.Core

// Acceso rápido de la página de nueva pestaña: icono del sitio (o su
// inicial, si no hay icono) en un cuadro redondeado y su nombre debajo.
// Con `adder`, es el botón "+".
Item {
    id: root

    property string name: ""
    property string url: ""
    property bool adder: false
    // Se puede quitar (no en las ventanas privadas)
    property bool editable: true

    readonly property string faviconUrl: Urls.favicon(url)

    signal opened()
    signal removeRequested()

    implicitWidth: Theme.tileWidth
    implicitHeight: Theme.tileSize + Theme.spacing + caption.implicitHeight

    readonly property bool hovered: hover.hovered

    Surface {
        id: tile
        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.tileSize
        height: Theme.tileSize
        radius: Theme.radius
        fill: Colors.surfaceFloat
        scale: tap.pressed ? Theme.pressScale : (root.hovered ? Theme.hoverScale : 1)

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeInOut
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.hovered ? Colors.tintHover : "transparent"
        }

        Rectangle {
            visible: favicon.visible
            anchors.centerIn: parent
            width: Theme.tileIconBackdrop
            height: Theme.tileIconBackdrop
            radius: width / 2
            color: Colors.faviconBackdrop
        }

        Image {
            id: favicon
            anchors.centerIn: parent
            width: Theme.tileIconSize
            height: Theme.tileIconSize
            sourceSize: Qt.size(2 * Theme.tileIconSize, 2 * Theme.tileIconSize)
            source: root.adder ? "" : root.faviconUrl
            asynchronous: true
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
        }

        // Sin icono (sin conexión, o el sitio no tiene): la inicial
        Text {
            visible: !root.adder && !favicon.visible
            anchors.centerIn: parent
            text: root.name.charAt(0).toUpperCase()
            color: Colors.brandLight1
            font.pixelSize: Theme.fontSizeLarge + 6
            font.weight: Font.DemiBold
        }

        Icon {
            visible: root.adder
            anchors.centerIn: parent
            name: "new-tab"
            color: Colors.inkSoft
        }
    }

    Text {
        id: caption
        anchors.top: tile.bottom
        anchors.topMargin: Theme.spacing
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.adder ? "Añadir" : root.name
        color: Colors.inkSecondary
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: tap
        onTapped: root.opened()
    }

    // Quitar: aparece en la esquina al pasar por encima
    IconButton {
        visible: !root.adder && root.editable && root.hovered
        anchors.right: tile.right
        anchors.top: tile.top
        anchors.margins: -Theme.spacing / 2
        width: Theme.buttonSizeSmall - 4
        height: Theme.buttonSizeSmall - 4
        icon: "close"
        iconSize: Theme.iconSizeSmall - 2
        danger: true
        tooltip: "Quitar"
        onClicked: root.removeRequested()
    }
}

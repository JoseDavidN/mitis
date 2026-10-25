import QtQuick
import Mitis.Core

// Noticia de la página de nueva pestaña: titular (hasta dos líneas) y,
// debajo, la fuente y su antigüedad.
Item {
    id: root

    property string title: ""
    property string source: ""
    property string age: ""

    signal opened()

    implicitHeight: content.implicitHeight + 2 * Theme.margin

    Surface {
        anchors.fill: parent
        radius: Theme.radius
        fill: Colors.surfaceFloat

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: hover.hovered ? Colors.tintHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.margin
        spacing: Theme.spacing / 2

        Text {
            width: parent.width
            text: root.title
            color: Colors.ink
            font.pixelSize: Theme.fontSize
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.source !== "" ? root.source + " · " + root.age : root.age
            color: Colors.inkMuted
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: root.opened()
    }
}

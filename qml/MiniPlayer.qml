import QtQuick

// Mini reproductor: flota sobre la barra de búsqueda mientras una pestaña
// reproduce algo. Tamaño fijo; el título se acorta con "…" si no cabe.
// A la izquierda, el favicon de la plataforma (YouTube, Spotify...).
// Clic en el título: ir a la pestaña que suena.
Item {
    id: root

    property string title: ""
    // Favicon de la pestaña que suena; sin él, una nota musical
    property url iconSource
    property bool playing: false
    property bool hasNext: false
    property bool hasPrevious: false

    signal toggleRequested()
    signal nextRequested()
    signal previousRequested()
    signal activated()

    implicitWidth: Theme.miniPlayerWidth
    implicitHeight: Theme.miniPlayerHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        border.width: 1
        border.color: Theme.hairline
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.controlsStart }
            GradientStop { position: 1.0; color: Theme.controlsEnd }
        }
    }

    // Plataforma (favicon) y nombre de lo que suena
    Item {
        id: label
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin - 2
        anchors.right: buttons.left
        anchors.rightMargin: Theme.spacing
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        Item {
            id: platform
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconSizeSmall
            height: Theme.iconSizeSmall

            Image {
                id: favicon
                anchors.fill: parent
                sourceSize: Qt.size(2 * Theme.iconSizeSmall, 2 * Theme.iconSizeSmall)
                source: root.iconSource
                smooth: true
                mipmap: true
                // En pausa, atenuado
                opacity: root.playing ? 1 : 0.6
                visible: status === Image.Ready
            }

            Icon {
                anchors.fill: parent
                visible: !favicon.visible
                name: "music"
                size: Theme.iconSizeSmall
                color: root.playing ? Theme.brandLight1 : Theme.inkMuted
            }
        }

        Text {
            anchors.left: platform.right
            anchors.leftMargin: Theme.spacing
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: labelHover.hovered ? Theme.ink : Theme.inkStrong
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }

        HoverHandler {
            id: labelHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: root.activated()
        }
    }

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing / 2
        anchors.verticalCenter: parent.verticalCenter

        IconButton {
            width: Theme.buttonSizeSmall
            height: Theme.buttonSizeSmall
            flat: true
            icon: "previous"
            iconSize: Theme.iconSizeSmall
            enabled: root.hasPrevious
            tooltip: "Anterior"
            onClicked: root.previousRequested()
        }
        IconButton {
            width: Theme.buttonSizeSmall
            height: Theme.buttonSizeSmall
            flat: true
            icon: root.playing ? "pause" : "play"
            iconSize: Theme.iconSizeSmall
            tooltip: root.playing ? "Pausar" : "Reproducir"
            onClicked: root.toggleRequested()
        }
        IconButton {
            width: Theme.buttonSizeSmall
            height: Theme.buttonSizeSmall
            flat: true
            icon: "next"
            iconSize: Theme.iconSizeSmall
            enabled: root.hasNext
            tooltip: "Siguiente"
            onClicked: root.nextRequested()
        }
    }
}

import QtQuick

// Mini reproductor: flota sobre la barra de búsqueda mientras otra pestaña
// reproduce algo. Negro en todos los temas; los botones son solo el icono
// (relleno, blanco), que al pasar el ratón toma el degradado de la marca y
// crece un poco. Tamaño fijo; el título se acorta con "…" si no cabe.
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
        color: glass.active ? "transparent" : Theme.miniPlayerBg
        border.width: 1
        border.color: Theme.miniPlayerLine

        // Vidrio esmerilado (experimental): con velo oscuro siempre, por el
        // texto blanco
        Glass {
            id: glass
            z: -1
            anchors.fill: parent
            radius: parent.radius
            tint: Theme.glassTintDark
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
                color: root.playing ? Theme.miniPlayerInk : Theme.miniPlayerInkSoft
            }
        }

        Text {
            anchors.left: platform.right
            anchors.leftMargin: Theme.spacing
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: labelHover.hovered ? Theme.miniPlayerInk : Theme.miniPlayerInkSoft
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
        anchors.rightMargin: (parent.height - Theme.miniPlayerButtonSize) / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing / 2

        MediaButton {
            icon: "media-previous"
            available: root.hasPrevious
            tooltip: "Anterior"
            onClicked: root.previousRequested()
        }
        MediaButton {
            icon: root.playing ? "media-pause" : "media-play"
            tooltip: root.playing ? "Pausar" : "Reproducir"
            onClicked: root.toggleRequested()
        }
        MediaButton {
            icon: "media-next"
            available: root.hasNext
            tooltip: "Siguiente"
            onClicked: root.nextRequested()
        }
    }

    // Botón sin fondo ni borde: solo el icono. Al pasar el ratón, el icono
    // pasa del blanco al degradado de la marca (fundido) y crece suavemente
    component MediaButton: Item {
        id: button

        property string icon: ""
        property string tooltip: ""
        property bool available: true
        readonly property bool hovered: buttonHover.hovered && available

        signal clicked()

        width: Theme.miniPlayerButtonSize
        height: Theme.miniPlayerButtonSize
        opacity: available ? 1 : 0.35

        Item {
            anchors.centerIn: parent
            width: Theme.miniPlayerIconSize
            height: Theme.miniPlayerIconSize
            scale: buttonTap.pressed && button.available ? Theme.pressScale
                 : (button.hovered ? Theme.miniPlayerHoverScale : 1)
            Behavior on scale { NumberAnimation { duration: Theme.durationBase; easing.type: Easing.OutCubic } }

            Icon {
                anchors.fill: parent
                name: button.icon
                size: Theme.miniPlayerIconSize
                color: Theme.miniPlayerInk
            }
            Icon {
                anchors.fill: parent
                name: button.icon
                size: Theme.miniPlayerIconSize
                color: Theme.miniPlayerHoverStart
                colorEnd: Theme.miniPlayerHoverEnd
                opacity: button.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
            }
        }

        HoverHandler {
            id: buttonHover
            cursorShape: button.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
        TapHandler {
            id: buttonTap
            enabled: button.available
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: button.clicked()
        }
        Tooltip {
            text: button.tooltip
            visible: buttonHover.hovered && button.tooltip !== ""
        }
    }
}

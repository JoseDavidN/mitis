pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

// Reproductor desplegado desde la pestaña del reproductor (MediaTab): la
// carátula de lo que suena (o el icono de la plataforma sobre el degradado de
// la marca), título y artista, barra de progreso (se puede pulsar o arrastrar
// para ir a otro punto) y los botones anterior, reproducir/pausa y siguiente.
// Los datos los da Main (media.js de la página que suena, cada segundo); entre
// medias, la posición avanza sola mientras suena.
Popup {
    id: root

    // Estado de media.js: { title, artist, artwork, playing, position, duration, hasNext, hasPrevious }
    property var media: null
    // Favicon de la pestaña que suena
    property url iconSource
    // Nombre del sitio, si la página no da artista
    property string site: ""

    signal controlRequested(string action)
    signal seekRequested(real seconds)
    // Ir a la pestaña que suena
    signal activated()

    readonly property bool playing: media ? media.playing : false
    readonly property real duration: media ? media.duration : 0
    // Posición mostrada: la última que dio la página más lo que lleva sonando
    // desde entonces (o la que se está arrastrando)
    property real position: 0
    property real _base: 0
    property real _baseTime: 0
    onMediaChanged: {
        if (!media || seek.pressed)
            return
        _base = media.position
        _baseTime = Date.now()
        position = _base
    }
    Timer {
        interval: 250
        repeat: true
        running: root.opened && root.playing && !seek.pressed
        onTriggered: root.position = Math.min(root.duration, root._base + (Date.now() - root._baseTime) / 1000)
    }

    // 1:05, 12:30 o 1:02:03
    function clock(seconds) {
        const total = Math.max(0, Math.floor(seconds))
        const h = Math.floor(total / 3600), m = Math.floor(total % 3600 / 60), s = total % 60
        const ss = (s < 10 ? "0" : "") + s
        return h > 0 ? h + ":" + (m < 10 ? "0" : "") + m + ":" + ss : m + ":" + ss
    }

    width: Theme.mediaPlayerWidth
    padding: Theme.margin
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: PopupBackground {}

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationFast }
    }

    contentItem: Column {
        spacing: Theme.margin

        // Carátula: 16:9, con las esquinas redondeadas
        Item {
            id: cover
            width: parent.width
            height: Math.round(width * Theme.mediaArtworkRatio)

            // Sin carátula: el icono de la plataforma sobre el degradado de la marca
            Rectangle {
                anchors.fill: parent
                visible: artwork.status !== Image.Ready
                radius: Theme.radiusSmall
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Colors.brand1 }
                    GradientStop { position: 1.0; color: Colors.brand2 }
                }

                Image {
                    id: bigIcon
                    anchors.centerIn: parent
                    width: Theme.mediaPlaceholderIconSize
                    height: width
                    sourceSize: Qt.size(2 * width, 2 * width)
                    source: root.iconSource
                    smooth: true
                    mipmap: true
                    visible: status === Image.Ready
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !bigIcon.visible
                    name: "music"
                    size: Theme.mediaPlaceholderIconSize
                    color: Colors.onBrand
                }
            }

            // Solo para saber si carga y su tamaño; la dibuja el Canvas
            Image {
                id: artwork
                readonly property string address: root.media ? root.media.artwork : ""
                visible: false
                source: address
                asynchronous: true
                // La imagen ya está en memoria (la cargó este Image): el Canvas
                // puede tenerla al momento y no avisar con imageLoaded
                onStatusChanged: {
                    if (status !== Image.Ready)
                        return
                    coverCanvas.loadImage(address)
                    coverCanvas.requestPaint()
                }
            }
            // La carátula recortada para llenar el hueco (sin deformar) con
            // las esquinas redondeadas. En un Canvas, como el avatar:
            // funciona también sin GPU
            Canvas {
                id: coverCanvas
                anchors.fill: parent
                visible: artwork.status === Image.Ready
                onImageLoaded: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const source = artwork.address
                    if (!isImageLoaded(source))
                        return
                    const r = Theme.radiusSmall
                    ctx.beginPath()
                    ctx.roundedRect(0, 0, width, height, r, r)
                    ctx.clip()
                    const w = artwork.implicitWidth, h = artwork.implicitHeight
                    const scale = Math.max(width / w, height / h)
                    const sw = width / scale, sh = height / scale
                    ctx.drawImage(source, (w - sw) / 2, (h - sh) / 2, sw, sh, 0, 0, width, height)
                }
                Connections {
                    target: artwork
                    function onAddressChanged() {
                        coverCanvas.requestPaint()
                    }
                }
            }
        }

        // Título (clic: ir a la pestaña) y artista o sitio
        Column {
            width: parent.width
            spacing: Theme.spacing / 4

            Text {
                width: parent.width
                text: root.media && root.media.title !== "" ? root.media.title : "Reproduciendo"
                color: Colors.ink
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Font.DemiBold
                font.underline: titleHover.hovered
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight

                HoverHandler {
                    id: titleHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: {
                        root.close()
                        root.activated()
                    }
                }
                Tooltip {
                    text: "Ir a la pestaña"
                    visible: titleHover.hovered
                }
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: root.media && root.media.artist ? root.media.artist : root.site
                color: Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        // Barra de progreso: pulsar o arrastrar va a ese punto. En un directo
        // (sin duración), solo «En directo»
        Column {
            width: parent.width
            spacing: Theme.spacing / 2

            Item {
                id: seek
                readonly property bool pressed: seekDrag.active || seekTap.pressed
                readonly property real value: root.duration > 0 ? Math.max(0, Math.min(1, root.position / root.duration)) : 0

                width: parent.width
                height: Theme.mediaSeekHitHeight
                visible: root.duration > 0

                function positionAt(x) {
                    return Math.max(0, Math.min(1, x / width)) * root.duration
                }

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Theme.mediaSeekHeight
                    radius: height / 2
                    color: Colors.tintActive

                    Rectangle {
                        width: Math.max(height, parent.width * seek.value)
                        height: parent.height
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Colors.brand1 }
                            GradientStop { position: 1.0; color: Colors.brand2 }
                        }
                    }
                }
                // Asa: aparece al pasar el ratón o al arrastrar
                Rectangle {
                    width: Theme.mediaSeekKnobSize
                    height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: seek.width * seek.value - width / 2
                    color: Colors.ink
                    opacity: seekHover.hovered || seek.pressed ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                }

                HoverHandler {
                    id: seekHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    id: seekTap
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: eventPoint => {
                        root.position = seek.positionAt(eventPoint.position.x)
                        root.seekRequested(root.position)
                    }
                }
                DragHandler {
                    id: seekDrag
                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onCentroidChanged: if (active) root.position = seek.positionAt(centroid.position.x)
                    onActiveChanged: {
                        if (active)
                            return
                        root._base = root.position
                        root._baseTime = Date.now()
                        root.seekRequested(root.position)
                    }
                }
            }

            Item {
                width: parent.width
                height: elapsed.implicitHeight

                Text {
                    id: elapsed
                    text: root.duration > 0 ? root.clock(root.position) : "En directo"
                    color: root.duration > 0 ? Colors.inkMuted : Colors.danger
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: root.duration > 0 ? Font.Normal : Font.DemiBold
                }
                Text {
                    anchors.right: parent.right
                    visible: root.duration > 0
                    text: root.clock(root.duration)
                    color: Colors.inkMuted
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // Anterior, reproducir/pausa (el principal, con el degradado de la
        // marca) y siguiente
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.margin

            MediaButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "media-previous"
                tooltip: "Anterior"
                available: root.media ? root.media.hasPrevious : false
                onClicked: root.controlRequested("previous")
            }
            MediaButton {
                anchors.verticalCenter: parent.verticalCenter
                main: true
                icon: root.playing ? "media-pause" : "media-play"
                tooltip: root.playing ? "Pausar" : "Reproducir"
                onClicked: root.controlRequested("toggle")
            }
            MediaButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "media-next"
                tooltip: "Siguiente"
                available: root.media ? root.media.hasNext : false
                onClicked: root.controlRequested("next")
            }
        }
    }

    // Botón redondo: el principal, con el degradado de la marca; los demás,
    // solo el icono, con fondo al pasar el ratón
    component MediaButton: Item {
        id: button

        property string icon: ""
        property string tooltip: ""
        property bool main: false
        property bool available: true
        readonly property bool hovered: buttonHover.hovered && available

        signal clicked()

        width: main ? Theme.mediaPlayButtonSize : Theme.mediaButtonSize
        height: width
        opacity: available ? 1 : 0.35
        scale: buttonTap.pressed && available ? Theme.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Theme.durationFast } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: button.main
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Colors.brand1 }
                GradientStop { position: 1.0; color: Colors.brand2 }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: button.main ? Colors.onBrand : Colors.tintHover
            opacity: button.hovered ? (button.main ? 0.12 : 1) : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }
        Icon {
            anchors.centerIn: parent
            name: button.icon
            size: button.main ? Theme.mediaPlayIconSize : Theme.mediaIconSize
            color: button.main ? Colors.onBrand : (button.hovered ? Colors.ink : Colors.inkSecondary)
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

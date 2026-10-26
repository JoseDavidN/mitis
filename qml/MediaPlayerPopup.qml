pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

// Reproductor desplegado desde la pestaña del reproductor (MediaTab), compacto
// y ligero: arriba, una miniatura de lo que suena (la carátula, pequeña, o el
// icono de la plataforma sobre el degradado de la marca) con el título y el
// artista; abajo, el tiempo («1:23 / 3:34») y los botones anterior,
// reproducir/pausa y siguiente. Sin barra de progreso. El tiempo cambia una
// vez por segundo, solo abierto y sonando: entre las lecturas de la página
// (Main, cada segundo) lo avanza él. Solo existe abierto (LazyPopup).
Popup {
    id: root

    // Estado de media.js: { title, artist, artwork, playing, position, duration, hasNext, hasPrevious }
    property var media: null
    // Favicon de la pestaña que suena
    property url iconSource
    // Nombre del sitio, si la página no da artista
    property string site: ""

    signal controlRequested(string action)
    // Ir a la pestaña que suena
    signal activated()

    readonly property bool playing: media ? media.playing : false
    readonly property real duration: media && media.duration > 0 ? media.duration : 0

    // Segundos mostrados: los de la última lectura más lo que lleva sonando
    property int seconds: 0
    property real _base: 0
    property real _baseTime: 0
    onMediaChanged: {
        if (!media)
            return
        _base = media.position || 0
        _baseTime = Date.now()
        seconds = Math.floor(_base)
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.opened && root.playing && root.duration > 0
        onTriggered: root.seconds = Math.floor(Math.min(root.duration, root._base + (Date.now() - root._baseTime) / 1000))
    }
    // 1:05 o 1:02:03
    function clock(value) {
        const total = Math.max(0, Math.floor(value))
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

        // Miniatura y lo que suena (clic en el título: ir a la pestaña)
        Item {
            width: parent.width
            height: Theme.mediaThumbSize

            Item {
                id: thumb
                width: Theme.mediaThumbSize
                height: Theme.mediaThumbSize

                // Sin carátula: el icono de la plataforma sobre la marca
                Rectangle {
                    anchors.fill: parent
                    visible: !coverCanvas.visible
                    radius: Theme.radiusSmall
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Colors.brand1 }
                        GradientStop { position: 1.0; color: Colors.brand2 }
                    }

                    Image {
                        id: bigIcon
                        anchors.centerIn: parent
                        width: Theme.iconSize + 4
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
                        size: Theme.iconSize + 4
                        color: Colors.onBrand
                    }
                }

                // Solo para saber si carga y su tamaño (decodificada pequeña);
                // la dibuja el Canvas
                Image {
                    id: artwork
                    readonly property string address: root.media ? root.media.artwork : ""
                    visible: false
                    source: address
                    sourceSize: Qt.size(2 * Theme.mediaThumbSize, 2 * Theme.mediaThumbSize)
                    asynchronous: true
                    // La imagen ya está en memoria (la cargó este Image): el
                    // Canvas puede tenerla al momento y no avisar con imageLoaded
                    onStatusChanged: {
                        if (status !== Image.Ready)
                            return
                        coverCanvas.loadImage(address)
                        coverCanvas.requestPaint()
                    }
                }
                // Recortada para llenar el cuadrado (sin deformar), con las
                // esquinas redondeadas. En un Canvas, como el avatar: también
                // sin GPU
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
                        // El lienzo carga la imagen original: se escala entera
                        // para cubrir el cuadrado (con la proporción de la
                        // pequeña, que es la misma) y el recorte quita lo que sobra
                        const ratio = artwork.implicitWidth / Math.max(1, artwork.implicitHeight)
                        const dw = ratio >= 1 ? height * ratio : width
                        const dh = ratio >= 1 ? height : width / ratio
                        ctx.drawImage(source, (width - dw) / 2, (height - dh) / 2, dw, dh)
                    }
                    Connections {
                        target: artwork
                        function onAddressChanged() {
                            coverCanvas.requestPaint()
                        }
                    }
                }
            }

            Column {
                anchors.left: thumb.right
                anchors.leftMargin: Theme.margin
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing / 4

                Text {
                    width: parent.width
                    text: root.media && root.media.title !== "" ? root.media.title : "Reproduciendo"
                    color: Colors.ink
                    font.pixelSize: Theme.fontSize
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
        }

        // El tiempo a la izquierda (en un directo, «En directo») y, a la
        // derecha, anterior, reproducir/pausa (con el degradado de la marca) y
        // siguiente
        Item {
            width: parent.width
            height: Theme.mediaPlayButtonSize

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.duration > 0 ? root.clock(root.seconds) + " / " + root.clock(root.duration)
                                        : (root.media ? "En directo" : "")
                color: root.duration > 0 ? Colors.inkMuted : Colors.danger
                font.pixelSize: Theme.fontSizeSmall
                font.weight: root.duration > 0 ? Font.Normal : Font.DemiBold
                // Las cifras con el mismo ancho: el texto no baila al avanzar
                font.features: { "tnum": 1 }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing / 2

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

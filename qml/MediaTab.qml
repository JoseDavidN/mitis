import QtQuick
import Mitis.Core

// Pestaña del reproductor: mientras alguna pestaña reproduce algo, una cúpula
// pequeña, alargada en vertical, que sale del borde derecho (Main la pone
// encima del sitio del gesto de adelante), con el estilo de ese gesto
// (SwipeIndicator) y solo el icono de la plataforma (YouTube, Spotify…),
// atenuado en pausa. Al aparecer sale del
// borde con un pequeño rebote; al pasar el ratón sale un poco más. Al pulsarla
// se despliega el reproductor (MediaPlayerPopup, lo abre Main). Solo anima al
// cambiar: el resto del tiempo no redibuja nada.
Item {
    id: root

    property bool shown: false
    // Favicon de la pestaña que suena; sin él, una nota musical
    property url iconSource
    property bool playing: false
    // El reproductor está desplegado: sale como al pasar el ratón
    property bool expanded: false
    readonly property bool hovered: hover.hovered

    signal clicked()

    // Cuánto ha salido del borde
    property real depth: !shown ? 0 : (hovered || expanded ? Theme.mediaTabHoverDepth : Theme.mediaTabDepth)
    Behavior on depth {
        NumberAnimation {
            duration: Theme.durationSlow
            // Sale con un rebote suave; al irse, de una vez
            easing.type: root.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: Theme.mediaTabOvershoot
        }
    }

    width: Theme.mediaTabHoverDepth
    height: Theme.mediaTabLength
    visible: depth > 0.5

    // Una cúpula: sale del borde en vertical, donde se funde con él, y llega
    // a su cima en el centro (la de SwipeIndicator, más corta)
    SurfaceShape {
        width: Math.max(0, root.depth)
        height: parent.height
        x: parent.width - width
        fillStart: Colors.controlsStart
        fillEnd: Colors.controlsEnd
        path: {
            const h = height, k = h * Theme.mediaTabCurve, w = width
            return `M ${w} 0 C ${w} ${k} 0 ${h / 2 - k} 0 ${h / 2} `
                 + `C 0 ${h / 2 + k} ${w} ${h - k} ${w} ${h} Z`
        }
    }

    // El icono, centrado en lo que ya ha salido; aparece con la cúpula
    Item {
        readonly property real shownFraction: Math.max(0, Math.min(1, root.depth / Theme.mediaTabDepth))
        width: Theme.iconSize
        height: Theme.iconSize
        anchors.verticalCenter: parent.verticalCenter
        x: root.width - root.depth * 0.5 - width / 2
        opacity: shownFraction * (root.playing ? 1 : 0.55)
        scale: 0.6 + 0.4 * shownFraction

        Image {
            id: favicon
            anchors.fill: parent
            sourceSize: Qt.size(2 * Theme.iconSize, 2 * Theme.iconSize)
            source: root.iconSource
            smooth: true
            mipmap: true
            visible: status === Image.Ready
        }
        Icon {
            anchors.fill: parent
            visible: !favicon.visible
            name: "music"
            size: Theme.iconSize
            color: root.hovered || root.expanded ? Colors.brandLight1 : Colors.ink
        }
    }

    // Solo responde la cúpula, no el hueco que deja mientras sale menos
    Item {
        anchors.right: parent.right
        width: root.depth
        height: parent.height

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.clicked()
        }
    }
}

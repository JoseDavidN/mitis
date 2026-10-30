import QtQuick
import Mitis.Core

// Pestaña de las esenciales: mientras haya alguna, una cúpula pequeña que sale
// del borde izquierdo (Main la pone debajo del sitio del gesto de atrás), con
// la forma de la del reproductor (MediaTab), el color de los controles y el
// icono de las esenciales (con el de la marca si se ve una esencial). Al
// pulsarla se despliega EssentialsPopup (lo abre Main). Solo anima al cambiar.
Item {
    id: root

    property bool shown: false
    // La pestaña a la vista es una esencial
    property bool active: false
    // El panel está desplegado: sale como al pasar el ratón
    property bool expanded: false
    readonly property bool hovered: hover.hovered

    signal clicked()

    // Cuánto ha salido del borde
    property real depth: !shown ? 0 : (hovered || expanded ? Theme.mediaTabHoverDepth : Theme.mediaTabDepth)
    Behavior on depth {
        NumberAnimation {
            duration: Theme.durationSlow
            easing.type: root.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: Theme.mediaTabOvershoot
        }
    }

    width: Theme.mediaTabHoverDepth
    height: Theme.mediaTabLength
    visible: depth > 0.5

    // La cúpula de MediaTab, del lado izquierdo
    SurfaceShape {
        width: Math.max(0, root.depth)
        height: parent.height
        fillStart: Colors.controlsStart
        fillEnd: Colors.controlsEnd
        path: {
            const h = height, k = h * Theme.mediaTabCurve, w = width
            return `M 0 0 C 0 ${k} ${w} ${h / 2 - k} ${w} ${h / 2} `
                 + `C ${w} ${h / 2 + k} 0 ${h - k} 0 ${h} Z`
        }
    }

    Icon {
        readonly property real shownFraction: Math.max(0, Math.min(1, root.depth / Theme.mediaTabDepth))
        anchors.verticalCenter: parent.verticalCenter
        x: root.depth * 0.5 - width / 2
        name: "essentials"
        size: Theme.iconSizeSmall
        color: root.active ? Colors.brandLight1 : root.hovered ? Colors.ink : Colors.inkSecondary
        opacity: shownFraction
        scale: 0.6 + 0.4 * shownFraction
    }

    // Solo responde la cúpula, no el hueco que deja mientras sale menos
    Item {
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

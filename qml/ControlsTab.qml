import QtQuick

// Pestaña del borde inferior cuando los controles están ocultos: un relieve
// pequeño que sale del borde, centrado, con el título de la página. Al pasar el
// ratón por encima, los controles vuelven (`hovered`, lo atiende Main).
Item {
    id: root

    property string title: ""
    readonly property bool hovered: hover.hovered

    // Los lados son curvas suaves de `controlsTabSlope` de ancho que salen del
    // borde de la ventana: el título va en la parte plana de arriba
    implicitWidth: Math.min(Theme.controlsTabMaxWidth, label.implicitWidth + 2 * Theme.margin)
                   + 2 * Theme.controlsTabSlope
    implicitHeight: Theme.controlsTabHeight

    // Un relieve del borde inferior: cada lado sube en una S (horizontal
    // abajo, donde se funde con el borde, y horizontal arriba), sin bordes
    SurfaceShape {
        anchors.fill: parent
        fillStart: Theme.controlsStart
        fillEnd: Theme.controlsEnd
        path: {
            const w = width, h = height, s = Theme.controlsTabSlope
            const k = s * Theme.controlsTabCurve
            return `M 0 ${h} C ${k} ${h} ${s - k} 0 ${s} 0 L ${w - s} 0 `
                 + `C ${w - s + k} 0 ${w - k} ${h} ${w} ${h} Z`
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - 2 * (Theme.margin + Theme.controlsTabSlope))
        text: root.title !== "" ? root.title : "Mitis"
        color: root.hovered ? Theme.ink : Theme.inkSecondary
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
}

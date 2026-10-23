import QtQuick

// Botón base de Mitis: flotante y redondeado, con un icono SVG (`icon`)
// o un texto corto (`glyph`, p. ej. el contador de pestañas).
Item {
    id: root

    property string icon: ""
    property int iconSize: Theme.iconSize
    property string glyph: ""

    // Tooltip: qué hace el botón y su atajo de teclado, si tiene
    property string tooltip: ""
    property string shortcut: ""
    property bool tooltipBelow: false
    property bool danger: false
    property bool flat: false
    // Encendido (p. ej. la página actual ya está en marcadores): icono en brandLight1
    property bool highlighted: false

    // Relleno: degradado horizontal. Quien lo coloca puede darle un tramo
    // de un degradado mayor (ver BottomBar)
    // Por defecto, el degradado de los controles (los tonos de Configuración);
    // la barra inferior le pasa a cada botón su tramo del degradado compartido
    property color fillStart: Theme.controlsStart
    property color fillEnd: Theme.controlsEnd

    signal clicked()

    implicitWidth: Theme.buttonSize
    implicitHeight: Theme.buttonSize

    readonly property bool hovered: hover.hovered
    readonly property bool pressed: tap.pressed

    Rectangle {
        id: bubble
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: root.flat && !root.hovered ? 0 : 1
        border.color: root.hovered && !root.danger ? Theme.hairlineHover : Theme.hairline
        scale: root.pressed ? Theme.pressScale : (root.hovered ? Theme.hoverScale : 1.0)

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeInOut
            }
        }

        // Relleno
        Rectangle {
            visible: !root.flat
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.fillStart }
                GradientStop { position: 1.0; color: root.fillEnd }
            }
        }

        // Peligro (cerrar): rosa al pasar por encima
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.dangerStrong
            opacity: root.danger && root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }

        // Realce al pasar por encima y al pulsar
        Rectangle {
            visible: !root.danger
            anchors.fill: parent
            radius: parent.radius
            // Sin superficie propia, el plano necesita un tinte más marcado
            color: root.pressed || (root.flat && root.hovered) ? Theme.tintActive
                                : (root.hovered ? Theme.tintHover : "transparent")
        }

        readonly property color tint: !root.enabled ? Theme.inkDisabled
                                    : root.highlighted ? Theme.brandLight1
                                    : (root.hovered ? (root.danger ? Theme.onBrand : Theme.ink)
                                                    : Theme.inkSoft)

        Icon {
            visible: root.icon !== ""
            anchors.centerIn: parent
            name: root.icon
            size: root.iconSize
            color: bubble.tint
        }

        // Centrado por la forma de los caracteres (tightBoundingRect), no por
        // su caja: la caja deja sitio a acentos y descendentes y el número
        // se vería desplazado
        Text {
            id: glyphText
            visible: root.icon === ""
            x: (parent.width - glyphBounds.tightBoundingRect.width) / 2 - glyphBounds.tightBoundingRect.x
            y: parent.height / 2 - baselineOffset - glyphBounds.tightBoundingRect.y
               - glyphBounds.tightBoundingRect.height / 2
            text: root.glyph
            font.pixelSize: Theme.fontSizeIcon
            font.weight: Theme.fontWeightIcon
            color: bubble.tint
        }
        TextMetrics {
            id: glyphBounds
            font: glyphText.font
            text: glyphText.text
        }
    }

    Tooltip {
        text: root.tooltip
        shortcut: root.shortcut
        below: root.tooltipBelow
        visible: root.tooltip !== "" && root.hovered && !root.pressed
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }
}

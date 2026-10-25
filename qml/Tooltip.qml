import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

// Tooltip propio: qué hace un control y, si tiene, su atajo de teclado.
// Aparece centrado sobre su padre (o debajo, con `below`) tras una espera.
// Uso: Tooltip { text: "Atrás"; shortcut: "Alt+←"; visible: hovered }
ToolTip {
    id: root

    property string shortcut: ""
    // Debajo del control en lugar de encima (barra de título)
    property bool below: false

    delay: Theme.tooltipDelay
    // Siempre en una línea: el ancho es el del contenido, nunca menos
    width: implicitWidth
    x: (parent.width - width) / 2
    y: below ? parent.height + Theme.spacing : -height - Theme.spacing
    // Nunca se sale de la ventana
    margins: Theme.spacing
    leftPadding: Theme.tooltipPaddingX
    rightPadding: Theme.tooltipPaddingX
    topPadding: Theme.tooltipPaddingY
    bottomPadding: Theme.tooltipPaddingY
    font.pixelSize: Theme.fontSizeSmall

    background: Surface {
        radius: Theme.radiusSmall
        fill: Colors.surfacePopup
    }

    contentItem: Row {
        spacing: Theme.spacing

        Text {
            text: root.text
            color: Colors.ink
            font: root.font
            wrapMode: Text.NoWrap
            maximumLineCount: 1
        }
        Text {
            visible: root.shortcut !== ""
            text: root.shortcut
            color: Colors.inkMuted
            font: root.font
            wrapMode: Text.NoWrap
            maximumLineCount: 1
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationFast }
    }
}

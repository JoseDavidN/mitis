import QtQuick

// Indicador de zoom: aparece arriba a la derecha al cambiar el zoom, se
// queda `Theme.zoomIndicatorHold` y se cierra solo. Mientras el ratón está
// encima no se cierra, para poder usar sus botones.
Item {
    id: root

    // Zoom de la pestaña activa (1 = 100 %)
    property real zoom: 1

    signal zoomInRequested()
    signal zoomOutRequested()
    signal resetRequested()

    // Muestra el indicador y reinicia la cuenta atrás
    function flash() {
        shown = true
        hold.restart()
    }

    property bool shown: false

    implicitWidth: content.implicitWidth + Theme.spacing
    implicitHeight: Theme.controlHeight

    visible: opacity > 0
    opacity: shown ? 1 : 0
    transform: Translate { y: root.shown ? 0 : -Theme.spacing }
    Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

    Timer {
        id: hold
        interval: Theme.zoomIndicatorHold
        onTriggered: if (!hover.hovered) root.shown = false
    }

    HoverHandler {
        id: hover
        // Al salir el ratón, vuelve a contar desde el principio
        onHoveredChanged: if (!hovered && root.shown) hold.restart()
    }

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

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacing / 2
        spacing: Theme.spacing / 2

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.buttonSizeSmall
            height: Theme.buttonSizeSmall
            flat: true
            icon: "zoom-out"
            iconSize: Theme.iconSizeSmall
            tooltip: "Alejar"
            shortcut: "Ctrl+-"
            tooltipBelow: true
            onClicked: root.zoomOutRequested()
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.zoomLabelWidth
            horizontalAlignment: Text.AlignHCenter
            text: Math.round(root.zoom * 100) + " %"
            color: Theme.ink
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.buttonSizeSmall
            height: Theme.buttonSizeSmall
            flat: true
            icon: "zoom-in"
            iconSize: Theme.iconSizeSmall
            tooltip: "Acercar"
            shortcut: "Ctrl++"
            tooltipBelow: true
            onClicked: root.zoomInRequested()
        }

        // Volver al 100 %: solo si no está ya
        Rectangle {
            visible: Math.abs(root.zoom - 1) > 0.001
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: Theme.buttonSizeSmall - Theme.spacing
            color: Theme.line
        }
        Text {
            visible: Math.abs(root.zoom - 1) > 0.001
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Theme.spacing / 2
            rightPadding: Theme.spacing
            text: "Restablecer"
            color: resetHover.hovered ? Theme.ink : Theme.inkSecondary
            font.pixelSize: Theme.fontSizeSmall

            HoverHandler {
                id: resetHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: root.resetRequested()
            }
        }
    }
}

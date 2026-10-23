import QtQuick

// Aviso arriba en el centro, hasta cerrarlo: tarjeta con el estilo de los
// controles, icono, texto, botones propios (hijos) y la ✕. Lo usan el de
// cierre inesperado (CrashReports) y el de versión nueva (Updates).
Item {
    id: root

    property bool shown: false
    property string text: ""
    property string icon: "info"
    // Los botones del aviso (TextButton), entre el texto y la ✕
    default property alias actions: actionsRow.data

    signal closed()

    implicitWidth: row.implicitWidth + 2 * Theme.margin
    implicitHeight: row.implicitHeight + Theme.margin

    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        border.width: 1
        border.color: Theme.hairline
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: glass.active ? "transparent" : Theme.controlsStart }
            GradientStop { position: 1.0; color: glass.active ? "transparent" : Theme.controlsEnd }
        }
        Glass {
            id: glass
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacing

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            color: Theme.brandLight1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: Theme.spacing
            text: root.text
            color: Theme.ink
            font.pixelSize: Theme.fontSize
        }
        Row {
            id: actionsRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "close"
            flat: true
            tooltip: "Cerrar"
            tooltipBelow: true
            onClicked: root.closed()
        }
    }
}

import QtQuick
import Mitis.Core

// Diálogo de una pestaña: lo que una página pide al usuario (alert, permiso,
// certificado…). Se declara dentro del delegado BrowserTab de Main.qml y
// cubre solo la página de esa pestaña: al cambiar de pestaña se oculta con
// ella y vuelve al regresar. Las demás pestañas y los controles inferiores
// siguen disponibles, como en Chrome.
//
// Uso:
//   PageDialog {
//       id: dialog
//       title: "…"; message: "…"; iconName: "…"
//       onAccepted: …; onRejected: …
//       FormField { width: parent.width }        // contenido extra (opcional)
//       buttons: [ TextButton { … }, TextButton { primary: true; … } ]
//   }
//   dialog.show() / dialog.hide()
FocusScope {
    id: root

    property string title: ""
    property string message: ""
    // Icono junto al título (assets/icons); "" sin icono
    property string iconName: ""
    // Aviso serio (certificados): icono y título en Colors.danger
    property bool danger: false
    // Ancho de la tarjeta; los avisos largos pueden pedir más
    property int cardWidth: Theme.dialogWidth
    // Contenido entre el mensaje y los botones (campos, casillas…)
    default property alias content: extra.data
    // Botones, de izquierda a derecha: cancelar primero, la acción principal al final
    property alias buttons: buttonRow.data

    readonly property bool shown: _shown
    property bool _shown: false

    // Enter y Esc (con el foco en el diálogo)
    signal accepted()
    signal rejected()

    function show() {
        _shown = true
        root.forceActiveFocus()
    }
    function hide() {
        _shown = false
    }

    anchors.fill: parent
    z: 10
    visible: opacity > 0
    opacity: _shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

    // Al volver a la pestaña, el foco vuelve al diálogo
    onVisibleChanged: if (visible && _shown) root.forceActiveFocus()

    Keys.onEscapePressed: root.rejected()
    Keys.onReturnPressed: root.accepted()
    Keys.onEnterPressed: root.accepted()

    // Velo: tapa la página para que no reciba clics, rueda ni hover
    Rectangle {
        anchors.fill: parent
        color: Colors.backgroundScrim
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    PopupBackground {
        id: card
        anchors.centerIn: parent
        width: Math.min(root.cardWidth, root.width - 2 * Theme.margin)
        height: body.implicitHeight + 2 * body.anchors.margins
        scale: root._shown ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: Theme.durationBase; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

        Column {
            id: body
            anchors.fill: parent
            anchors.margins: Theme.margin + Theme.spacing
            spacing: Theme.margin

            Row {
                width: parent.width
                spacing: Theme.spacing
                visible: root.title !== ""

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.iconName !== ""
                    name: root.iconName
                    color: root.danger ? Colors.danger : Colors.brandLight1
                }
                Text {
                    width: parent.width - (root.iconName !== "" ? Theme.iconSize + parent.spacing : 0)
                    text: root.title
                    color: root.danger ? Colors.danger : Colors.ink
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }
            }

            Text {
                width: parent.width
                visible: root.message !== ""
                text: root.message
                color: Colors.inkSoft
                font.pixelSize: Theme.fontSize
                wrapMode: Text.Wrap
                // Los mensajes de las páginas son texto, nunca HTML
                textFormat: Text.PlainText
                maximumLineCount: 20
                elide: Text.ElideRight
            }

            Column {
                id: extra
                width: parent.width
                spacing: Theme.spacing
                visible: children.length > 0
            }

            Row {
                id: buttonRow
                anchors.right: parent.right
                spacing: Theme.spacing
            }
        }
    }
}

import QtQuick
import QtQuick.Controls.Basic

import "urls.js" as Urls

// Diálogo para añadir un acceso rápido: nombre (opcional) y dirección.
// Sin nombre, se usa el dominio.
Popup {
    id: root

    signal added(string name, string url)

    function openEmpty() {
        nameField.text = ""
        urlField.text = ""
        open()
        urlField.forceActiveFocus()
    }

    function accept() {
        const url = SearchEngines.resolve(urlField.text)
        if (url === "" || urlField.text.trim().indexOf(" ") >= 0)
            return
        const name = nameField.text.trim() || Urls.host(url) || url
        added(name, url)
        close()
    }

    width: Theme.dialogWidth
    padding: Theme.margin + Theme.spacing
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent

    Overlay.modal: Rectangle { color: Theme.backgroundScrim }

    background: PopupBackground {}

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationBase }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationFast }
    }

    contentItem: Column {
        spacing: Theme.margin

        Text {
            text: "Nuevo acceso rápido"
            color: Theme.ink
            font.pixelSize: Theme.fontSizeTitle
            font.weight: Font.DemiBold
        }

        FormField {
            id: urlField
            width: parent.width
            placeholderText: "Dirección, p. ej. github.com"
            onAccepted: root.accept()
        }

        FormField {
            id: nameField
            width: parent.width
            placeholderText: "Nombre (opcional)"
            onAccepted: root.accept()
        }

        Row {
            anchors.right: parent.right
            spacing: Theme.spacing

            TextButton {
                text: "Cancelar"
                onClicked: root.close()
            }
            TextButton {
                text: "Añadir"
                primary: true
                enabled: urlField.text.trim() !== ""
                onClicked: root.accept()
            }
        }
    }
}

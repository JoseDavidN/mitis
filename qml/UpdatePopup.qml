import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

// Confirmación de la actualización (botón UpdateButton de la barra
// inferior): «Confirmar» la empieza (Updates.install()); «Cancelar» solo
// cierra esto. Mientras se descarga (macOS y Linux), el avance.
Popup {
    id: root

    width: Theme.updatePopupWidth
    padding: Theme.margin
    focus: true
    closePolicy: Updates.installing ? Popup.NoAutoClose
                                    : Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: PopupBackground {}

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationFast }
    }

    contentItem: Column {
        spacing: Theme.spacing

        Text {
            width: parent.width
            text: "Actualizar ahora"
            color: Theme.ink
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            color: Updates.error !== "" && !Updates.installing ? Theme.danger : Theme.inkMuted
            font.pixelSize: Theme.fontSizeSmall
            text: Updates.installing
                  ? "Descargando Mitis " + Updates.available + "…"
                    + (Updates.progress >= 0 ? " " + Math.round(Updates.progress * 100) + " %" : "")
                  : Updates.error !== "" && Updates.canInstall ? Updates.error
                  : Updates.canInstall
                    ? "Mitis " + Updates.available + " está disponible. Mitis se cerrará, se actualizará y volverá a abrirse con tus pestañas."
                    : "Mitis " + Updates.available + " está disponible. Esta instalación no se puede actualizar desde Mitis: descarga e instala la versión nueva."
        }
        Item {
            width: parent.width
            height: Theme.spacing / 2
        }
        Row {
            visible: !Updates.installing
            anchors.right: parent.right
            spacing: Theme.spacing

            TextButton {
                text: "Cancelar"
                onClicked: root.close()
            }
            TextButton {
                visible: Updates.canInstall
                primary: true
                text: Updates.error !== "" ? "Reintentar" : "Confirmar"
                onClicked: Updates.install()
            }
        }
    }
}

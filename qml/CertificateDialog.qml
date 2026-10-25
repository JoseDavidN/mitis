import QtQuick
import Mitis.Core

// Aviso de certificado inválido de una pestaña (BrowserTab.certificateErrorRequested).
// La opción segura, «Volver», es la principal y la de Enter y Esc; «Continuar
// de todos modos» solo aparece si el motor lo permite y se ve menos.
PageDialog {
    id: root

    // Petición pendiente de BrowserTab: { url, host, reason, overridable, proceed(), reject(), back() }
    property var error: null

    // Se rechazó el certificado: la pestaña vuelve a la página anterior, o se
    // queda en la página de error del motor si no la hay
    signal backRequested()
    // Se aceptó el certificado y la página sigue cargando
    signal proceeded()

    function ask(request) {
        root.error = request
        root.show()
    }
    // El aviso dejó de estar pendiente por otra vía (otra navegación)
    function dismiss() {
        root.error = null
        root.hide()
    }

    function _back() {
        if (!root.error)
            return
        root.error.back()
        root.dismiss()
        root.backRequested()
    }
    function _proceed() {
        if (!root.error)
            return
        root.error.proceed()
        root.dismiss()
        root.proceeded()
    }

    danger: true
    iconName: "not-secure"
    title: "La conexión no es privada"
    cardWidth: Theme.certificateDialogWidth
    message: root.error
             ? "Puede que alguien esté intentando hacerse pasar por " + root.error.host
               + ". Lo que envíes a este sitio (contraseñas, mensajes, datos de tarjetas) podrían verlo otros."
             : ""

    onAccepted: root._back()
    onRejected: root._back()

    Text {
        width: parent.width
        text: root.error ? root.error.reason : ""
        color: Colors.inkMuted
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
    }

    buttons: [
        TextButton {
            text: "Continuar de todos modos"
            danger: true
            visible: root.error !== null && root.error.overridable
            onClicked: root._proceed()
        },
        TextButton {
            text: "Volver"
            primary: true
            onClicked: root._back()
        }
    ]
}

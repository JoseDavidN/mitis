import QtQuick
import Mitis.Core

// Aviso de una pestaña cuya página pide contenido protegido (Netflix,
// Spotify…) sin Widevine en el motor (BrowserTab.protectedContentUnavailable).
// Explica qué falta y cómo instalarlo según el sistema.
PageDialog {
    id: root

    // Dominio de la página que lo pidió
    property string host: ""

    signal closed()

    function ask(pageHost) {
        root.host = pageHost
        root.show()
    }
    function _close() {
        root.hide()
        root.closed()
    }

    iconName: "protected-content"
    title: "Este sitio necesita Widevine"
    cardWidth: Theme.certificateDialogWidth
    message: (root.host !== "" ? root.host : "Esta página") + " reproduce contenido protegido (series, películas o música)"
             + " con Widevine, un componente de Google que Mitis no puede incluir. Mitis usa el que tenga"
             + " instalado otro navegador del equipo."

    onAccepted: root._close()
    onRejected: root._close()

    Text {
        width: parent.width
        text: Qt.platform.os === "linux"
              ? "Para tenerlo, instala Google Chrome o, en Arch Linux, el paquete chromium-widevine (AUR)."
                + " También sirve Firefox con la reproducción de contenido con DRM activada. Después, reinicia Mitis."
              : "Para tenerlo, instala Google Chrome y ábrelo una vez. Después, reinicia Mitis."
        color: Colors.inkSecondary
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.Wrap
    }

    buttons: [
        TextButton {
            text: "Entendido"
            primary: true
            onClicked: root._close()
        }
    ]
}

import QtQuick

// ¿Abrir la aplicación? (BrowserTab.externalAppRequested): una página quiere
// abrir un enlace de una aplicación del equipo (Teams, Zoom, el correo…).
// Como en Chrome, se pregunta siempre. Si llega otra mientras se ve, la
// sustituye: las páginas suelen repetir el intento.
PageDialog {
    id: root

    // { url, scheme, site, open() } o null
    property var request: null

    // Se respondió (abriendo o no)
    signal finished()

    // Nombre de las aplicaciones más comunes por su esquema; las demás, «la aplicación»
    readonly property var _apps: ({
        msteams: "Microsoft Teams", zoommtg: "Zoom", zoomus: "Zoom", slack: "Slack",
        discord: "Discord", spotify: "Spotify", steam: "Steam", whatsapp: "WhatsApp",
        tg: "Telegram", skype: "Skype", vscode: "Visual Studio Code", webex: "Webex",
        mailto: "tu programa de correo", tel: "la aplicación de llamadas"
    })
    readonly property string _app: request ? (_apps[request.scheme] ?? "la aplicación") : ""

    function ask(external) {
        root.request = external
        root.show()
    }
    function _answer(open) {
        if (open && root.request)
            root.request.open()
        root.request = null
        root.hide()
        root.finished()
    }

    iconName: "open-link"
    title: "¿Abrir " + _app + "?"
    message: !request ? ""
           : (request.site !== "" ? request.site : "Esta página") + " quiere abrir un enlace «"
             + request.scheme + ":» en una aplicación de tu equipo."

    // Enter no abre a propósito: un Enter que se estaba pulsando en la página
    // al aparecer el diálogo no debe lanzar una aplicación
    onRejected: _answer(false)

    buttons: [
        TextButton {
            text: "Cancelar"
            onClicked: root._answer(false)
        },
        TextButton {
            text: "Abrir"
            primary: true
            onClicked: root._answer(true)
        }
    ]
}

pragma ComponentBehavior: Bound
import QtQuick

// Diálogos JavaScript de una pestaña (alert, confirm, prompt y el aviso de
// salir con cambios sin guardar). Va dentro del delegado BrowserTab de
// Main.qml, como PageDialog. Si la página pide varios, se muestran en orden.
// El diálogo se crea la primera vez que hace falta: las pestañas que nunca
// muestran uno no lo pagan.
Item {
    id: root

    // Se cerró el último diálogo pendiente (para devolver el foco a la página)
    signal closed()

    // Pendientes; el primero es el que se ve
    property var queue: []
    readonly property var current: queue.length > 0 ? queue[0] : null

    // Añade un diálogo de BrowserTab.javaScriptDialogRequested
    function enqueue(dialog) {
        queue = queue.concat([dialog])
        loader.active = true
    }
    // Lo quita sin responder (BrowserTab.javaScriptDialogCancelled)
    function cancel(dialog) {
        if (!queue.includes(dialog))
            return
        queue = queue.filter(item => item !== dialog)
        if (!current)
            root.closed()
    }
    // Responde al diálogo visible; `text` es lo escrito en un prompt
    function answer(ok, text) {
        const dialog = current
        if (!dialog)
            return
        queue = queue.slice(1)
        if (ok)
            dialog.accept(text)
        else
            dialog.reject()
        if (!current)
            root.closed()
    }

    anchors.fill: parent
    z: 10

    Loader {
        id: loader
        anchors.fill: parent
        active: false

        sourceComponent: PageDialog {
            id: page

            readonly property var request: root.current
            readonly property string type: request ? request.type : ""

            // Cada diálogo nuevo se muestra con el foco listo; sin ninguno, se oculta
            onRequestChanged: {
                if (!request) {
                    hide()
                    return
                }
                show()
                // request.type y no `type`: este manejador puede correr antes
                // de que se actualice esa propiedad (p. ej. un prompt tras un confirm)
                if (request.type === "prompt") {
                    field.text = request.defaultText
                    field.selectAll()
                    field.forceActiveFocus()
                }
            }
            Component.onCompleted: requestChanged()

            // Al volver a la pestaña PageDialog da el foco a la tarjeta: en
            // un prompt, mejor al campo
            onVisibleChanged: if (visible && shown && type === "prompt") Qt.callLater(() => field.forceActiveFocus())

            title: type === "beforeunload" ? "¿Salir de este sitio?"
                 : request && request.origin !== "" ? request.origin + " dice"
                 : "Esta página dice"
            message: type === "beforeunload" ? "Puede que no se guarden los cambios que hayas hecho."
                   : request ? request.message : ""

            onAccepted: root.answer(true, field.text)
            onRejected: root.answer(type === "alert", "")

            FormField {
                id: field
                width: parent.width
                // Enter llega a PageDialog, que acepta
                visible: page.type === "prompt"
            }

            buttons: [
                TextButton {
                    text: "Cancelar"
                    visible: page.type !== "alert"
                    onClicked: root.answer(false, "")
                },
                TextButton {
                    text: page.type === "beforeunload" ? "Salir" : "Aceptar"
                    primary: true
                    onClicked: root.answer(true, field.text)
                }
            ]
        }
    }
}

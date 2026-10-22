import QtQuick
import "urls.js" as Urls

// Pregunta si un sitio puede usar la cámara, el micrófono, la ubicación…
// Una por pestaña, dentro del delegado BrowserTab de Main.qml. Las peticiones
// que llegan seguidas esperan en cola y se muestran de una en una.
//
// Uso:
//   PermissionDialog {
//       pageUrl: tab.url
//       onFinished: tab.focusPage()
//   }
//   tab.onPermissionRequested: permission => dialog.ask(permission)
PageDialog {
    id: root

    // Dirección de la página: si pasa a otro sitio, lo pendiente se descarta
    property string pageUrl: ""

    // Se respondió la última petición de la cola
    signal finished()

    // Peticiones sin responder (la primera es la que se ve), con el sitio
    // que tenía la página al llegar: { permission, pageHost }
    property var _queue: []
    readonly property var _current: _queue.length > 0 ? _queue[0].permission : null

    // Qué quiere hacer el sitio, para «ejemplo.com quiere …», y su icono
    readonly property var _texts: ({
        camera: "usar tu cámara",
        microphone: "usar tu micrófono",
        cameraMicrophone: "usar tu cámara y tu micrófono",
        screen: "ver tu pantalla",
        screenAudio: "ver tu pantalla y oír su sonido",
        location: "conocer tu ubicación",
        notifications: "mostrarte notificaciones",
        clipboard: "leer y cambiar tu portapapeles",
        fonts: "ver las fuentes instaladas en tu equipo"
    })
    readonly property var _icons: ({
        camera: "camera",
        microphone: "microphone",
        cameraMicrophone: "camera-microphone",
        screen: "screen",
        screenAudio: "screen",
        location: "location",
        notifications: "notifications",
        clipboard: "clipboard",
        fonts: "fonts"
    })

    function ask(permission) {
        _queue = _queue.concat([{ permission: permission, pageHost: Urls.host(pageUrl) }])
        if (!shown)
            show()
    }

    // Responde la petición visible y pasa a la siguiente
    function _answer(allow) {
        const permission = _current
        if (!permission)
            return
        _queue = _queue.slice(1)
        if (allow)
            permission.grant()
        else
            permission.deny()
        if (_queue.length === 0) {
            hide()
            finished()
        }
    }

    title: _current ? (Urls.host(_current.origin) || _current.origin) + " quiere " + _texts[_current.kind] : ""
    message: !_current ? ""
           : _current.remembered ? "Mitis recordará tu decisión para este sitio."
           : "Se volverá a preguntar la próxima vez."
    iconName: _current ? _icons[_current.kind] : ""

    // Esc bloquea. Enter no concede nada a propósito: un Enter que se estaba
    // pulsando en la página al aparecer el diálogo no debe dar un permiso.
    onRejected: _answer(false)

    // La página pasó a otro sitio: lo que pidió el anterior ya no vale. Se
    // descarta sin guardar: el usuario no llegó a decidir
    onPageUrlChanged: {
        const host = Urls.host(pageUrl)
        const stale = _queue.filter(item => item.pageHost !== host)
        if (stale.length === 0)
            return
        _queue = _queue.filter(item => item.pageHost === host)
        stale.forEach(item => item.permission.dismiss())
        if (_queue.length === 0 && shown) {
            hide()
            finished()
        }
    }

    // Pestaña cerrada: se descarta lo pendiente
    Component.onDestruction: _queue.forEach(item => item.permission.dismiss())

    buttons: [
        TextButton {
            text: "Bloquear"
            onClicked: root._answer(false)
        },
        TextButton {
            text: "Permitir"
            primary: true
            onClicked: root._answer(true)
        }
    ]
}

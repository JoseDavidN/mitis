import QtQuick
import QtQuick.Controls.Basic

// Una lista desplegable (Popup) que solo existe mientras se usa: se crea al
// abrirla y se destruye cuando termina de cerrarse (tras su animación). Así
// cada ventana, también las privadas, no lleva en memoria listas que quizá
// nunca abra. Lo de dentro se declara como Component en quien la usa y ve
// sus ids; lo que deba durar más que la lista (estado, selección) va fuera.
//
// Uso:
//   LazyPopup {
//       id: tabsPopup
//       popup: Component { TabsPopup { parent: bottomBar.tabsButton; … } }
//   }
//   tabsPopup.open() / close() / toggle(); tabsPopup.opened; tabsPopup.item
Loader {
    id: root

    property Component popup
    readonly property Popup _popup: item as Popup
    readonly property bool opened: _popup !== null && _popup.opened

    function open() {
        root.active = true
        root._popup.open()
    }
    function close() {
        if (root._popup)
            root._popup.close()
    }
    function toggle() {
        if (root.opened)
            root.close()
        else
            root.open()
    }

    // Toda la ventana: las que no fijan su `parent` se colocan en ella
    anchors.fill: parent
    active: false
    sourceComponent: popup

    Connections {
        target: root._popup
        // Fuera del aviso de cierre: no se destruye un objeto mientras emite.
        // Si entretanto se volvió a abrir, se queda
        function onClosed() {
            Qt.callLater(() => {
                if (root._popup && !root._popup.visible)
                    root.active = false
            })
        }
    }
}

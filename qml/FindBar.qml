import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

// Buscar en la página (Ctrl+F): píldora flotante centrada bajo la barra de
// título. Busca mientras se escribe; Intro va a la siguiente coincidencia,
// Mayús+Intro a la anterior y Esc cierra. No conoce el motor: pide las
// búsquedas con señales y recibe el resultado en `matches` y `active`.
Item {
    id: root

    // Resultado de la última búsqueda (lo da la pestaña)
    property int matches: 0
    property int active: 0

    readonly property bool isOpen: shown
    readonly property string text: field.text

    property bool shown: false

    signal searchRequested(string text, bool backward)
    signal closed()

    // Abre (o, si ya está abierta, vuelve a ella) con el texto seleccionado
    function openAndFocus() {
        shown = true
        field.forceActiveFocus()
        field.selectAll()
        if (field.text !== "")
            searchRequested(field.text, false)
    }

    function close() {
        if (!shown)
            return
        shown = false
        closed()
    }

    function findNext() {
        if (field.text !== "")
            searchRequested(field.text, false)
    }

    function findPrevious() {
        if (field.text !== "")
            searchRequested(field.text, true)
    }

    implicitWidth: Theme.findBarWidth
    implicitHeight: Theme.controlHeight

    // Aparece deslizándose desde la barra de título
    visible: opacity > 0
    opacity: shown ? 1 : 0
    transform: Translate { y: root.shown ? 0 : -Theme.spacing }
    Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

    readonly property bool noMatches: field.text !== "" && matches === 0

    Surface {
        anchors.fill: parent
        radius: height / 2
        border.width: field.activeFocus ? 1 : 0
        border.color: Colors.focusRing
        fillStart: Colors.controlsStart
        fillEnd: Colors.controlsEnd
    }

    Icon {
        id: searchIcon
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: Theme.iconSizeSmall
        color: field.activeFocus ? Colors.brandLight1 : Colors.inkMuted
    }

    TextField {
        id: field
        anchors.left: searchIcon.right
        anchors.leftMargin: Theme.spacing / 2
        anchors.right: counter.left
        anchors.rightMargin: Theme.spacing
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: Theme.spacing / 2
        rightPadding: 0
        color: Colors.ink
        placeholderText: "Buscar en la página"
        placeholderTextColor: Colors.inkMuted
        selectionColor: Colors.selection
        selectedTextColor: Colors.ink
        font.pixelSize: Theme.fontSize
        selectByMouse: true
        background: null

        // Busca mientras se escribe
        onTextChanged: root.searchRequested(text, false)

        Keys.onReturnPressed: event => {
            if (event.modifiers & Qt.ShiftModifier)
                root.findPrevious()
            else
                root.findNext()
        }
        Keys.onEnterPressed: event => {
            if (event.modifiers & Qt.ShiftModifier)
                root.findPrevious()
            else
                root.findNext()
        }
        Keys.onEscapePressed: root.close()
    }

    // "2 de 7" o "Sin coincidencias"
    Text {
        id: counter
        anchors.right: buttons.left
        anchors.rightMargin: Theme.spacing
        anchors.verticalCenter: parent.verticalCenter
        visible: field.text !== ""
        text: root.noMatches ? "Sin coincidencias" : root.active + " de " + root.matches
        color: root.noMatches ? Colors.danger : Colors.inkMuted
        font.pixelSize: Theme.fontSizeSmall
    }

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacing / 2
        anchors.verticalCenter: parent.verticalCenter

        IconButton {
            width: Theme.buttonSizeSmall
            height: Theme.buttonSizeSmall
            flat: true
            icon: "find-previous"
            iconSize: Theme.iconSizeSmall
            tooltipBelow: true
            enabled: root.matches > 0
            tooltip: "Anterior"
            shortcut: "Mayús+Intro"
            onClicked: root.findPrevious()
        }
        IconButton {
            width: Theme.buttonSizeSmall
            height: Theme.buttonSizeSmall
            flat: true
            icon: "find-next"
            iconSize: Theme.iconSizeSmall
            tooltipBelow: true
            enabled: root.matches > 0
            tooltip: "Siguiente"
            shortcut: "Intro"
            onClicked: root.findNext()
        }
        IconButton {
            width: Theme.buttonSizeSmall
            height: Theme.buttonSizeSmall
            flat: true
            icon: "close"
            iconSize: Theme.iconSizeSmall
            tooltipBelow: true
            tooltip: "Cerrar"
            shortcut: "Esc"
            onClicked: root.close()
        }
    }
}

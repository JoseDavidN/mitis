import QtQuick
import QtQuick.Controls.Basic

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

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        border.width: 1
        border.color: field.activeFocus ? Theme.focusRing : Theme.hairline
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: glass.active ? "transparent" : Theme.controlsStart }
            GradientStop { position: 1.0; color: glass.active ? "transparent" : Theme.controlsEnd }
        }
        Glass {
            id: glass
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    }

    Icon {
        id: searchIcon
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: Theme.iconSizeSmall
        color: field.activeFocus ? Theme.brandLight1 : Theme.inkMuted
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
        color: Theme.ink
        placeholderText: "Buscar en la página"
        placeholderTextColor: Theme.inkMuted
        selectionColor: Theme.selection
        selectedTextColor: Theme.ink
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
        color: root.noMatches ? Theme.danger : Theme.inkMuted
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

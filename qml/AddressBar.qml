import QtQuick
import QtQuick.Controls.Basic

import "urls.js" as Urls

// Campo de dirección y búsqueda. Si lo escrito no parece una URL,
// se busca en DuckDuckGo.
// Dos modos: al escribir (con foco) muestra la dirección y ocupa todo el
// ancho; en reposo muestra el título corto de la página y se encoge a su
// tamaño (compactWidth). Quien lo coloca decide el ancho (ver BottomBar).
TextField {
    id: root

    // Dirección y título de la página actual
    property url currentUrl
    property string pageTitle: ""
    property bool loading: false
    property int loadProgress: 0

    // Relleno: tramo del degradado compartido de los controles (ver BottomBar)
    property color fillStart: Theme.surfaceFloat
    property color fillEnd: Theme.surfaceFloat

    readonly property bool editing: activeFocus

    // Texto del modo reposo: título sin lo que va tras un guion separador
    // ("DuckDuckGo - Privacidad" → "DuckDuckGo"); si no hay, el dominio
    readonly property string shortTitle: {
        const title = pageTitle.split(/\s+[-–—]\s+/)[0].trim()
        if (title !== "")
            return title
        return Urls.host(currentUrl.toString())
    }

    // Ancho del modo reposo: el título más un margen a cada lado
    readonly property real compactWidth: Math.ceil(titleMetrics.advanceWidth)
                                         + 2 * (Theme.margin + Theme.spacing)

    signal navigate(url target)

    function focusAndSelect() {
        forceActiveFocus()
        selectAll()
    }


    implicitHeight: Theme.controlHeight
    leftPadding: Theme.margin + Theme.iconSizeSmall + Theme.spacing
    rightPadding: Theme.margin + Theme.spacing / 2
    verticalAlignment: TextInput.AlignVCenter
    color: Theme.ink
    // Solo al escribir: en reposo el hueco lo ocupa el título
    placeholderText: editing ? "Buscar o escribir una dirección" : ""
    placeholderTextColor: Theme.inkMuted
    selectionColor: Theme.selection
    selectedTextColor: Theme.ink
    font.pixelSize: Theme.fontSize
    selectByMouse: true

    TextMetrics {
        id: titleMetrics
        font: root.font
        text: root.shortTitle || "Buscar"
    }

    background: Rectangle {
        id: field
        radius: height / 2
        border.width: 1
        border.color: root.editing ? Theme.focusRing
                                   : (fieldHover.hovered ? Theme.hairlineHover : Theme.hairline)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.fillStart }
            GradientStop { position: 1.0; color: root.fillEnd }
        }

        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

        // Realce al pasar por encima
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: fieldHover.hovered && !root.editing ? Theme.tintHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        // Icono de búsqueda: solo al escribir
        Icon {
            anchors.left: parent.left
            anchors.leftMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: Theme.iconSizeSmall
            color: Theme.brandLight1
            opacity: root.editing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }

        // Título corto de la página: solo en reposo
        Text {
            anchors.fill: parent
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.rightMargin: Theme.margin + Theme.spacing
            text: root.shortTitle || "Buscar"
            color: root.shortTitle ? Theme.inkStrong : Theme.inkMuted
            font: root.font
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: root.editing ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }

        // Progreso de carga, a lo largo del borde inferior del campo
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: field.radius
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.progressHeight
            height: Theme.progressHeight
            radius: height / 2
            width: (parent.width - 2 * field.radius) * root.loadProgress / 100
            opacity: root.loading ? 1 : 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.brand1 }
                GradientStop { position: 1.0; color: Theme.brand2 }
            }
            Behavior on width { NumberAnimation { duration: Theme.durationBase } }
            Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
        }
    }

    HoverHandler {
        id: fieldHover
        cursorShape: root.editing ? Qt.IBeamCursor : Qt.PointingHandCursor
    }

    // En reposo el campo va vacío: el título lo pinta el Text del fondo
    Binding on text {
        when: !root.editing
        value: ""
        restoreMode: Binding.RestoreNone
    }

    // Al empezar a escribir se recupera la dirección, seleccionada
    onEditingChanged: {
        if (editing) {
            text = currentUrl.toString()
            selectAll()
        }
    }

    onAccepted: {
        const target = Urls.resolve(text)
        if (target !== "") {
            focus = false
            navigate(target)
        }
    }

    Keys.onEscapePressed: focus = false
}

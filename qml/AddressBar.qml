pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

import "urls.js" as Urls

// Campo de dirección y búsqueda. Si lo escrito no parece una URL,
// se busca en el buscador elegido (SearchEngines).
// Dos modos: al escribir (con foco) muestra la dirección y ocupa todo el
// ancho; en reposo muestra el título corto de la página y se encoge a su
// tamaño (compactWidth). Quien lo coloca decide el ancho (ver BottomBar).
// Al escribir, encima aparecen sugerencias de los marcadores y el historial.
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

    // ── Sugerencias ──────────────────────────────────────────────────
    // [{ url, title, bookmark }]: primero marcadores, luego historial
    property var suggestions: []
    // La elegida con las flechas; -1 = lo escrito
    property int suggestionIndex: -1
    readonly property int suggestionsMax: 6

    function updateSuggestions() {
        suggestionIndex = -1
        const query = text.trim()
        if (!editing || query === "") {
            suggestions = []
            return
        }
        const list = []
        const seen = {}
        const take = (items, bookmark) => {
            for (const item of items) {
                if (list.length >= suggestionsMax)
                    return
                if (seen[item.url])
                    continue
                seen[item.url] = true
                list.push({ url: item.url, title: item.title, bookmark: bookmark })
            }
        }
        take(Bookmarks.search(query, 3), true)
        take(History.suggest(query, suggestionsMax), false)
        suggestions = list
    }

    function moveSuggestion(step) {
        if (suggestions.length === 0)
            return
        suggestionIndex = Math.max(-1, Math.min(suggestions.length - 1, suggestionIndex + step))
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
        } else {
            suggestions = []
        }
    }
    onTextEdited: updateSuggestions()

    onAccepted: {
        const target = suggestionIndex >= 0 ? suggestions[suggestionIndex].url
                                            : SearchEngines.resolve(text)
        if (target !== "") {
            focus = false
            navigate(target)
        }
    }

    Keys.onUpPressed: moveSuggestion(-1)
    Keys.onDownPressed: moveSuggestion(1)
    // Con sugerencias, Esc las cierra; sin ellas, deja de escribir
    Keys.onEscapePressed: {
        if (suggestions.length > 0)
            suggestions = []
        else
            focus = false
    }

    // Se abren hacia arriba, con el ancho del campo. No se quedan el foco:
    // se sigue escribiendo en el campo.
    Popup {
        id: suggestionList
        visible: root.editing && root.suggestions.length > 0
        y: -height - Theme.floatingMargin
        width: root.width
        padding: Theme.spacing / 2
        focus: false
        closePolicy: Popup.NoAutoClose

        background: PopupBackground {}

        contentItem: Column {
            Repeater {
                model: root.suggestions

                delegate: Item {
                    id: suggestion

                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.suggestionIndex

                    width: suggestionList.availableWidth
                    height: Theme.popupRowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: suggestion.selected ? Theme.tintActive
                                                   : (suggestionHover.hovered ? Theme.tintHover : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    }

                    Icon {
                        id: suggestionIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin
                        anchors.verticalCenter: parent.verticalCenter
                        name: suggestion.modelData.bookmark ? "bookmark" : "history"
                        color: suggestion.selected ? Theme.brandLight1 : Theme.inkMuted
                    }

                    Text {
                        id: suggestionTitle
                        anchors.left: suggestionIcon.right
                        anchors.leftMargin: Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, (parent.width - x - Theme.margin) * 0.6)
                        text: suggestion.modelData.title || Urls.host(suggestion.modelData.url)
                        color: Theme.ink
                        font.pixelSize: Theme.fontSize
                        font.weight: suggestion.selected ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.left: suggestionTitle.right
                        anchors.leftMargin: Theme.spacing
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.margin
                        anchors.verticalCenter: parent.verticalCenter
                        text: suggestion.modelData.url.replace(/^https?:\/\/(www\.)?/, "")
                        color: Theme.inkMuted
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    HoverHandler {
                        id: suggestionHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            root.focus = false
                            root.navigate(suggestion.modelData.url)
                        }
                    }
                }
            }
        }
    }
}

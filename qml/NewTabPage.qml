pragma ComponentBehavior: Bound
import QtCore as Core
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import Mitis.Core

import "urls.js" as Urls

// Página de nueva pestaña, en QML: buscador en el centro, accesos rápidos
// y noticias de tecnología, sobre el fondo del tema o una imagen propia.
// Una sola instancia para todas las pestañas (ver Main.qml).
Item {
    id: root

    signal navigate(url target)
    // Ventana privada: sin fondo propio ni cambios en los accesos rápidos
    // (nada de Configuración) y un aviso de lo que hace la ventana
    property bool privateMode: false

    function focusSearch() {
        search.forceActiveFocus()
    }

    // ── Sugerencias del buscador ─────────────────────────────────────
    // [{ query, url, title, bookmark }]: primero lo buscado antes (`query`:
    // páginas de resultados del historial, la más reciente primero); al
    // escribir, las que coinciden y luego marcadores e historial. Sin
    // escribir, solo las búsquedas recientes (no en la ventana privada)
    property var suggestions: []
    // La elegida con las flechas; -1 = lo escrito
    property int suggestionIndex: -1
    readonly property int suggestionsMax: 6
    readonly property int searchSuggestionsMax: 4
    // Páginas del historial que se revisan para encontrar búsquedas
    readonly property int searchHistoryScan: 300

    function updateSuggestions() {
        suggestionIndex = -1
        const typed = search.text.trim()
        if (!search.activeFocus || (typed === "" && privateMode)) {
            suggestions = []
            return
        }
        const key = fold(typed)
        const list = []
        const seenQueries = {}
        const searchesMax = typed === "" ? suggestionsMax : searchSuggestionsMax
        for (const row of History.recent(searchHistoryScan)) {
            if (list.length >= searchesMax)
                break
            const query = SearchEngines.queryOf(String(row.url))
            const folded = fold(query)
            if (query === "" || seenQueries[folded] || folded === key || !folded.includes(key))
                continue
            seenQueries[folded] = true
            list.push({ query: query, url: "", title: "", bookmark: false })
        }
        if (typed !== "") {
            const seenUrls = {}
            const take = (items, bookmark) => {
                for (const item of items) {
                    if (list.length >= suggestionsMax)
                        return
                    // Las páginas de resultados ya salen como búsquedas
                    if (seenUrls[item.url] || SearchEngines.queryOf(item.url) !== "")
                        continue
                    seenUrls[item.url] = true
                    list.push({ query: "", url: item.url, title: item.title, bookmark: bookmark })
                }
            }
            take(Bookmarks.search(typed, 3), true)
            take(History.suggest(typed, suggestionsMax), false)
        }
        suggestions = list
    }

    // Sin acentos ni mayúsculas, como las sugerencias de la dirección
    function fold(value) {
        return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase()
    }

    function moveSuggestion(step) {
        if (suggestions.length === 0)
            return
        suggestionIndex = Math.max(-1, Math.min(suggestions.length - 1, suggestionIndex + step))
    }

    // Una búsqueda se repite en el buscador elegido; una página se abre
    function openSuggestion(item) {
        search.text = ""
        root.navigate(item.query !== "" ? SearchEngines.searchUrl(item.query) : item.url)
    }

    readonly property var defaultLinks: [
        { name: "YouTube", url: "https://www.youtube.com/" },
        { name: "Wikipedia", url: "https://es.wikipedia.org/" },
        { name: "GitHub", url: "https://github.com/" },
        { name: "Gmail", url: "https://mail.google.com/" }
    ]

    ListModel {
        id: links
    }

    function saveLinks() {
        const list = []
        for (let i = 0; i < links.count; i++)
            list.push({ name: links.get(i).name, url: links.get(i).url })
        Settings.quickLinks = JSON.stringify(list)
    }

    Component.onCompleted: {
        let list = root.defaultLinks
        try {
            if (Settings.quickLinks !== "")
                list = JSON.parse(Settings.quickLinks)
        } catch (error) {
            console.warn("[Mitis] Accesos rápidos dañados; se usan los de serie")
        }
        list.forEach(link => links.append({ name: link.name, url: link.url }))
    }

    onVisibleChanged: if (visible) News.refreshIfStale()

    // ── Fondo ────────────────────────────────────────────────────────
    // Lo que difumina el vidrio de las tarjetas y el buscador
    GlassBackdrop {
        anchors.fill: parent

        // Del tema
        ThemeBackground {
            anchors.fill: parent
        }

        // Imagen propia, decodificada al tamaño de la pantalla (no al de la foto)
        Image {
            id: wallpaper
            anchors.fill: parent
            source: root.privateMode ? "" : Settings.newTabBackground
            sourceSize: Qt.size(Screen.width, Screen.height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
        Rectangle {
            anchors.fill: parent
            visible: wallpaper.visible
            color: Colors.backgroundScrim
        }
    }

    FileDialog {
        id: picker
        title: "Elegir imagen de fondo"
        nameFilters: ["Imágenes (*.png *.jpg *.jpeg *.webp *.bmp)"]
        currentFolder: Core.StandardPaths.standardLocations(Core.StandardPaths.PicturesLocation)[0]
        onAccepted: Settings.newTabBackground = selectedFile.toString()
    }

    // ── Contenido ────────────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        contentHeight: column.y + column.height + Theme.ntpSectionSpacing * 2
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column
            width: Math.min(root.width - 4 * Theme.margin, Theme.ntpMaxWidth)
            x: (root.width - width) / 2
            y: Math.max(Theme.ntpSectionSpacing * 2, root.height * 0.22 - logo.height - Theme.ntpLogoSpacing)
            spacing: Theme.ntpSectionSpacing

            // Logo completo de Mitis (el de temas oscuros o claros) y buscador
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                spacing: Theme.ntpLogoSpacing

                Image {
                    id: logo
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Theme.ntpLogoWidth
                    height: width * implicitHeight / Math.max(1, implicitWidth)
                    source: Colors.dark ? "qrc:/branding/mitis-logo-dark.png" : "qrc:/branding/mitis-logo-light.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }

                TextField {
                    id: search
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, Theme.ntpSearchWidth)
                    height: Theme.ntpSearchHeight
                    leftPadding: Theme.margin * 2 + Theme.iconSize
                    rightPadding: Theme.margin * 2
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.ink
                    placeholderText: "Buscar en " + SearchEngines.name + " o escribir una dirección"
                    placeholderTextColor: Colors.inkMuted
                    selectionColor: Colors.selection
                    selectedTextColor: Colors.ink
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Theme.fontWeightInput
                    selectByMouse: true

                    // Mismo degradado que el campo de dirección y los controles
                    background: Surface {
                        radius: height / 2
                        fillStart: Colors.controlsStart
                        fillEnd: Colors.controlsEnd
                        // Sin borde ni anillo de foco: el icono de búsqueda
                        // en brandLight1 ya dice que tiene el foco
                        Icon {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.margin + Theme.spacing / 2
                            anchors.verticalCenter: parent.verticalCenter
                            name: "search"
                            color: search.activeFocus ? Colors.brandLight1 : Colors.inkMuted
                        }
                    }

                    HoverHandler {
                        cursorShape: Qt.IBeamCursor
                    }

                    onAccepted: {
                        if (root.suggestionIndex >= 0) {
                            root.openSuggestion(root.suggestions[root.suggestionIndex])
                            return
                        }
                        const target = SearchEngines.resolve(text)
                        if (target !== "") {
                            text = ""
                            root.navigate(target)
                        }
                    }
                    onActiveFocusChanged: root.updateSuggestions()
                    onTextEdited: root.updateSuggestions()
                    Keys.onUpPressed: root.moveSuggestion(-1)
                    Keys.onDownPressed: root.moveSuggestion(1)
                    // Con sugerencias, Esc las cierra; sin ellas, deja el campo
                    Keys.onEscapePressed: {
                        if (root.suggestions.length > 0)
                            root.suggestions = []
                        else
                            search.focus = false
                    }

                    // Bajo el campo, con su ancho. No se queda el foco: se
                    // sigue escribiendo en el campo
                    Popup {
                        id: suggestionList
                        visible: search.activeFocus && root.suggestions.length > 0
                        y: search.height + Theme.spacing
                        width: search.width
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
                                    readonly property bool isSearch: modelData.query !== ""

                                    width: suggestionList.availableWidth
                                    height: Theme.popupRowHeight

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radiusSmall
                                        color: suggestion.selected ? Colors.tintActive
                                                                   : (suggestionHover.hovered ? Colors.tintHover : "transparent")
                                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                                    }

                                    Icon {
                                        id: suggestionIcon
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.margin
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: suggestion.isSearch ? "search"
                                            : (suggestion.modelData.bookmark ? "bookmark" : "history")
                                        color: suggestion.selected ? Colors.brandLight1 : Colors.inkMuted
                                    }

                                    Text {
                                        id: suggestionTitle
                                        anchors.left: suggestionIcon.right
                                        anchors.leftMargin: Theme.spacing
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, (parent.width - x - Theme.margin)
                                                                       * (suggestion.isSearch ? 1 : 0.6))
                                        text: suggestion.isSearch ? suggestion.modelData.query
                                            : (suggestion.modelData.title || Urls.host(suggestion.modelData.url))
                                        color: Colors.ink
                                        font.pixelSize: Theme.fontSize
                                        font.weight: suggestion.selected ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: !suggestion.isSearch
                                        anchors.left: suggestionTitle.right
                                        anchors.leftMargin: Theme.spacing
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.margin
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: suggestion.modelData.url.replace(/^https?:\/\/(www\.)?/, "")
                                        color: Colors.inkMuted
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                    }

                                    HoverHandler {
                                        id: suggestionHover
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    TapHandler {
                                        gesturePolicy: TapHandler.ReleaseWithinBounds
                                        onTapped: root.openSuggestion(suggestion.modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                // Ventana privada: qué hace por ti
                Row {
                    visible: root.privateMode
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, Theme.ntpSearchWidth)
                    spacing: Theme.spacing

                    Icon {
                        id: privateIcon
                        name: "private"
                        color: Colors.brandLight1
                    }
                    Text {
                        width: parent.width - privateIcon.width - parent.spacing
                        text: "Ventana privada: al cerrarla se borra lo que hayas hecho en ella (historial, cookies, datos de los sitios). La protección contra rastreadores y el resto de opciones de privacidad están siempre activas."
                        color: Colors.inkSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            // Accesos rápidos
            Item {
                width: parent.width
                height: quickLinks.height

                Flow {
                    id: quickLinks
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width,
                                    (links.count + 1) * (Theme.tileWidth + spacing) - spacing)
                    spacing: Theme.spacing

                    Repeater {
                        model: links

                        delegate: QuickLinkTile {
                            required property int index
                            required url
                            required name
                            editable: !root.privateMode
                            onOpened: root.navigate(url)
                            onRemoveRequested: {
                                links.remove(index)
                                root.saveLinks()
                            }
                        }
                    }

                    QuickLinkTile {
                        visible: links.count < Theme.quickLinksMax && !root.privateMode
                        adder: true
                        onOpened: editor.openEmpty()
                    }
                }
            }

            // Noticias
            Column {
                width: parent.width
                spacing: Theme.margin

                Item {
                    width: parent.width
                    height: Theme.buttonSizeSmall

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "news"
                            color: Colors.brandLight1
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Tecnología"
                            color: Colors.ink
                            font.pixelSize: Theme.fontSizeTitle
                            font.weight: Font.DemiBold
                        }
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.buttonSizeSmall
                        height: Theme.buttonSizeSmall
                        flat: true
                        icon: "reload"
                        iconSize: Theme.iconSizeSmall
                        tooltip: "Actualizar noticias"
                        enabled: !News.loading
                        onClicked: News.refresh()
                    }
                }

                Text {
                    visible: News.items.count === 0
                    text: News.loading ? "Cargando noticias…"
                                       : (News.failed ? "No se pudieron cargar las noticias." : "")
                    color: Colors.inkMuted
                    font.pixelSize: Theme.fontSize
                }

                Grid {
                    id: news
                    width: parent.width
                    columns: width >= Theme.ntpNewsTwoColumnsWidth ? 2 : 1
                    spacing: Theme.spacing

                    Repeater {
                        model: News.items

                        delegate: NewsCard {
                            required title
                            required source
                            required property string link
                            required property real published
                            width: (news.width - (news.columns - 1) * news.spacing) / news.columns
                            age: News.age(published)
                            onOpened: root.navigate(link)
                        }
                    }
                }
            }
        }
    }

    // Botones de fondo, arriba a la derecha (no en las ventanas privadas)
    Row {
        visible: !root.privateMode
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.margin
        spacing: Theme.spacing

        IconButton {
            visible: Settings.newTabBackground !== ""
            icon: "background-reset"
            tooltip: "Quitar fondo"
            tooltipBelow: true
            onClicked: Settings.newTabBackground = ""
        }
        IconButton {
            icon: "background"
            tooltip: "Cambiar fondo"
            tooltipBelow: true
            onClicked: picker.open()
        }
    }

    QuickLinkEditor {
        id: editor
        parent: root
        onAdded: (name, url) => {
            links.append({ name: name, url: url })
            root.saveLinks()
        }
    }
}

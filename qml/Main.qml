pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtWebEngine

// Ventana principal de Mitis. Sin marco del sistema: la barra de título,
// los botones y el redimensionado son propios.
Window {
    id: win
    // Tamaño inicial ajustado a la pantalla, para que la barra inferior
    // nunca quede fuera en pantallas pequeñas
    width: Math.min(1280, Screen.desktopAvailableWidth)
    height: Math.min(800, Screen.desktopAvailableHeight)
    x: (Screen.desktopAvailableWidth - width) / 2
    y: (Screen.desktopAvailableHeight - height) / 2
    minimumWidth: 640
    minimumHeight: 360
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: Theme.bgBase
    title: currentView && currentView.title ? currentView.title + " — Mitis" : "Mitis"


    property int currentIndex: 0
    property WebEngineView currentView: null

    // Pestañas cerradas, la última al final: { url, title }
    property var closedTabs: []
    readonly property int closedTabsLimit: 20

    // `position` es opcional: sin ella, la pestaña va al final
    function newTab(target, activate, position) {
        // Una pestaña nueva nunca entra en el grupo de fijadas
        const at = Math.max(position === undefined ? tabs.count : position, pinnedCount)
        tabs.insert(at, { initialUrl: target ? target.toString() : "", url: "", title: "", icon: "",
                          audible: false, muted: false, pinned: false })
        if (activate !== false)
            currentIndex = at
        else if (at <= currentIndex)
            currentIndex++     // la activa se ha desplazado una posición
        return views.itemAt(at)
    }

    // Enlaces abiertos desde una pestaña: van a su derecha y, si se abren
    // varios seguidos, cada uno tras el anterior (como Chrome). La serie se
    // reinicia al cambiar de pestaña activa o de pestaña de origen.
    property WebEngineView linkOpener: null
    property WebEngineView linkLast: null
    property WebEngineView linkActive: null

    function linkTabPosition(opener, openerIndex) {
        if (opener === linkOpener && currentView === linkActive && linkLast !== null) {
            for (let i = 0; i < tabs.count; i++) {
                if (views.itemAt(i) === linkLast)
                    return i + 1
            }
        }
        return openerIndex + 1
    }

    // Las fijadas no se cierran (ni con Ctrl+W ni desde la página): hay que desfijarlas antes
    function closeTab(index) {
        if (tabs.get(index).pinned)
            return
        if (tabs.count <= 1) {
            win.close()
            return
        }
        const closing = tabs.get(index)
        if (closing.url !== "")
            closedTabs = closedTabs.concat([{ url: closing.url, title: closing.title }])
                                   .slice(-closedTabsLimit)

        // Mantiene seleccionada la misma pestaña si se cierra una anterior
        if (index < currentIndex || (index === currentIndex && index === tabs.count - 1))
            currentIndex--
        tabs.remove(index)
    }

    // Reabre la última pestaña cerrada (solo su dirección: el historial de
    // atrás/adelante de esa pestaña no se conserva)
    function reopenClosedTab() {
        if (closedTabs.length === 0)
            return
        const last = closedTabs[closedTabs.length - 1]
        closedTabs = closedTabs.slice(0, -1)
        newTab(last.url)
    }

    // Pestaña vacía: muestra la página de nueva pestaña con el foco en su buscador
    function openNewTabPage() {
        newTab("")
        Qt.callLater(newTabPage.focusSearch)
    }

    // Una pestaña sin dirección muestra la página de nueva pestaña
    readonly property bool showingNewTabPage: currentView !== null && currentView.url.toString() === ""

    function selectTab(index) {
        currentIndex = (index + tabs.count) % tabs.count
    }

    // Las fijadas son siempre las primeras `pinnedCount` filas del modelo,
    // en el orden en que se fijaron. Solo lo cambia setTabPinned().
    property int pinnedCount: 0

    // Mueve una pestaña sin recrear su página (el Repeater reordena las vistas)
    // y mantiene seleccionada la misma. `to` se limita al grupo de la pestaña:
    // una fijada no sale de las fijadas ni una normal entra en ellas.
    // Devuelve la posición final.
    function moveTab(from, to) {
        const pinned = tabs.get(from).pinned
        const first = pinned ? 0 : pinnedCount
        const last = pinned ? pinnedCount - 1 : tabs.count - 1
        to = Math.max(first, Math.min(to, last))
        if (to === from)
            return to

        let current = currentIndex
        if (current === from)
            current = to
        else if (from < current && to >= current)
            current--
        else if (from > current && to <= current)
            current++
        tabs.move(from, to, 1)
        currentIndex = current
        return to
    }

    // Fijar: al final del grupo de fijadas. Desfijar: al principio de las demás.
    function setTabPinned(index, pinned) {
        if (tabs.get(index).pinned === pinned)
            return
        const to = moveTab(index, pinned ? pinnedCount : pinnedCount - 1)
        tabs.setProperty(to, "pinned", pinned)
        pinnedCount += pinned ? 1 : -1
    }

    // Perfil persistente: cookies, sesiones y caché sobreviven al cierre
    WebEngineProfile {
        id: profile
        storageName: "Mitis"
        offTheRecord: false
        httpCacheType: WebEngineProfile.DiskHttpCache
        persistentCookiesPolicy: WebEngineProfile.AllowPersistentCookies
    }

    // ── Multimedia ───────────────────────────────────────────────────
    // La última pestaña que sonó y lo que reproduce, según el script
    // assets/scripts/media.js inyectado en cada página. `media` es null si
    // no hay nada: entonces el mini reproductor se oculta.
    property WebEngineView mediaView: null
    property var media: null

    function pollMedia() {
        const view = mediaView
        if (!view)
            return
        view.runJavaScript("window.__mitisMedia ? window.__mitisMedia.state() : null", result => {
            if (view !== win.mediaView)
                return
            win.media = result ?? null
            // La página ya no tiene nada que reproducir
            if (!result)
                win.mediaView = null
        })
    }

    function mediaControl(action) {
        const view = mediaView
        if (!view)
            return
        view.runJavaScript("window.__mitisMedia ? window.__mitisMedia.control('" + action + "') : null",
                           result => {
            if (view === win.mediaView && result)
                win.media = result
        })
    }

    function selectView(view) {
        for (let i = 0; i < tabs.count; i++) {
            if (views.itemAt(i) === view)
                selectTab(i)
        }
    }

    onMediaViewChanged: if (!mediaView) media = null

    // Pregunta a la página solo mientras hay algo que mostrar
    Timer {
        interval: 1000
        repeat: true
        running: win.mediaView !== null
        onTriggered: win.pollMedia()
    }

    // Roles: initialUrl (solo al crear), url, title, icon, audible, muted, pinned
    ListModel {
        id: tabs
    }

    TitleBar {
        id: titleBar
        window: win
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
    }

    // Flota sobre la página: se dibuja encima de ella
    BottomBar {
        id: bottomBar
        z: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        currentUrl: win.currentView ? win.currentView.url : ""
        pageTitle: win.showingNewTabPage ? "Nueva pestaña"
                                         : (win.currentView ? win.currentView.title : "")
        canGoBack: win.currentView ? win.currentView.canGoBack : false
        canGoForward: win.currentView ? win.currentView.canGoForward : false
        loading: win.currentView ? win.currentView.loading : false
        loadProgress: win.currentView ? win.currentView.loadProgress : 0
        tabCount: tabs.count

        onBackRequested: win.currentView.goBack()
        onForwardRequested: win.currentView.goForward()
        onReloadRequested: win.currentView.reload()
        onStopRequested: win.currentView.stop()
        onNavigateRequested: target => {
            win.currentView.url = target
            win.currentView.forceActiveFocus()
        }
        onTabsRequested: tabsPopup.opened ? tabsPopup.close() : tabsPopup.open()
        onBookmarksRequested: bookmarksPopup.opened ? bookmarksPopup.close() : bookmarksPopup.open()
        onOptionsRequested: optionsPopup.opened ? optionsPopup.close() : optionsPopup.open()
    }

    Item {
        id: pages
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Repeater {
            id: views
            model: tabs

            delegate: WebEngineView {
                id: view

                required property int index
                required property string initialUrl

                readonly property bool current: index === win.currentIndex

                anchors.fill: parent
                profile: profile
                visible: current

                onCurrentChanged: if (current) win.currentView = view
                Component.onCompleted: {
                    if (initialUrl !== "")
                        url = initialUrl
                    if (current)
                        win.currentView = view
                }

                onUrlChanged: tabs.setProperty(index, "url", url.toString())
                onTitleChanged: tabs.setProperty(index, "title", title)
                onIconChanged: tabs.setProperty(index, "icon", icon.toString())
                onAudioMutedChanged: tabs.setProperty(index, "muted", view.audioMuted)
                onRecentlyAudibleChanged: {
                    tabs.setProperty(index, "audible", view.recentlyAudible)
                    if (view.recentlyAudible) {
                        win.mediaView = view
                        win.pollMedia()
                    }
                }

                // Enlaces y ventanas emergentes se abren como pestañas, a la
                // derecha de esta. Chromium decide el destino según el clic:
                //  · central o Ctrl+clic → InNewBackgroundTab: segundo plano
                //  · Ctrl+Mayús+clic, target=_blank → InNewTab: primer plano
                //  · Mayús+clic → InNewWindow; window.open → InNewDialog/InNewWindow.
                //    Mitis aún no tiene varias ventanas: de momento, pestaña en primer plano.
                onNewWindowRequested: request => {
                    const background = request.destination === WebEngineNewWindowRequest.InNewBackgroundTab
                    const target = win.newTab("", !background, win.linkTabPosition(view, index))
                    if (background) {
                        win.linkOpener = view
                        win.linkLast = target as WebEngineView
                        win.linkActive = win.currentView
                    }
                    request.openIn(target)
                }

                onWindowCloseRequested: win.closeTab(index)
            }
        }

        // Una sola página de nueva pestaña para todas: se muestra sobre la
        // pestaña activa mientras esta no tenga dirección
        NewTabPage {
            id: newTabPage
            anchors.fill: parent
            visible: win.showingNewTabPage
            onNavigate: target => {
                win.currentView.url = target
                win.currentView.forceActiveFocus()
            }
        }
    }

    TabsPopup {
        id: tabsPopup
        parent: bottomBar.tabsButton
        x: parent.width - width
        y: -height - Theme.floatingMargin
        tabs: tabs
        currentIndex: win.currentIndex
        closedCount: win.closedTabs.length
        pinnedCount: win.pinnedCount
        onTabPinToggled: index => win.setTabPinned(index, !tabs.get(index).pinned)
        onTabMoveRequested: (from, to) => win.moveTab(from, to)
        onReopenRequested: win.reopenClosedTab()
        onTabSelected: index => win.selectTab(index)
        onTabCloseRequested: index => win.closeTab(index)
        onTabMuteToggled: index => {
            const view = views.itemAt(index) as WebEngineView
            view.audioMuted = !view.audioMuted
        }
        onNewTabRequested: {
            win.openNewTabPage()
        }
    }

    // Marcadores: llegan en la Fase 4; por ahora solo se anuncian
    OptionsPopup {
        id: bookmarksPopup
        parent: bottomBar.bookmarksButton
        x: parent.width - width
        y: -height - Theme.floatingMargin
        options: [
            { key: "bookmark-add", label: "Añadir esta página", icon: "bookmark-add", available: false },
            { key: "bookmarks", label: "Ver marcadores", icon: "bookmark", available: false }
        ]
    }

    OptionsPopup {
        id: optionsPopup
        parent: bottomBar.optionsButton
        x: parent.width - width
        y: -height - Theme.floatingMargin
    }

    MiniPlayer {
        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        // Pegado a la barra inferior, a la misma distancia que sus controles
        anchors.bottom: bottomBar.top
        anchors.bottomMargin: Theme.spacing - Theme.floatingMargin
        visible: opacity > 0
        opacity: win.media ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

        iconSource: win.mediaView ? win.mediaView.icon : ""
        title: win.media ? (win.media.artist ? win.media.title + " · " + win.media.artist
                                             : win.media.title) : ""
        playing: win.media ? win.media.playing : false
        hasNext: win.media ? win.media.hasNext : false
        hasPrevious: win.media ? win.media.hasPrevious : false
        onToggleRequested: win.mediaControl("toggle")
        onNextRequested: win.mediaControl("next")
        onPreviousRequested: win.mediaControl("previous")
        onActivated: win.selectView(win.mediaView)
    }

    ResizeHandles {
        window: win
    }

    // Atajos de teclado
    Shortcut {
        sequence: "Ctrl+T"
        context: Qt.ApplicationShortcut
        onActivated: {
            win.openNewTabPage()
        }
    }
    Shortcut {
        sequence: "Ctrl+Shift+T"
        context: Qt.ApplicationShortcut
        onActivated: win.reopenClosedTab()
    }
    Shortcut {
        sequence: "Ctrl+W"
        context: Qt.ApplicationShortcut
        onActivated: win.closeTab(win.currentIndex)
    }
    Shortcut {
        sequence: "Ctrl+L"
        context: Qt.ApplicationShortcut
        onActivated: bottomBar.focusAddress()
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        context: Qt.ApplicationShortcut
        onActivated: win.selectTab(win.currentIndex + 1)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab"]
        context: Qt.ApplicationShortcut
        onActivated: win.selectTab(win.currentIndex - 1)
    }
    Shortcut {
        sequence: "Ctrl+Shift+A"
        context: Qt.ApplicationShortcut
        onActivated: tabsPopup.opened ? tabsPopup.close() : tabsPopup.open()
    }
    Shortcut {
        sequences: ["Ctrl+R", "F5"]
        context: Qt.ApplicationShortcut
        onActivated: win.currentView.reload()
    }
    Shortcut {
        sequence: "Alt+Left"
        context: Qt.ApplicationShortcut
        onActivated: win.currentView.goBack()
    }
    Shortcut {
        sequence: "Alt+Right"
        context: Qt.ApplicationShortcut
        onActivated: win.currentView.goForward()
    }

    Component.onCompleted: {
        // Mitis se presenta como un Chrome normal: el User-Agent de serie incluye
        // "QtWebEngine/x.y.z", que algunos sitios (WhatsApp Web) no reconocen y
        // rechazan. Se conserva la versión real de Chromium.
        profile.httpUserAgent = profile.httpUserAgent.replace(/ QtWebEngine\/\S+/, "")

        // Puente con el contenido multimedia, en todas las páginas
        const script = WebEngine.script()
        script.name = "mitis-media"
        script.sourceUrl = "qrc:/scripts/media.js"
        script.injectionPoint = WebEngineScript.DocumentCreation
        script.worldId = WebEngineScript.MainWorld
        profile.userScripts.insert(script)

        openNewTabPage()
    }
}

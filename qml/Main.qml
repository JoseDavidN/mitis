pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window

import "urls.js" as Urls

// Ventana principal de Mitis. Sin marco del sistema: la barra de título,
// los botones y el redimensionado son propios. No conoce el motor web: cada
// pestaña es un BrowserTab (ver BrowserTab.qml).
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

    // Las herramientas de desarrollo se cierran antes: si siguieran abiertas,
    // la aplicación no se daría por cerrada y quedaría sin ventanas
    onClosing: {
        for (let i = 0; i < views.count; i++)
            closeDevTools(views.itemAt(i))
    }


    property int currentIndex: 0
    property BrowserTab currentView: null

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
        return views.itemAt(at) as BrowserTab
    }

    // Enlaces abiertos desde una pestaña: van a su derecha y, si se abren
    // varios seguidos, cada uno tras el anterior (como Chrome). La serie se
    // reinicia al cambiar de pestaña activa o de pestaña de origen.
    property BrowserTab linkOpener: null
    property BrowserTab linkLast: null
    property BrowserTab linkActive: null

    function linkTabPosition(opener, openerIndex) {
        if (opener === linkOpener && currentView === linkActive && linkLast !== null) {
            for (let i = 0; i < tabs.count; i++) {
                if (views.itemAt(i) === linkLast)
                    return i + 1
            }
        }
        return openerIndex + 1
    }

    // Abre `target` en una pestaña nueva a la derecha de `opener`; en segundo
    // plano continúa la serie de enlaces. Devuelve la pestaña nueva.
    function openFromTab(opener, openerIndex, target, background) {
        const created = newTab(target, !background, linkTabPosition(opener, openerIndex))
        if (background) {
            linkOpener = opener
            linkLast = created
            linkActive = currentView
        }
        return created
    }

    // ── Menú contextual ──────────────────────────────────────────────
    // Pestaña en la que se abrió el menú (las acciones van a ella)
    property BrowserTab contextTab: null

    // Sitios a los que ya se explicó que falta Widevine (host → true)
    property var protectedContentNoticed: ({})

    function openContextMenu(tab, info) {
        contextTab = tab
        const point = tab.mapToItem(win.contentItem, info.x, info.y)
        const menuInfo = Object.assign({}, info, { canGoBack: tab.canGoBack, canGoForward: tab.canGoForward })
        contextMenu.show(menuInfo, point.x, point.y)
    }

    function contextAction(action) {
        const tab = contextTab
        if (!tab)
            return
        let index = -1
        for (let i = 0; i < tabs.count; i++) {
            if (views.itemAt(i) === tab)
                index = i
        }
        if (index < 0)
            return    // la pestaña se cerró con el menú abierto
        const info = contextMenu.info
        switch (action) {
        case "openLinkBackground":
            openFromTab(tab, index, info.linkUrl, true)
            break
        case "openLink":
            openFromTab(tab, index, info.linkUrl, false)
            break
        case "openImage":
            openFromTab(tab, index, info.mediaUrl, true)
            break
        case "inspect":
            // El motor necesita el panel abierto para señalar el elemento
            openDevTools(tab)
            tab.runAction("inspect")
            break
        case "search":
            newTab(SearchEngines.searchUrl(info.selectedText.trim()), true, index + 1)
            break
        default:
            // Cortar, pegar… actúan sobre el elemento con foco de la página
            tab.focusPage()
            tab.runAction(action)
        }
    }

    // ── Herramientas de desarrollo (F12) ─────────────────────────────
    // Una ventana por pestaña; se crea al abrirla y se destruye al cerrarla,
    // con lo que el motor libera el panel
    Component {
        id: devToolsComponent
        DevToolsWindow {}
    }
    function openDevTools(tab) {
        if (tab.devToolsWindow) {
            tab.devToolsWindow.raise()
            tab.devToolsWindow.requestActivate()
            return
        }
        const devtools = devToolsComponent.createObject(win, {
            pageTitle: Qt.binding(() => tab.title),
            // Al lado de la ventana principal, sin salirse de la pantalla
            x: Math.min(win.x + win.width / 2, Screen.desktopAvailableWidth - Theme.devtoolsWidth),
            y: win.y + Theme.titleBarHeight
        }) as DevToolsWindow
        tab.devToolsWindow = devtools
        devtools.dismissed.connect(() => win.closeDevTools(tab))
        tab.openDevTools(devtools.container)
        devtools.show()
    }
    function closeDevTools(tab) {
        const devtools = tab.devToolsWindow
        if (!devtools)
            return
        tab.devToolsWindow = null
        tab.closeDevTools()
        devtools.destroy()
    }
    function toggleDevTools(tab) {
        if (tab.devToolsWindow)
            closeDevTools(tab)
        else
            openDevTools(tab)
    }

    // Las fijadas no se cierran (ni con Ctrl+W ni desde la página): hay que desfijarlas antes
    function closeTab(index) {
        if (tabs.get(index).pinned)
            return
        if (tabs.count <= 1) {
            win.close()
            return
        }
        if (views.itemAt(index) === fullScreenTab)
            exitPageFullScreen()
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

    // ── Buscar en la página ──────────────────────────────────────────
    // Pestaña en la que se está buscando (la barra se cierra al cambiar de pestaña)
    property BrowserTab findTab: null

    function openFind() {
        if (showingNewTabPage || pageFullScreen)
            return
        findTab = currentView
        findBar.openAndFocus()
    }

    onCurrentViewChanged: findBar.close()

    // ── Zoom ─────────────────────────────────────────────────────────
    // Los mismos pasos que Chrome
    readonly property var zoomSteps: [0.25, 0.33, 0.5, 0.67, 0.75, 0.8, 0.9, 1,
                                      1.1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5]

    // `direction`: 1 acerca, -1 aleja, 0 vuelve al 100 %
    function zoomBy(direction) {
        if (!currentView || showingNewTabPage)
            return
        const level = currentView.zoom
        let next = 1
        if (direction > 0)
            next = zoomSteps.find(step => step > level + 0.001) ?? zoomSteps[zoomSteps.length - 1]
        else if (direction < 0)
            next = zoomSteps.slice().reverse().find(step => step < level - 0.001) ?? zoomSteps[0]
        currentView.setZoom(next)
        zoomIndicator.flash()
    }

    // Cualquier cambio de zoom de la pestaña activa (también Ctrl+rueda) muestra
    // el indicador; cambiar de pestaña no
    Connections {
        target: win.currentView
        function onZoomChanged() { zoomIndicator.flash() }
    }

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

    // ── Pantalla completa ────────────────────────────────────────────
    // Dos modos independientes: la de página (un vídeo la pide; la página
    // ocupa toda la ventana y no hay controles) y la de ventana (F11; los
    // controles inferiores aparecen al llevar el ratón al borde inferior).
    // Con cualquiera de las dos la ventana pasa a pantalla completa y, al
    // salir de ambas, vuelve a como estaba (normal o maximizada).
    property BrowserTab fullScreenTab: null
    property bool windowFullScreen: false
    readonly property bool pageFullScreen: fullScreenTab !== null
    readonly property bool immersive: pageFullScreen || windowFullScreen
    property int visibilityBeforeFullScreen: Window.Windowed

    // Controles inferiores visibles. En F11 solo mientras el ratón está en
    // el borde inferior o sobre ellos, se escribe en la dirección o hay una
    // lista suya abierta. `revealControls` los fuerza (p. ej. Ctrl+L).
    property bool revealControls: false
    readonly property bool controlsShown: !immersive
        || (!pageFullScreen && (revealControls || revealHover.hovered || barHover.hovered
                                || playerHover.hovered || bottomBar.editing
                                || tabsPopup.opened || bookmarksPopup.opened || optionsPopup.opened
                                || downloadsPopup.opened || downloadPanel.opened))

    onImmersiveChanged: {
        if (immersive) {
            if (visibility !== Window.FullScreen) {
                visibilityBeforeFullScreen = visibility === Window.Maximized ? Window.Maximized
                                                                              : Window.Windowed
                showFullScreen()
            }
        } else {
            fullscreenHint.hide()
            if (visibility === Window.FullScreen) {
                if (visibilityBeforeFullScreen === Window.Maximized)
                    showMaximized()
                else
                    showNormal()
            }
        }
    }

    // Una pestaña entra o sale de pantalla completa (ya aceptado por ella)
    function setPageFullScreen(tab, on) {
        if (!on) {
            if (tab === fullScreenTab) {
                fullScreenTab = null
                // Vuelve a F11: el aviso de Esc ya no vale
                fullscreenHint.hide()
            }
            return
        }
        // Una pestaña en segundo plano no se queda con la ventana
        if (tab !== currentView) {
            tab.exitFullScreen()
            return
        }
        // La página tapa toda la interfaz: nada queda abierto encima
        findBar.close()
        tabsPopup.close()
        bookmarksPopup.close()
        optionsPopup.close()
        downloadsPopup.close()
        downloadPanel.close()
        contextMenu.close()
        searchEngineDialog.close()
        fullScreenTab = tab
        fullscreenHint.show("Pulsa Esc para salir de la pantalla completa")
    }

    function exitPageFullScreen() {
        const tab = fullScreenTab
        fullScreenTab = null
        if (tab)
            tab.exitFullScreen()
    }

    // F11. Durante la de página, sale de toda pantalla completa.
    function toggleWindowFullScreen() {
        if (pageFullScreen) {
            windowFullScreen = false
            exitPageFullScreen()
            return
        }
        windowFullScreen = !windowFullScreen
        if (windowFullScreen)
            fullscreenHint.show("Pulsa F11 para salir de la pantalla completa")
    }

    // Cambiar de pestaña saca de la pantalla completa de página
    Connections {
        target: win
        function onCurrentViewChanged() {
            if (win.fullScreenTab && win.fullScreenTab !== win.currentView)
                win.exitPageFullScreen()
        }
    }

    // ── Multimedia ───────────────────────────────────────────────────
    // La última pestaña que sonó y lo que reproduce, según el script
    // assets/scripts/media.js inyectado en cada página. `media` es null si
    // no hay nada: entonces el mini reproductor se oculta.
    property BrowserTab mediaView: null
    property var media: null

    function pollMedia() {
        const tab = mediaView
        if (!tab)
            return
        tab.mediaState(state => {
            if (tab !== win.mediaView)
                return
            win.media = state
            // La página ya no tiene nada que reproducir
            if (!state)
                win.mediaView = null
        })
    }

    function mediaControl(action) {
        const tab = mediaView
        if (!tab)
            return
        tab.mediaControl(action, state => {
            if (tab === win.mediaView && state)
                win.media = state
        })
    }

    function selectView(tab) {
        for (let i = 0; i < tabs.count; i++) {
            if (views.itemAt(i) === tab)
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
        // En pantalla completa desaparece y la página (y lo anclado a la
        // barra, como la búsqueda) sube hasta el borde superior
        height: win.immersive ? 0 : implicitHeight
        visible: !win.immersive
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
        downloadsShown: downloadPanel.active
        download: downloadPanel.item
        downloadPanelOpen: downloadPanel.visible

        // Pantalla completa: se oculta con fundido y bajando un poco
        visible: win.controlsShown || opacity > 0
        opacity: win.controlsShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
        transform: Translate {
            y: win.controlsShown ? 0 : Theme.spacing
            Behavior on y {
                NumberAnimation { duration: Theme.durationBase; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            }
        }
        HoverHandler { id: barHover }

        onBackRequested: win.currentView.goBack()
        onForwardRequested: win.currentView.goForward()
        onReloadRequested: win.currentView.reload()
        onStopRequested: win.currentView.stop()
        onNavigateRequested: target => {
            win.currentView.navigate(target)
            win.currentView.focusPage()
        }
        onDownloadsRequested: downloadPanel.opened ? downloadPanel.close() : downloadPanel.show()
        onTabsRequested: tabsPopup.opened ? tabsPopup.close() : tabsPopup.open()
        onBookmarksRequested: bookmarksPopup.opened ? bookmarksPopup.close() : bookmarksPopup.open()
        // Con el listado de descargas abierto, el botón de opciones lo cierra
        onOptionsRequested: downloadsPopup.opened ? downloadsPopup.close()
                          : optionsPopup.opened ? optionsPopup.close() : optionsPopup.open()
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

            delegate: BrowserTab {
                id: tab

                required property int index
                required initialUrl

                readonly property bool current: index === win.currentIndex

                anchors.fill: parent
                visible: current

                onCurrentChanged: if (current) win.currentView = tab
                Component.onCompleted: if (current) win.currentView = tab

                onUrlChanged: tabs.setProperty(index, "url", url.toString())
                onTitleChanged: tabs.setProperty(index, "title", title)
                onIconChanged: tabs.setProperty(index, "icon", icon.toString())
                onMutedChanged: tabs.setProperty(index, "muted", tab.muted)
                onAudibleChanged: {
                    tabs.setProperty(index, "audible", tab.audible)
                    if (tab.audible) {
                        win.mediaView = tab
                        win.pollMedia()
                    }
                }

                // Enlaces y ventanas emergentes se abren como pestañas, a la
                // derecha de esta (en serie si se abren varios seguidos)
                onNewTabRequested: (background, request) => {
                    win.openFromTab(tab, index, "", background).adopt(request)
                }

                onCloseRequested: win.closeTab(index)
                onPageFullScreenRequested: on => win.setPageFullScreen(tab, on)
                onContextMenuRequested: info => win.openContextMenu(tab, info)

                // Cámara, micrófono, ubicación…: se pregunta sobre la página
                onPermissionRequested: permission => permissionDialog.ask(permission)

                PermissionDialog {
                    id: permissionDialog
                    pageUrl: tab.url
                    onFinished: tab.focusPage()
                }

                // Certificado inválido: aviso propio sobre la página
                onCertificateErrorRequested: error => certificateDialog.ask(error)
                onCertificateErrorPendingChanged: if (!certificateErrorPending) certificateDialog.dismiss()

                CertificateDialog {
                    id: certificateDialog
                    onBackRequested: tab.focusPage()
                    onProceeded: tab.focusPage()
                }

                // alert, confirm, prompt y aviso de salir de la página
                onJavaScriptDialogRequested: dialog => jsDialog.enqueue(dialog)
                onJavaScriptDialogCancelled: dialog => jsDialog.cancel(dialog)
                onFileDialogRequested: dialog => filePicker.ask(tab, dialog)
                Component.onDestruction: {
                    filePicker.dismiss(tab)
                    win.closeDevTools(tab)
                }

                // Contenido protegido sin Widevine: se explica una vez por sitio y sesión
                onProtectedContentUnavailable: {
                    const host = Urls.host(tab.url.toString())
                    if (win.protectedContentNoticed[host])
                        return
                    win.protectedContentNoticed = Object.assign({}, win.protectedContentNoticed, { [host]: true })
                    protectedContentNotice.ask(host)
                }

                ProtectedContentNotice {
                    id: protectedContentNotice
                    onClosed: if (tab.current) tab.focusPage()
                }

                // Herramientas de desarrollo de esta pestaña (F12), si están abiertas
                property DevToolsWindow devToolsWindow: null

                JsDialog {
                    id: jsDialog
                    onClosed: if (tab.current) tab.focusPage()
                }
            }
        }

        // Una sola página de nueva pestaña para todas: se muestra sobre la
        // pestaña activa mientras esta no tenga dirección
        NewTabPage {
            id: newTabPage
            anchors.fill: parent
            visible: win.showingNewTabPage
            onNavigate: target => {
                win.currentView.navigate(target)
                win.currentView.focusPage()
            }
        }
    }

    // Selector de archivos de las páginas (<input type=file>), uno para todas
    FilePicker {
        id: filePicker
    }

    // Descarga actual: se abre sola al empezar y al terminar una descarga
    DownloadPanel {
        id: downloadPanel
        parent: bottomBar.downloadsButton
        x: parent.width - width
        y: -height - Theme.floatingMargin
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
            const tab = views.itemAt(index) as BrowserTab
            tab.muted = !tab.muted
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
        onOptionSelected: key => {
            if (key === "downloads")
                downloadsPopup.open()
            else if (key === "search")
                searchEngineDialog.open()
        }
    }

    // Elegir el motor de búsqueda (hasta que exista la página de Configuración)
    SearchEngineDialog {
        id: searchEngineDialog
    }

    DownloadsPopup {
        id: downloadsPopup
        parent: bottomBar.optionsButton
        x: parent.width - width
        y: -height - Theme.floatingMargin
    }

    // Clic derecho en la página: se coloca en openContextMenu()
    ContextMenu {
        id: contextMenu
        onActionSelected: action => win.contextAction(action)
        // El teclado vuelve a la página al cerrar (salvo si ya se reabrió)
        onClosed: {
            if (!contextMenu.visible && win.contextTab && win.contextTab === win.currentView)
                win.contextTab.focusPage()
        }
    }

    FindBar {
        id: findBar
        z: 1
        anchors.top: titleBar.bottom
        anchors.topMargin: Theme.floatingMargin
        anchors.horizontalCenter: parent.horizontalCenter

        matches: win.findTab ? win.findTab.findMatches : 0
        active: win.findTab ? win.findTab.findActive : 0
        onSearchRequested: (text, backward) => {
            if (win.findTab)
                win.findTab.find(text, backward)
        }
        onClosed: {
            if (win.findTab) {
                win.findTab.stopFind()
                // Al cerrar con Esc o con la ✕, el teclado vuelve a la página
                if (win.findTab === win.currentView)
                    win.findTab.focusPage()
            }
            win.findTab = null
        }
    }

    ZoomIndicator {
        id: zoomIndicator
        z: 1
        anchors.top: titleBar.bottom
        anchors.topMargin: Theme.floatingMargin
        anchors.right: parent.right
        anchors.rightMargin: Theme.margin
        visible: opacity > 0 && !win.pageFullScreen
        zoom: win.currentView ? win.currentView.zoom : 1
        onZoomInRequested: win.zoomBy(1)
        onZoomOutRequested: win.zoomBy(-1)
        onResetRequested: win.zoomBy(0)
    }

    MiniPlayer {
        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        // Pegado a la barra inferior, a la misma distancia que sus controles
        anchors.bottom: bottomBar.top
        anchors.bottomMargin: Theme.spacing - Theme.floatingMargin
        visible: opacity > 0
        // Va con los controles inferiores: en pantalla completa se oculta con ellos
        opacity: win.media && win.controlsShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
        HoverHandler { id: playerHover }

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

    // F11: franja fina del borde inferior que muestra los controles. No
    // bloquea el ratón: la página sigue recibiendo el hover y los clics.
    Item {
        z: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.fullscreenRevealEdge
        visible: win.windowFullScreen && !win.pageFullScreen
        HoverHandler { id: revealHover }
    }

    FullscreenHint {
        id: fullscreenHint
        z: 2
        anchors.top: parent.top
        anchors.topMargin: Theme.floatingMargin
        anchors.horizontalCenter: parent.horizontalCenter
    }

    ResizeHandles {
        window: win
    }

    // Pantalla completa. Esc solo se atiende durante la de página (así
    // también sale con el foco fuera de ella); el resto del tiempo es de
    // la página y de las listas. F11 entra y sale de la de ventana.
    Shortcut {
        sequence: "Esc"
        context: Qt.ApplicationShortcut
        enabled: win.pageFullScreen
        onActivated: win.exitPageFullScreen()
        onActivatedAmbiguously: win.exitPageFullScreen()
    }
    Shortcut {
        sequence: "F12"
        context: Qt.ApplicationShortcut
        enabled: win.currentView !== null && !win.showingNewTabPage
        onActivated: win.toggleDevTools(win.currentView)
        onActivatedAmbiguously: win.toggleDevTools(win.currentView)
    }
    Shortcut {
        sequence: "F11"
        context: Qt.ApplicationShortcut
        onActivated: win.toggleWindowFullScreen()
        onActivatedAmbiguously: win.toggleWindowFullScreen()
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
        onActivated: {
            // En F11 la barra está oculta: se muestra antes de darle el foco
            win.revealControls = true
            bottomBar.focusAddress()
            win.revealControls = false
        }
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        context: Qt.ApplicationShortcut
        onActivated: win.selectTab(win.currentIndex + 1)
    }
    Shortcut {
        // Una sola secuencia: "Ctrl+Backtab" y similares coinciden con la misma
        // pulsación y Qt las declara ambiguas (no emite onActivated). Si otro
        // sistema la reporta ambigua igualmente, se atiende igual.
        sequence: "Ctrl+Shift+Tab"
        context: Qt.ApplicationShortcut
        onActivated: win.selectTab(win.currentIndex - 1)
        onActivatedAmbiguously: win.selectTab(win.currentIndex - 1)
    }
    Shortcut {
        sequence: "Ctrl+Shift+A"
        context: Qt.ApplicationShortcut
        onActivated: tabsPopup.opened ? tabsPopup.close() : tabsPopup.open()
    }
    Shortcut {
        sequence: "Ctrl+F"
        context: Qt.ApplicationShortcut
        onActivated: win.openFind()
    }
    Shortcut {
        sequences: ["F3", "Ctrl+G"]
        context: Qt.ApplicationShortcut
        onActivated: findBar.isOpen ? findBar.findNext() : win.openFind()
    }
    Shortcut {
        sequences: ["Shift+F3", "Ctrl+Shift+G"]
        context: Qt.ApplicationShortcut
        onActivated: findBar.isOpen ? findBar.findPrevious() : win.openFind()
    }
    // Zoom: un Shortcut por secuencia (varias equivalentes en uno solo son
    // ambiguas). "Ctrl+=" es el "+" sin Mayús de los teclados en inglés.
    Shortcut {
        sequence: "Ctrl++"
        context: Qt.ApplicationShortcut
        onActivated: win.zoomBy(1)
        onActivatedAmbiguously: win.zoomBy(1)
    }
    Shortcut {
        sequence: "Ctrl+="
        context: Qt.ApplicationShortcut
        onActivated: win.zoomBy(1)
        onActivatedAmbiguously: win.zoomBy(1)
    }
    Shortcut {
        sequence: "Ctrl+-"
        context: Qt.ApplicationShortcut
        onActivated: win.zoomBy(-1)
        onActivatedAmbiguously: win.zoomBy(-1)
    }
    Shortcut {
        sequence: "Ctrl+0"
        context: Qt.ApplicationShortcut
        onActivated: win.zoomBy(0)
        onActivatedAmbiguously: win.zoomBy(0)
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

    Component.onCompleted: openNewTabPage()
}

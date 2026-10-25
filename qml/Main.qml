pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Mitis.Core

import "urls.js" as Urls

// Ventana principal de Mitis. Sin marco del sistema: la barra de título,
// los botones y el redimensionado son propios. No conoce el motor web: cada
// pestaña es un BrowserTab (ver BrowserTab.qml).
Window {
    id: win
    // Tamaño y posición de la última vez (ver «Tamaño de la ventana») o, la
    // primera vez, el 75 % de la pantalla, centrada
    readonly property var initialGeometry: savedGeometry()
    width: initialGeometry.width
    height: initialGeometry.height
    x: initialGeometry.x
    y: initialGeometry.y
    minimumWidth: 640
    minimumHeight: 360
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: Theme.bgBase
    title: (currentView && currentView.title ? currentView.title + " — " : "")
           + (privateMode ? "Mitis (ventana privada)" : "Mitis")
           + (Qt.application.version.indexOf("beta") >= 0 ? " Beta" : "")

    // Ventana privada: perfil sin disco, sin historial ni sesión guardada
    property bool privateMode: false
    // Ventanas privadas abiertas desde esta; cada una se quita al cerrarse
    property var privateWindows: []
    // Ventana que abrió esta (solo en las privadas)
    property Window opener: null

    // Con qué dibuja la ventana: "Metal", "Direct3D 11", "OpenGL"…, o
    // "software" sin GPU; "" hasta el primer fotograma. Lo leen el vidrio
    // (Glass) y Configuración con Window.window.graphicsApi. Se pregunta a C++
    // (EngineBridge): GraphicsInfo de QML da «desconocido» demasiado tiempo
    property string graphicsApi: ""
    // Lo que difumina el vidrio de lo que no está sobre un fondo propio (las
    // listas desplegables): la Configuración, si está abierta, o las páginas
    readonly property Item glassBackdrop: settingsOpen ? settingsPage.glassBackdropItem : pages
    onFrameSwapped: {
        if (graphicsApi !== "")
            return
        // qmllint disable unqualified
        const api = typeof MitisEngine.graphicsApi === "function" ? MitisEngine.graphicsApi(win) : ""
        // qmllint enable unqualified
        if (api !== "") {
            graphicsApi = api
            console.info("[Mitis] Gráficos:", api)
        }
    }
    // Los atajos son de aplicación (así funcionan también con el foco en la
    // ventana de DevTools o sin gestor de ventanas que active ninguna), pero
    // con varias ventanas solo los atiende una: la activa o, si no hay
    // ninguna activa, la principal
    readonly property bool ownsShortcuts: active
        || (!privateMode && !privateWindows.some(window => window && window.active))
    // Se está cerrando: lo que pase con las pestañas ya no es la sesión
    property bool closingWindow: false

    // Las herramientas de desarrollo se cierran antes: si siguieran abiertas,
    // la aplicación no se daría por cerrada y quedaría sin ventanas
    onClosing: {
        for (let i = 0; i < views.count; i++)
            closeDevTools(views.itemAt(i))
        if (privateMode) {
            // Fuera la ventana y, con la última privada, su perfil
            closingWindow = true
            Qt.callLater(win.destroy)
            return
        }
        saveSession()
        rememberGeometry()
        if (Settings.clearOnExit) {
            BrowserProfile.clearCookies()
            BrowserProfile.clearCache()
        }
        closingWindow = true
        // Si queda abierta una privada, Mitis sigue: las pestañas de esta no
        // deben quedarse vivas (ni sonando) en una ventana oculta
        if (privateWindows.some(window => window && window.visible))
            tabs.clear()
    }

    // ── Tamaño de la ventana ─────────────────────────────────────────
    // Se recuerda entre sesiones (Settings, "Window/geometry"): el tamaño y la
    // posición sin maximizar y si estaba maximizada. Las privadas no guardan
    // nada: se abren como la principal la primera vez.
    function defaultGeometry() {
        const width = Math.round(Screen.width * Theme.windowDefaultRatio)
        const height = Math.round(Screen.height * Theme.windowDefaultRatio)
        return { x: Screen.virtualX + Math.round((Screen.width - width) / 2),
                 y: Screen.virtualY + Math.round((Screen.height - height) / 2),
                 width: width, height: height, maximized: false }
    }
    function savedGeometry() {
        if (privateMode)
            return defaultGeometry()
        let saved = null
        try {
            saved = JSON.parse(Settings.value("Window/geometry", "null"))
        } catch (error) {
            saved = null
        }
        if (!saved || !(saved.width > 0) || !(saved.height > 0))
            return defaultGeometry()
        // El centro debe caer en alguna pantalla: si se quitó un monitor o
        // cambió la resolución, vuelve a lo de serie
        const centerX = saved.x + saved.width / 2
        const centerY = saved.y + saved.height / 2
        const visible = Application.screens.some(screen =>
            centerX >= screen.virtualX && centerX < screen.virtualX + screen.width
            && centerY >= screen.virtualY && centerY < screen.virtualY + screen.height)
        return visible ? saved : defaultGeometry()
    }
    // Último tamaño sin maximizar (lo que se guarda aunque se cierre maximizada)
    property var normalGeometry: ({ x: initialGeometry.x, y: initialGeometry.y,
                                    width: initialGeometry.width, height: initialGeometry.height })
    function rememberGeometry() {
        if (privateMode)
            return
        if (visibility === Window.Windowed)
            normalGeometry = { x: x, y: y, width: width, height: height }
        // En pantalla completa cuenta cómo estaba antes de entrar
        const maximized = visibility === Window.Maximized
            || (visibility === Window.FullScreen && visibilityBeforeFullScreen === Window.Maximized)
        if (visibility === Window.Minimized || visibility === Window.Hidden)
            return
        Settings.setValue("Window/geometry", JSON.stringify(Object.assign({ maximized: maximized }, normalGeometry)))
    }
    Timer {
        id: geometrySaver
        interval: 1000
        onTriggered: win.rememberGeometry()
    }
    onXChanged: geometrySaver.restart()
    onYChanged: geometrySaver.restart()
    onWidthChanged: geometrySaver.restart()
    onHeightChanged: geometrySaver.restart()
    onVisibilityChanged: {
        geometrySaver.restart()
        win.applyCorners()
    }
    // Esquinas redondeadas como las del sistema (Windows 11, macOS); rectas
    // maximizada o en pantalla completa
    function applyCorners() {
        // qmllint disable unqualified
        if (typeof MitisEngine.setRoundedCorners === "function")
            MitisEngine.setRoundedCorners(win, win.visibility === Window.Windowed)
        // qmllint enable unqualified
    }

    Component.onCompleted: {
        Qt.callLater(win.applyCorners)
        // Si se cerró maximizada, se abre maximizada
        if (initialGeometry.maximized)
            Qt.callLater(win.showMaximized)
        // Enlaces con los que se abrió Mitis (navegador predeterminado): con
        // ellos no hace falta la página de inicio ni la de nueva pestaña
        const links = privateMode ? [] : Links.takePending()
        // Tras actualizarse (installUpdate), las pestañas vuelven siempre
        const afterUpdate = !privateMode && String(Settings.value("Session/restoreOnce", false)) === "true"
        if (afterUpdate)
            Settings.setValue("Session/restoreOnce", false)
        if (privateMode) {
            BrowserProfile.retainPrivate()
            openNewTabPage()
        } else if (!afterUpdate && Settings.startupMode === "page" && Settings.startupUrl !== "" && links.length === 0) {
            newTab(Settings.startupUrl)
        } else if (!((afterUpdate || Settings.startupMode === "restore") && restoreSession(links.length > 0))
                   && links.length === 0) {
            openNewTabPage()
        }
        // Primera vez tras actualizarse: las novedades, en su pestaña
        if (!privateMode)
            openReleaseNotes(Updates.takeReleaseNotes(afterUpdate))
        openLinks(links)
    }

    // ── Novedades tras actualizar ────────────────────────────────────
    // Una pestaña sin dirección con ReleaseNotesPage encima (como la de nueva
    // pestaña). No se guarda en la sesión ni en las cerradas: solo se ve
    // esta vez
    property var releaseNotes: null

    function openReleaseNotes(notes) {
        if (!notes || !notes.groups)
            return
        releaseNotes = notes
        tabs.append({ initialUrl: "", url: "", title: "Novedades de Mitis", icon: "qrc:/branding/mitis.png",
                      audible: false, muted: false, microphone: 0, camera: 0, pinned: false, lifecycle: "active",
                      deferred: false, special: "notes" })
        currentIndex = tabs.count - 1
    }

    readonly property bool showingReleaseNotes: currentView !== null && currentView.special === "notes"

    // ── Enlaces de fuera (navegador predeterminado) ──────────────────
    // Cada uno en una pestaña nueva al final, como Chrome (en la de nueva
    // pestaña si es la que se ve), y la ventana se pone delante. Solo la
    // ventana principal: una privada nunca recibe enlaces de fuera.
    function openLinks(urls) {
        if (urls.length === 0)
            return
        closeSettings()
        for (const url of urls) {
            if (currentView && showingNewTabPage)
                currentView.navigate(url)
            else
                newTab(url)
        }
    }
    Connections {
        target: Links
        enabled: !win.privateMode
        function onReceived() {
            win.openLinks(Links.takePending())
            if (win.visibility === Window.Minimized)
                win.showNormal()
            win.raise()
            win.requestActivate()
        }
    }
    // Pulsaron una notificación del sistema (src/notifier.*): al frente la
    // ventana con una pestaña de ese sitio (la activa si es de él)
    Connections {
        // qmllint disable unqualified
        target: MitisEngine
        // qmllint enable unqualified
        function onNotificationActivated(origin) {
            const prefix = origin.toString()
            const fromSite = i => {
                const url = tabs.get(i).url
                return url === prefix || url.startsWith(prefix + "/")
            }
            // Solo una página cargada manda notificaciones: primero la activa,
            // luego una cargada del sitio y, si no, cualquiera del sitio
            const loaded = i => {
                const tab = views.itemAt(i)
                return tab && !tab.deferred && tab.lifecycle !== "discarded"
            }
            let found = fromSite(win.currentIndex) ? win.currentIndex : -1
            for (let i = 0; i < tabs.count && found < 0; i++) {
                if (fromSite(i) && loaded(i))
                    found = i
            }
            for (let i = 0; i < tabs.count && found < 0; i++) {
                if (fromSite(i))
                    found = i
            }
            if (found < 0)
                return
            win.selectTab(found)
            if (win.visibility === Window.Minimized)
                win.showNormal()
            win.raise()
            win.requestActivate()
        }
    }
    Component.onDestruction: {
        if (!privateMode)
            return
        BrowserProfile.releasePrivate()
        const main = opener as Main
        if (main)
            main.privateWindows = main.privateWindows.filter(window => window !== win)
    }

    function openPrivateWindow() {
        const component = Qt.createComponent("Main.qml")
        const created = component.createObject(null, { privateMode: true, opener: win }) as Window
        if (!created) {
            console.warn("[Mitis] No se pudo abrir la ventana privada:", component.errorString())
            return
        }
        privateWindows = privateWindows.concat([created])
        created.requestActivate()
    }

    // ── Sesión ───────────────────────────────────────────────────────
    // Las pestañas (dirección, título, icono, fijada) y la activa, en
    // Settings ("Session/tabs"). Se guarda un momento después de cada cambio
    // y al cerrar. Al abrir, solo carga la activa: las demás esperan a que se
    // seleccionen (BrowserTab.deferred) y no gastan un proceso del motor.
    // Actualizar: Updates prepara la versión nueva (Windows: el instalador;
    // macOS y Linux: la descarga) y avisa con readyToRestart. Entonces Mitis
    // se cierra como al pulsar la ✕ (la sesión se guarda, y al volver se
    // restaura aunque «Al abrir Mitis» diga otra cosa), con las privadas antes;
    // lo que queda la reemplaza y lo vuelve a abrir
    function installUpdate() {
        Updates.install()
    }
    Connections {
        target: Updates
        enabled: !win.privateMode
        function onReadyToRestart() {
            Settings.setValue("Session/restoreOnce", true)
            win.quitForUpdate()
        }
    }
    function quitForUpdate() {
        for (const window of privateWindows) {
            if (window)
                window.close()
        }
        win.close()
    }

    // ── Iconos de las pestañas ───────────────────────────────────────
    // Qt WebEngine se cae si se le pide un icono (image://favicon/…) que
    // también tiene una pestaña descargada: lee la página que ya no existe.
    // Esos iconos se piden al servicio de iconos (Urls.favicon), como los
    // accesos rápidos: los de pestañas con iconRetired y los que comparten
    // con una retirada de cualquier ventana (BrowserProfile.retiredIcons)

    // El icono que puede mostrar la interfaz para `tab` (BrowserTab)
    function displayIcon(tab) {
        const raw = tab ? tab.icon.toString() : ""
        if (raw.startsWith("image://") && (tab.iconRetired || BrowserProfile.retiredIcons[raw] === true))
            return Urls.favicon(tab.url.toString())
        return raw
    }
    Connections {
        target: BrowserProfile
        function onRetiredIconsChanged() { win.refreshIcons() }
    }
    function refreshIcons() {
        for (let i = 0; i < views.count; i++) {
            const tab = views.itemAt(i) as BrowserTab
            // Una restaurada sin cargar aún no tiene icono: conserva el guardado
            if (tab && tab.icon.toString() !== "")
                tabs.setProperty(i, "icon", displayIcon(tab))
        }
    }
    // Los image://favicon de una sesión no valen en la siguiente (y podrían
    // coincidir con el de una pestaña descargada): se guarda el del servicio
    function sessionIcon(icon, url) {
        return String(icon ?? "").startsWith("image://") ? Urls.favicon(url) : (icon ?? "")
    }

    function saveSession() {
        if (privateMode || closingWindow)
            return
        const list = []
        let current = 0
        for (let i = 0; i < tabs.count; i++) {
            const tab = tabs.get(i)
            // La de novedades no vuelve
            if (tab.special !== "")
                continue
            if (i <= currentIndex)
                current = list.length
            list.push({ url: tab.url, title: tab.title, icon: sessionIcon(tab.icon, tab.url), pinned: tab.pinned })
        }
        Settings.setValue("Session/tabs", JSON.stringify({ current: current, tabs: list }))
    }

    // false si no había nada que restaurar. Con `deferAll`, ni la que estaba
    // activa carga todavía (se va a abrir otra: un enlace de fuera)
    function restoreSession(deferAll) {
        let saved = null
        try {
            saved = JSON.parse(Settings.value("Session/tabs", "null"))
        } catch (error) {
            console.warn("[Mitis] Sesión guardada no válida; se empieza de cero")
        }
        if (!saved || !Array.isArray(saved.tabs) || saved.tabs.length === 0)
            return false
        // La activa se fija antes de crear las pestañas: así solo carga ella
        currentIndex = Math.max(0, Math.min(saved.tabs.length - 1, saved.current ?? 0))
        for (let i = 0; i < saved.tabs.length; i++) {
            const tab = saved.tabs[i]
            const url = typeof tab.url === "string" ? tab.url : ""
            const pinned = tab.pinned === true
            tabs.append({ initialUrl: url, url: url, title: tab.title ?? "", icon: sessionIcon(tab.icon, url),
                          audible: false, muted: false, microphone: 0, camera: 0, pinned: pinned, lifecycle: "active",
                          deferred: (deferAll === true || i !== currentIndex) && url !== "", special: "" })
            if (pinned)
                pinnedCount++
        }
        if (showingNewTabPage)
            Qt.callLater(newTabPage.focusSearch)
        return true
    }

    Timer {
        id: sessionSaver
        interval: 1000
        onTriggered: win.saveSession()
    }
    Connections {
        target: tabs
        enabled: !win.privateMode
        function onCountChanged() { sessionSaver.restart() }
        function onDataChanged() { sessionSaver.restart() }
        function onRowsMoved() { sessionSaver.restart() }
    }
    onCurrentIndexChanged: if (!privateMode) sessionSaver.restart()

    // ── Historial ────────────────────────────────────────────────────
    // Cada página a la que se llega (BrowserTab.pageLoaded). Nunca desde una
    // ventana privada.
    function recordVisit(tab) {
        if (!privateMode)
            History.addVisit(tab.url.toString(), tab.title)
    }

    // ── Suspensión de pestañas ───────────────────────────────────────
    // Para ahorrar memoria, las pestañas que no se ven se congelan a los
    // cinco minutos y se descargan a los de Configuración → Rendimiento
    // (BrowserTab.suspend() pone el resto de excepciones). Nunca las fijadas
    // ni la del mini reproductor (sus botones dejarían de responder).
    readonly property int freezeAfter: 5 * 60 * 1000
    function suspendIdleTabs() {
        const discardAfter = Settings.suspendAfter * 60 * 1000
        const now = Date.now()
        for (let i = 0; i < tabs.count; i++) {
            const tab = views.itemAt(i) as BrowserTab
            if (!tab || tab.hiddenSince === 0 || tabs.get(i).pinned || tab === mediaView)
                continue
            const hidden = now - tab.hiddenSince
            if (hidden >= discardAfter)
                tab.suspend(true)
            else if (hidden >= Math.min(freezeAfter, discardAfter))
                tab.suspend(false)
        }
    }
    Timer {
        interval: 30 * 1000
        repeat: true
        running: Settings.suspendAfter > 0 && tabs.count > 1
        onTriggered: win.suspendIdleTabs()
    }

    // ── Monitor de rendimiento ───────────────────────────────────────
    // Lo que mide MemoryMonitor, repartido: el proceso de cada pestaña de
    // esta ventana (contado una vez aunque lo compartan varias) y el resto
    // por tipo. Los de otras ventanas van en «otros». CPU y GPU: -1 = sin dato.
    function measurePerformance() {
        const measured = MemoryMonitor.measure()
        const byPid = {}
        for (const process of measured.processes)
            byPid[process.pid] = process
        const sharing = {}
        for (let i = 0; i < tabs.count; i++) {
            const pid = (views.itemAt(i) as BrowserTab).renderProcessPid
            if (pid > 0)
                sharing[pid] = (sharing[pid] ?? 0) + 1
        }
        const states = { active: "Activa", frozen: "Congelada", discarded: "Descargada" }
        const list = []
        const counted = {}
        const pages = { label: "Páginas de esta ventana", bytes: 0, cpu: -1 }
        // Suma de CPU que deja -1 solo si no hay ningún dato
        const addCpu = (group, cpu) => {
            if (cpu >= 0)
                group.cpu = Math.max(group.cpu, 0) + cpu
        }
        for (let i = 0; i < tabs.count; i++) {
            const tab = views.itemAt(i) as BrowserTab
            const process = byPid[tab.renderProcessPid]
            let detail = i === currentIndex ? "En pantalla" : tab.deferred ? "Sin cargar" : states[tab.lifecycle]
            if (tabs.get(i).pinned)
                detail = "Fijada · " + detail
            if (process && sharing[process.pid] > 1)
                detail += " · proceso compartido con " + (sharing[process.pid] - 1)
                          + (sharing[process.pid] === 2 ? " pestaña" : " pestañas")
            list.push({ url: tab.url.toString(), title: tabs.get(i).title,
                        bytes: process ? process.bytes : 0, cpu: process ? process.cpu : -1,
                        detail: detail })
            if (process && !counted[process.pid]) {
                counted[process.pid] = true
                pages.bytes += process.bytes
                addCpu(pages, process.cpu)
            }
        }
        const browser = { label: "Proceso principal (interfaz y motor)", bytes: 0, cpu: -1 }
        const gpu = { label: "Proceso de la GPU", bytes: 0, cpu: -1 }
        const other = { label: "Otros procesos del motor", bytes: 0, cpu: -1 }
        for (const process of measured.processes) {
            if (counted[process.pid])
                continue
            const group = process.kind === "browser" ? browser : process.kind === "gpu" ? gpu : other
            group.bytes += process.bytes
            addCpu(group, process.cpu)
        }
        const groups = [browser, pages]
        if (gpu.bytes > 0)
            groups.push(gpu)
        groups.push(other)
        performancePanel.sample = { total: measured.total, cpu: measured.cpu, gpu: measured.gpu,
                                    processCount: measured.processes.length,
                                    groups: groups, tabs: list }
    }
    // Abierto por quien lo usa (Shift+Esc, menú, al activar la opción); se
    // ve si además la opción sigue activa y no está Configuración delante
    property bool performancePanelOpen: Settings.performanceMonitor
    function togglePerformancePanel() {
        performancePanelOpen = !performancePanelOpen
    }
    Connections {
        target: Settings
        function onPerformanceMonitorChanged() {
            win.performancePanelOpen = Settings.performanceMonitor
        }
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
        // Lo que se abra se ve: la Configuración se cierra
        if (activate !== false)
            closeSettings()
        const address = target ? target.toString() : ""
        tabs.insert(at, { initialUrl: address, url: address, title: "", icon: "",
                          audible: false, muted: false, microphone: 0, camera: 0, pinned: false, lifecycle: "active",
                          deferred: false, special: "" })
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
    // Captura de pantalla de la pestaña activa (ScreenshotOverlay): solo de
    // páginas web, no de la nueva pestaña ni con Configuración abierta
    function startScreenshot() {
        if (!currentView || showingNewTabPage || settingsOpen || pageFullScreen)
            return
        siteInfoPopup.close()
        screenshotOverlay.open(currentView)
    }

    function openFromTab(opener, openerIndex, target, background) {
        const created = newTab(target, !background, linkTabPosition(opener, openerIndex))
        created.openerTab = opener
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
        case "print":
            tab.requestPrint()
            break
        default:
            // Corrector: una sugerencia para la palabra mal escrita
            if (action.startsWith("replace:")) {
                tab.focusPage()
                tab.replaceMisspelledWord(action.slice("replace:".length))
                break
            }
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
    // Al desactivarlas en Configuración, se cierran las abiertas
    Connections {
        target: Settings
        function onDevToolsChanged() {
            if (Settings.devTools)
                return
            for (let i = 0; i < views.count; i++)
                win.closeDevTools(views.itemAt(i) as BrowserTab)
        }
    }

    // La ventana de DevTools de `tab` es la activa
    function devToolsFocused(tab) {
        return tab !== null && tab.devToolsWindow !== null && tab.devToolsWindow.active
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

    // Abre una dirección guardada (marcador, historial): en la pestaña activa
    // si es la nueva pestaña; si no, en una nueva a su derecha
    function openUrl(url) {
        if (currentView && showingNewTabPage) {
            currentView.navigate(url)
            currentView.focusPage()
        } else {
            newTab(url, true, currentIndex + 1)
        }
    }

    // Pestaña vacía: muestra la página de nueva pestaña con el foco en su buscador
    function openNewTabPage() {
        newTab("")
        Qt.callLater(newTabPage.focusSearch)
    }

    // Una pestaña sin dirección muestra la página de nueva pestaña
    readonly property bool showingNewTabPage: currentView !== null && currentView.url.toString() === ""
                                              && currentView.special === ""

    // ── Configuración ────────────────────────────────────────────────
    // Página sobre las pestañas (no es una pestaña): mientras está abierta,
    // los controles inferiores se ocultan y la pestaña activa no recibe
    // atajos de página (buscar, zoom, F12). Se cierra al cambiar de pestaña.
    // Atrás y adelante sin la barra: botones laterales del ratón y gestos de
    // macOS (NavigationGestures, solo los de esta ventana), si no se han
    // apagado (Configuración → Contenido)
    function historyStep(direction) {
        const tab = win.currentView
        if (!tab || win.settingsOpen || !Settings.navigationGestures)
            return
        if (direction < 0 && tab.canGoBack)
            tab.goBack()
        else if (direction > 0 && tab.canGoForward)
            tab.goForward()
    }
    // Deslizar con dos dedos es también desplazar: solo navega si la página
    // no usa el gesto (BrowserTab.swipeAllowed), y se pregunta con algo de
    // recorrido, cuando la página ya ha recibido los primeros eventos.
    // 0: sin preguntar; 1: preguntando; 2: para navegar; 3: de la página
    property int _swipeCheck: 0
    property int _swipeId: 0
    Connections {
        target: NavigationGestures
        function onNavigateRequested(source, direction) {
            if (source === win)
                win.historyStep(direction)
        }
        function onSwipeUpdated(source, direction, progress) {
            if (source !== win)
                return
            swipeIndicator.direction = direction
            swipeIndicator.progress = progress
            if (win._swipeCheck !== 0 || progress < 0.2)
                return
            const tab = win.currentView
            if (!tab || !Settings.navigationGestures || win.settingsOpen || win.pageFullScreen
                    || !(direction < 0 ? tab.canGoBack : tab.canGoForward)) {
                win._swipeCheck = 3
                return
            }
            win._swipeCheck = 1
            const id = ++win._swipeId
            tab.swipeAllowed(allowed => {
                if (id === win._swipeId && win._swipeCheck === 1)
                    win._swipeCheck = allowed ? 2 : 3
            })
        }
        function onSwipeFinished(source, navigate) {
            if (source !== win)
                return
            if (navigate && win._swipeCheck === 2)
                win.historyStep(swipeIndicator.direction)
            win._swipeCheck = 0
            swipeIndicator.progress = 0
        }
    }

    property bool settingsOpen: false

    // `section`: la de Configuración a la que ir ("history"…); sin ella, arriba
    function openSettings(section) {
        findBar.close()
        settingsOpen = true
        if (section)
            Qt.callLater(() => settingsPage.scrollTo(section))
    }
    function closeSettings() {
        if (!settingsOpen)
            return
        settingsOpen = false
        if (showingNewTabPage)
            newTabPage.focusSearch()
        else if (currentView)
            currentView.focusPage()
    }

    // La página de la pestaña activa está tapada (nueva pestaña, novedades o Configuración)
    readonly property bool pageHidden: showingNewTabPage || showingReleaseNotes || settingsOpen
    // Hay una página web a la vista que imprimir (Ctrl+P, Opciones)
    readonly property bool canPrint: currentView !== null && !pageHidden

    // ── Buscar en la página ──────────────────────────────────────────
    // Pestaña en la que se está buscando (la barra se cierra al cambiar de pestaña)
    property BrowserTab findTab: null

    function openFind() {
        if (pageHidden || pageFullScreen)
            return
        findTab = currentView
        findBar.openAndFocus()
    }

    onCurrentViewChanged: {
        findBar.close()
        closeSettings()
    }

    // ── Zoom ─────────────────────────────────────────────────────────
    // Los mismos pasos que Chrome
    readonly property var zoomSteps: [0.25, 0.33, 0.5, 0.67, 0.75, 0.8, 0.9, 1,
                                      1.1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5]

    // `direction`: 1 acerca, -1 aleja, 0 vuelve al predeterminado (Configuración)
    function zoomBy(direction) {
        if (!currentView || pageHidden)
            return
        if (direction === 0) {
            currentView.resetZoom()
            zoomIndicator.flash()
            return
        }
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
        // Con la página tapada es el zoom predeterminado cambiando en Configuración
        function onZoomChanged() { if (!win.pageHidden) zoomIndicator.flash() }
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

    // Controles inferiores visibles. Se ocultan solos `controlsHold` después
    // de dejar de usarlos, para no tapar lo que las páginas tienen abajo
    // (avisos de cookies, reproductores…): no vuelven al pasar por el borde
    // ni al desplazar la página, solo con la pestaña del borde inferior
    // (ControlsTab). Los mantiene a la vista tener el ratón encima, escribir
    // en la dirección o una lista suya abierta; `revealControls` los fuerza
    // (p. ej. Ctrl+L). En F11, como antes: el borde inferior los muestra.
    property bool revealControls: false
    readonly property bool controlsInUse: revealControls || barHover.hovered || playerHover.hovered
        || controlsTab.hovered || bottomBar.editing
        || tabsPopup.opened || bookmarksPopup.opened || optionsPopup.opened || siteInfoPopup.opened
        || historyPopup.opened || downloadsPopup.opened || downloadPanel.opened || updatePopup.opened
    // A la vista fuera de F11; al abrir Mitis también (para saber dónde están)
    property bool controlsAwake: true
    onControlsInUseChanged: {
        if (controlsInUse) {
            controlsAwake = true
            controlsHold.stop()
        } else {
            controlsHold.restart()
        }
    }
    Timer {
        id: controlsHold
        interval: Theme.controlsHold
        running: true
        onTriggered: if (!win.controlsInUse) win.controlsAwake = false
    }
    // En la nueva pestaña no se ocultan: no hay página que tapar
    readonly property bool controlsShown: !settingsOpen && (immersive
        ? !pageFullScreen && (controlsInUse || revealHover.hovered)
        : controlsAwake || showingNewTabPage || showingReleaseNotes)

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
        historyPopup.close()
        optionsPopup.close()
        downloadsPopup.close()
        downloadPanel.close()
        contextMenu.close()
        closeSettings()
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

    // Roles: initialUrl (solo al crear), url, title, icon, audible, muted, microphone, camera, pinned,
    // lifecycle ("active", "frozen" o "discarded": BrowserTab.lifecycle)
    ListModel {
        id: tabs
    }

    // ── Barra de título que se oculta sola ───────────────────────────
    // Flota sobre la página (no la empuja) y está oculta desde que se abre
    // Mitis: aparece al pasar el ratón por el borde superior y se queda
    // `titleBarHold` tras quitarlo. Con Configuración abierta, siempre (no
    // hay página que tapar). Sube y baja moviendo su `y`: lo anclado a su
    // borde inferior (buscar, zoom, panel de memoria) la acompaña.
    property bool titleBarShown: false
    readonly property bool titleBarPinned: settingsOpen || titleBarHover.hovered || titleRevealHover.hovered
    onTitleBarPinnedChanged: {
        if (titleBarPinned) {
            titleBarShown = true
            titleBarHold.stop()
        } else {
            titleBarHold.restart()
        }
    }
    Timer {
        id: titleBarHold
        interval: Theme.titleBarHold
        onTriggered: if (!win.titleBarPinned) win.titleBarShown = false
    }

    TitleBar {
        id: titleBar
        z: 2
        window: win
        privateMode: win.privateMode
        onProfileRequested: win.openSettings("profile")
        anchors.left: parent.left
        anchors.right: parent.right
        y: win.titleBarShown ? 0 : -height
        Behavior on y {
            NumberAnimation { duration: Theme.durationBase; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        }
        // En pantalla completa desaparece y lo anclado a la barra (como la
        // búsqueda) sube hasta el borde superior
        height: win.immersive ? 0 : implicitHeight
        visible: !win.immersive && y > -height
        HoverHandler { id: titleBarHover }
    }

    // Franja del borde superior que muestra la barra. No bloquea el ratón:
    // la página sigue recibiendo el hover y los clics. Sin maximizar, justo
    // debajo del borde de redimensionar, con algo de tolerancia.
    Item {
        z: 2
        readonly property bool windowed: win.visibility === Window.Windowed
        anchors.left: parent.left
        anchors.right: parent.right
        y: windowed ? Theme.resizeGrip : 0
        height: windowed ? Theme.titleBarRevealTolerance : Theme.fullscreenRevealEdge
        visible: !win.immersive
        HoverHandler { id: titleRevealHover }
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
                 : win.showingReleaseNotes ? "Novedades de Mitis"
                 : (win.currentView ? win.currentView.title : "")
        canGoBack: win.currentView ? win.currentView.canGoBack : false
        canGoForward: win.currentView ? win.currentView.canGoForward : false
        loading: win.currentView ? win.currentView.loading : false
        loadProgress: win.currentView ? win.currentView.loadProgress : 0
        tabCount: tabs.count
        bookmarked: win.currentView !== null && Bookmarks.urls.indexOf(win.currentView.url.toString()) >= 0
        downloadsShown: downloadPanel.active
        updateAvailable: !win.privateMode && Updates.available !== ""
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
        onSiteInfoRequested: siteInfoPopup.opened ? siteInfoPopup.close() : siteInfoPopup.open()
        // Conexión de la página para el botón del sitio (candado)
        security: {
            if (!win.currentView || win.showingNewTabPage)
                return ""
            const address = win.currentView.url.toString()
            if (address.startsWith("https:"))
                return win.currentView.certificateOverridden ? "overridden" : "secure"
            return address.startsWith("http:") ? "insecure" : ""
        }
        // Con el listado de descargas abierto, el botón de opciones lo cierra
        onOptionsRequested: downloadsPopup.opened ? downloadsPopup.close()
                          : historyPopup.opened ? historyPopup.close()
                          : optionsPopup.opened ? optionsPopup.close() : optionsPopup.open()
        onUpdateRequested: updatePopup.opened ? updatePopup.close() : updatePopup.open()
    }

    Item {
        id: pages
        // Lo que se ve difuminado a través de los controles (Glass)
        readonly property bool glassBackdrop: true
        // Desde el borde superior: la barra de título flota encima
        anchors.top: parent.top
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
                required deferred
                required special

                readonly property bool current: index === win.currentIndex

                anchors.fill: parent
                visible: current
                privateMode: win.privateMode

                // Una restaurada carga al seleccionarla. Se mira un momento
                // después: al mover filas (moveTab) otra pestaña puede ser «la
                // actual» un instante, y no debe cargarse por eso
                onCurrentChanged: if (current) {
                    win.currentView = tab
                    Qt.callLater(() => {
                        if (tab.current)
                            tab.load()
                    })
                }
                Component.onCompleted: if (current) win.currentView = tab

                onUrlChanged: {
                    tabs.setProperty(index, "url", url.toString())
                    // Escribir una dirección en la de novedades la convierte en una normal
                    if (special !== "" && url.toString() !== "") {
                        special = ""
                        tabs.setProperty(index, "special", "")
                    }
                }
                onPageLoaded: win.recordVisit(tab)
                onTitleChanged: {
                    if (special !== "")
                        return
                    tabs.setProperty(index, "title", title)
                    if (!win.privateMode)
                        History.updateTitle(tab.url.toString(), title)
                }
                onIconChanged: if (special === "") tabs.setProperty(index, "icon", win.displayIcon(tab))
                onIconRetiredChanged: win.refreshIcons()
                onMutedChanged: tabs.setProperty(index, "muted", tab.muted)
                onMicrophoneChanged: tabs.setProperty(index, "microphone", tab.microphone)
                onCameraChanged: tabs.setProperty(index, "camera", tab.camera)
                onLifecycleChanged: tabs.setProperty(index, "lifecycle", tab.lifecycle)
                onAudibleChanged: {
                    tabs.setProperty(index, "audible", tab.audible)
                    // Solo si tiene algo que reproducir: una llamada (Meet,
                    // Zoom…) suena pero no se lleva el mini reproductor
                    if (tab.audible && tab !== win.mediaView) {
                        tab.mediaState(state => {
                            if (state && tab.audible) {
                                win.mediaView = tab
                                win.media = state
                            }
                        })
                    }
                }

                // Enlaces y ventanas emergentes se abren como pestañas, a la
                // derecha de esta (en serie si se abren varios seguidos)
                onNewTabRequested: (background, request) => {
                    win.openFromTab(tab, index, "", background).adopt(request)
                }

                onCloseRequested: win.closeTab(index)
                // Se abrió solo para una descarga: se cierra y se vuelve a la
                // pestaña desde la que se pidió (si sigue abierta)
                onOpenedOnlyForDownload: {
                    const back = tab.openerTab
                    const wasCurrent = tab === win.currentView
                    win.closeTab(index)
                    if (wasCurrent && back)
                        win.selectView(back)
                }
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

                // Imprimir y guardar como PDF: ventana propia sobre la página
                onPrintRequested: printDialog.open()

                PrintDialog {
                    id: printDialog
                    page: tab
                    onFinished: tab.focusPage()
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

        // Novedades tras actualizar, sobre su pestaña
        ReleaseNotesPage {
            anchors.fill: parent
            visible: win.showingReleaseNotes
            notes: win.releaseNotes
            onCloseRequested: win.closeTab(win.currentIndex)
        }
    }

    // Configuración: sobre las pestañas y los controles inferiores
    SettingsPage {
        id: settingsPage
        z: 1
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        open: win.settingsOpen
        graphicsApi: win.graphicsApi
        currentPageUrl: win.currentView && !win.privateMode ? win.currentView.url.toString() : ""
        onCloseRequested: win.closeSettings()
        onUpdateRequested: win.installUpdate()
    }

    // «Preguntar dónde guardar» (Configuración → Descargas): la carpeta se
    // elige en la ventana que atiende los atajos (la activa)
    Connections {
        target: BrowserProfile
        enabled: win.ownsShortcuts
        function onDownloadFolderRequested(request) {
            filePicker.ask(null, {
                folder: true,
                title: "Guardar «" + request.fileName + "» en",
                startFolder: Urls.fileUrl(request.folder),
                accept: urls => request.accept(Urls.localPath(urls[0])),
                reject: () => request.reject()
            })
        }
    }

    // Selector de archivos de las páginas (<input type=file>), uno para todas
    FilePicker {
        id: filePicker
    }

    // Descargas en curso: se abre solo al empezar y al terminar cada una
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

    // Marcadores: la página actual, buscar, abrir y quitar
    BookmarksPopup {
        id: bookmarksPopup
        parent: bottomBar.bookmarksButton
        x: parent.width - width
        y: -height - Theme.floatingMargin
        pageUrl: win.currentView && !win.showingNewTabPage ? win.currentView.url.toString() : ""
        pageTitle: win.currentView ? win.currentView.title : ""
        onOpenRequested: url => win.openUrl(url)
    }

    // Panel del sitio (candado del campo de dirección): conexión y
    // certificado, rastreadores y acciones con la página
    SiteInfoPopup {
        id: siteInfoPopup
        parent: bottomBar.addressField
        x: 0
        y: -height - Theme.floatingMargin
        pageUrl: win.currentView && !win.showingNewTabPage ? win.currentView.url.toString() : ""
        pageTitle: win.currentView ? win.currentView.title : ""
        pageIcon: win.displayIcon(win.currentView)
        security: bottomBar.security
        onReloadRequested: if (win.currentView) win.currentView.reload()
        onSettingsRequested: section => win.openSettings(section)
        onScreenshotRequested: win.startScreenshot()
    }

    // Historial: reabrir la última cerrada, lo visitado y el acceso a Configuración
    HistoryPopup {
        id: historyPopup
        parent: bottomBar.optionsButton
        x: parent.width - width
        y: -height - Theme.floatingMargin
        closedCount: win.closedTabs.length
        onOpenRequested: url => win.openUrl(url)
        onReopenRequested: win.reopenClosedTab()
        onSettingsRequested: win.openSettings("history")
    }

    // Confirmación de la actualización (botón tras Opciones)
    UpdatePopup {
        id: updatePopup
        parent: bottomBar.updateButton
        x: parent.width - width
        y: -height - Theme.floatingMargin
    }

    OptionsPopup {
        id: optionsPopup
        parent: bottomBar.optionsButton
        performanceMonitor: Settings.performanceMonitor
        canPrint: win.canPrint
        x: parent.width - width
        y: -height - Theme.floatingMargin
        onOptionSelected: key => {
            if (key === "downloads")
                downloadsPopup.open()
            else if (key === "history")
                historyPopup.open()
            else if (key === "private")
                win.openPrivateWindow()
            else if (key === "settings")
                win.openSettings()
            else if (key === "profile")
                win.openSettings("profile")
            else if (key === "performance")
                win.togglePerformancePanel()
            else if (key === "print")
                win.currentView.requestPrint()
        }
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
        inspectAvailable: Settings.devTools
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

    MemoryPanel {
        id: performancePanel
        z: 1
        anchors.top: titleBar.bottom
        anchors.topMargin: Theme.floatingMargin
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        // Configuración lo tapa: se oculta (y deja de medir) mientras está abierta
        shown: Settings.performanceMonitor && win.performancePanelOpen && !win.settingsOpen
        graphicsApi: win.graphicsApi
        onRefreshRequested: win.measurePerformance()
        onTabSelected: index => win.selectTab(index)
        onCloseRequested: win.togglePerformancePanel()
    }

    // Deslizar entre páginas con dos dedos (macOS): la flecha del lado al que
    // se va, a media altura de las páginas
    SwipeIndicator {
        id: swipeIndicator
        z: 1
        shown: win._swipeCheck === 2
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

    // Con los controles ocultos: pestaña con el título de la página que los
    // vuelve a mostrar (no en pantalla completa ni con Configuración)
    ControlsTab {
        id: controlsTab
        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        title: bottomBar.pageTitle
        visible: opacity > 0
        opacity: !win.controlsShown && !win.immersive && !win.settingsOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
    }

    MiniPlayer {
        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        // Pegado a la barra inferior, a la misma distancia que sus controles
        anchors.bottom: bottomBar.top
        anchors.bottomMargin: Theme.spacing - Theme.floatingMargin
        visible: opacity > 0
        // Va con los controles inferiores: en pantalla completa se oculta con
        // ellos. En la pestaña que suena no hace falta (está su propio
        // reproductor), salvo con Configuración abierta encima
        opacity: win.media && win.controlsShown
                 && (win.mediaView !== win.currentView || win.settingsOpen) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
        HoverHandler { id: playerHover }

        iconSource: win.displayIcon(win.mediaView)
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

    // Captura de pantalla: sobre la página y los controles de abajo, bajo la
    // barra de título. Copia la capa de las páginas (sin la interfaz)
    ScreenshotOverlay {
        id: screenshotOverlay
        z: 1.5
        anchors.fill: parent
        source: pages
    }

    // Avisos de arriba, solo en la ventana principal: cierre inesperado de la
    // sesión anterior
    Column {
        z: 2
        anchors.top: parent.top
        anchors.topMargin: Theme.floatingMargin
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacing

        Notice {
            id: crashNotice
            anchors.horizontalCenter: parent.horizontalCenter
            shown: !win.privateMode && CrashReports.pending !== ""
            text: "Mitis se cerró de forma inesperada. Se guardó un informe."
            onClosed: CrashReports.dismiss()

            property bool copied: false

            TextButton {
                text: crashNotice.copied ? "Copiado" : "Copiar informe"
                onClicked: {
                    CrashReports.copy(CrashReports.pending)
                    crashNotice.copied = true
                }
            }
            TextButton {
                text: "Abrir carpeta"
                onClicked: CrashReports.openFolder()
            }
        }
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
        enabled: win.ownsShortcuts && win.pageFullScreen
        onActivated: win.exitPageFullScreen()
        onActivatedAmbiguously: win.exitPageFullScreen()
    }
    Shortcut {
        sequence: "F12"
        // También desde la ventana de DevTools de esta pestaña, para cerrarla
        context: Qt.ApplicationShortcut
        enabled: Settings.devTools && win.currentView !== null && !win.pageHidden
                 && (win.ownsShortcuts || win.devToolsFocused(win.currentView))
        onActivated: win.toggleDevTools(win.currentView)
        onActivatedAmbiguously: win.toggleDevTools(win.currentView)
    }
    // Monitor de rendimiento (como el administrador de tareas de Chrome)
    Shortcut {
        sequence: "Shift+Esc"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts && Settings.performanceMonitor
        onActivated: win.togglePerformancePanel()
        onActivatedAmbiguously: win.togglePerformancePanel()
    }
    Shortcut {
        sequence: "F11"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.toggleWindowFullScreen()
        onActivatedAmbiguously: win.toggleWindowFullScreen()
    }

    // Atajos de teclado
    Shortcut {
        sequence: "Ctrl+T"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: {
            win.openNewTabPage()
        }
    }
    Shortcut {
        sequence: "Ctrl+Shift+T"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.reopenClosedTab()
    }
    Shortcut {
        sequence: "Ctrl+W"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.closeTab(win.currentIndex)
    }
    Shortcut {
        sequence: "Ctrl+L"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: {
            // En F11 la barra está oculta: se muestra antes de darle el foco
            win.closeSettings()
            win.revealControls = true
            bottomBar.focusAddress()
            win.revealControls = false
        }
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.selectTab(win.currentIndex + 1)
    }
    Shortcut {
        // Una sola secuencia: "Ctrl+Backtab" y similares coinciden con la misma
        // pulsación y Qt las declara ambiguas (no emite onActivated). Si otro
        // sistema la reporta ambigua igualmente, se atiende igual.
        sequence: "Ctrl+Shift+Tab"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.selectTab(win.currentIndex - 1)
        onActivatedAmbiguously: win.selectTab(win.currentIndex - 1)
    }
    Shortcut {
        sequence: "Ctrl+Shift+A"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: {
            win.closeSettings()
            tabsPopup.opened ? tabsPopup.close() : tabsPopup.open()
        }
    }
    Shortcut {
        sequence: "Ctrl+Shift+S"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.startScreenshot()
    }
    Shortcut {
        sequence: "Ctrl+P"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts && win.canPrint
        onActivated: win.currentView.requestPrint()
    }
    Shortcut {
        sequence: "Ctrl+F"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.openFind()
    }
    Shortcut {
        sequences: ["F3", "Ctrl+G"]
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: findBar.isOpen ? findBar.findNext() : win.openFind()
    }
    Shortcut {
        sequences: ["Shift+F3", "Ctrl+Shift+G"]
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: findBar.isOpen ? findBar.findPrevious() : win.openFind()
    }
    // Zoom: un Shortcut por secuencia (varias equivalentes en uno solo son
    // ambiguas). "Ctrl+=" es el "+" sin Mayús de los teclados en inglés.
    Shortcut {
        sequence: "Ctrl++"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.zoomBy(1)
        onActivatedAmbiguously: win.zoomBy(1)
    }
    Shortcut {
        sequence: "Ctrl+="
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.zoomBy(1)
        onActivatedAmbiguously: win.zoomBy(1)
    }
    Shortcut {
        sequence: "Ctrl+-"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.zoomBy(-1)
        onActivatedAmbiguously: win.zoomBy(-1)
    }
    Shortcut {
        sequence: "Ctrl+0"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.zoomBy(0)
        onActivatedAmbiguously: win.zoomBy(0)
    }
    Shortcut {
        sequences: ["Ctrl+R", "F5"]
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.currentView.reload()
    }
    Shortcut {
        sequence: "Alt+Left"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.currentView.goBack()
    }
    Shortcut {
        sequence: "Alt+Right"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.currentView.goForward()
    }

    Shortcut {
        sequence: "Ctrl+D"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: {
            win.closeSettings()
            if (!bookmarksPopup.bookmarked)
                bookmarksPopup.toggleCurrent()
            bookmarksPopup.open()
        }
    }
    Shortcut {
        sequence: "Ctrl+H"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: {
            win.closeSettings()
            historyPopup.opened ? historyPopup.close() : historyPopup.open()
        }
    }
    Shortcut {
        sequence: "Ctrl+Shift+N"
        context: Qt.ApplicationShortcut
        enabled: win.ownsShortcuts
        onActivated: win.openPrivateWindow()
    }
}

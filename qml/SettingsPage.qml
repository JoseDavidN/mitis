pragma ComponentBehavior: Bound
import QtCore as Core
import QtQuick
import QtQuick.Dialogs
import Mitis.Core

import "urls.js" as Urls

// Página de Configuración: ocupa la ventana bajo la barra de título, sobre
// las pestañas (menú de opciones → Configuración; se cierra con Esc o la ✕).
// Índice de secciones a la izquierda y, a la derecha, cada sección con sus
// ajustes en una tarjeta. Todo se guarda al momento en Settings.
FocusScope {
    id: root

    property bool open: false
    // Su fondo: lo difumina el vidrio de sus tarjetas y de las listas que abre
    readonly property Item glassBackdropItem: backdrop

    // Cómo dibuja la ventana: con la GPU (y qué API) o por software (lo
    // pregunta Main a C++ al primer fotograma). Lo muestra la opción de
    // transparencia, que sin GPU no funciona
    property string graphicsApi: ""
    readonly property string graphicsApiName: graphicsApi !== "" ? graphicsApi : "desconocido"
    readonly property bool gpuRendering: graphicsApiName !== "software" && graphicsApiName !== "desconocido"

    // Página de la pestaña activa (para «Usar la página actual» al iniciar)
    property string currentPageUrl: ""

    signal closeRequested()
    // «Actualizar» (Acerca de Mitis): lo hace la ventana, que debe cerrarse
    signal updateRequested()

    // Secciones del índice, en el orden de la página
    readonly property var sections: [
        { key: "profile", title: "Perfil", icon: "profile" },
        { key: "startup", title: "Al iniciar", icon: "reopen" },
        { key: "appearance", title: "Apariencia e idioma", icon: "appearance" },
        { key: "search", title: "Búsqueda", icon: "search" },
        { key: "newtab", title: "Nueva pestaña", icon: "new-tab" },
        { key: "privacy", title: "Privacidad", icon: "privacy" },
        { key: "blocker", title: "Anuncios y rastreadores", icon: "blocker" },
        { key: "security", title: "Seguridad", icon: "security" },
        { key: "permissions", title: "Permisos de sitios", icon: "permissions" },
        { key: "sites", title: "Ajustes por sitio", icon: "sites" },
        { key: "content", title: "Contenido", icon: "open-image" },
        { key: "history", title: "Borrar datos", icon: "history" },
        { key: "downloads", title: "Descargas", icon: "downloads" },
        { key: "performance", title: "Rendimiento", icon: "performance" },
        { key: "shortcuts", title: "Atajos de teclado", icon: "keyboard" },
        { key: "developer", title: "Desarrollo", icon: "devtools" },
        { key: "about", title: "Acerca de Mitis", icon: "info" }
    ]

    // ── Opciones de los ajustes ──────────────────────────────────────
    readonly property var zoomOptions: [
        { value: 0.8, label: "80 %" }, { value: 0.9, label: "90 %" }, { value: 1, label: "100 %" },
        { value: 1.1, label: "110 %" }, { value: 1.25, label: "125 %" }, { value: 1.5, label: "150 %" }
    ]
    // Minutos sin usar tras los que se descarga una pestaña (0 = nunca)
    readonly property var suspendOptions: [
        { value: 15, label: "15 min" }, { value: 30, label: "30 min" }, { value: 60, label: "1 hora" },
        { value: 120, label: "2 horas" }, { value: 0, label: "Nunca" }
    ]
    // Tamaño de los controles de abajo (factores en Theme.controlsScales)
    readonly property var controlsSizeOptions: [
        { value: "normal", label: "Normal" }, { value: "large", label: "Grande" },
        { value: "larger", label: "Más grande" }
    ]
    // Páginas anteriores que guarda cada pestaña para volver al instante
    readonly property var instantBackOptions: [
        { value: 0, label: "No" }, { value: 1, label: "La anterior" }, { value: 3, label: "Las 3 anteriores" }
    ]
    // Espacio para la caché de las páginas, en MB (0 = automático)
    readonly property var cacheSizeOptions: [
        { value: 100, label: "100 MB" }, { value: 250, label: "250 MB" },
        { value: 500, label: "500 MB" }, { value: 0, label: "Automático" }
    ]
    // 0,4 MB, 172 MB o 1,2 GB
    function formatSize(bytes) {
        const locale = Qt.locale("es_ES")
        const mb = bytes / (1024 * 1024)
        if (mb >= 1024)
            return (mb / 1024).toLocaleString(locale, "f", 1) + " GB"
        return mb.toLocaleString(locale, "f", mb < 10 ? 1 : 0) + " MB"
    }
    // Idiomas que se pueden pedir a las páginas (código de Accept-Language)
    readonly property var languageOptions: [
        { value: "es", label: "Español" }, { value: "en", label: "Inglés" },
        { value: "pt", label: "Portugués" }, { value: "fr", label: "Francés" },
        { value: "de", label: "Alemán" }, { value: "it", label: "Italiano" },
        { value: "ca", label: "Catalán" }
    ]
    // Permisos que se pueden bloquear para todos los sitios
    readonly property var permissionKinds: [
        { kind: "location", title: "Ubicación", icon: "location" },
        { kind: "camera", title: "Cámara", icon: "camera" },
        { kind: "microphone", title: "Micrófono", icon: "microphone" },
        { kind: "notifications", title: "Notificaciones", icon: "notifications" },
        { kind: "clipboard", title: "Leer el portapapeles", icon: "clipboard" },
        { kind: "screen", title: "Compartir la pantalla", icon: "screen" }
    ]
    // Nombre e icono de un permiso guardado (también "fonts")
    function permissionInfo(kind) {
        return permissionKinds.find(item => item.kind === kind)
            ?? (kind === "fonts" ? { kind: kind, title: "Fuentes del equipo", icon: "fonts" }
                                 : { kind: kind, title: kind, icon: "permissions" })
    }
    function setPermissionBlocked(kind, blocked) {
        const list = Settings.blockedPermissions.filter(item => item !== kind)
        if (blocked)
            list.push(kind)
        Settings.blockedPermissions = list
    }
    function toggleLanguage(code) {
        const list = Settings.languages
        if (!list.includes(code))
            Settings.languages = list.concat([code])
        else if (list.length > 1)   // Siempre queda al menos uno
            Settings.languages = list.filter(item => item !== code)
    }
    function languageName(code) {
        return languageOptions.find(item => item.value === code)?.label ?? code
    }

    // Permisos guardados por sitio: se leen al abrir y tras olvidar uno
    property var sitePermissions: []
    function refreshSitePermissions() {
        sitePermissions = BrowserProfile.sitePermissions()
    }

    // ── Ajustes por sitio ────────────────────────────────────────────
    // Cada sitio (el de BrowserProfile.siteOf: «a.com» para www.a.com y
    // blog.a.com) con lo que tiene propio, en filas: zoom (por host),
    // permisos guardados (por origen) y anuncios permitidos en el bloqueador.
    // [{ site, items: [{ type, icon, title, detail, warn, host, origin, kind }] }]
    readonly property var siteSettings: {
        const groups = {}
        const group = site => groups[site] ?? (groups[site] = { site: site, items: [] })
        const hostOf = address => address.replace(/^[a-z][a-z0-9+.-]*:\/\//i, "").replace(/\/$/, "")
        const zooms = BrowserProfile.siteZooms
        for (const host in zooms) {
            const site = BrowserProfile.siteOf("https://" + host) || host
            group(site).items.push({ type: "zoom", icon: "search", host: host,
                                     title: host === site ? "Zoom" : "Zoom en " + host,
                                     detail: Math.round(zooms[host] * 100) + " %", warn: false })
        }
        for (const permission of sitePermissions) {
            const host = hostOf(permission.origin)
            const site = BrowserProfile.siteOf(permission.origin) || host
            const info = permissionInfo(permission.kind)
            group(site).items.push({ type: "permission", icon: info.icon, origin: permission.origin,
                                     kind: permission.kind,
                                     title: host === site ? info.title : info.title + " en " + host,
                                     detail: permission.allowed ? "Permitido" : "Bloqueado",
                                     warn: !permission.allowed })
        }
        for (const site of Settings.adBlockAllowedSites)
            group(site).items.push({ type: "ads", icon: "blocker", title: "Anuncios y rastreadores",
                                     detail: "Permitidos: el bloqueador no actúa", warn: true })
        return Object.keys(groups).sort().map(site => groups[site])
    }
    // Sitio desplegado ("" = ninguno) y cuántos se ven (la lista puede ser larga)
    property string openSite: ""
    property int sitesShown: Theme.settingsSitesPage
    // Resumen de un sitio: «Zoom 125 % · Ubicación · Anuncios permitidos»
    function siteSummary(group) {
        return group.items.map(item => item.type === "zoom" ? item.title + " " + item.detail
                                     : item.type === "ads" ? "Anuncios permitidos"
                                     : item.title + " " + item.detail.toLowerCase()).join(" · ")
    }
    function forgetSiteItem(item) {
        if (item.type === "zoom") {
            BrowserProfile.forgetSiteZoom(item.host)
        } else if (item.type === "permission") {
            BrowserProfile.forgetSitePermission(item.origin, item.kind)
            refreshSitePermissions()
        } else {
            Settings.adBlockAllowedSites = Settings.adBlockAllowedSites.filter(site => site !== item.site)
        }
    }
    function forgetSite(group) {
        for (const item of group.items)
            forgetSiteItem(Object.assign({ site: group.site }, item))
        if (openSite === group.site)
            openSite = ""
    }

    // Bloqueador: sitio de la pestaña activa (para «Permitir en…») y estado de las listas
    readonly property string currentSite: /^https?:/.test(currentPageUrl) ? BrowserProfile.siteOf(currentPageUrl) : ""
    readonly property string filterListsStatus: {
        if (!Settings.blockAds)
            return "El bloqueador está desactivado."
        const rules = BrowserProfile.adBlockRules
        if (rules === 0)
            return BrowserProfile.adBlockUpdating ? "Descargando las listas…"
                                                  : "Aún no se han podido descargar: se volverá a intentar."
        const locale = Qt.locale("es_ES")
        const updated = BrowserProfile.adBlockUpdated
        return rules.toLocaleString(locale, "f", 0) + " reglas"
            + (isNaN(updated.getTime()) ? "" : ", del " + updated.toLocaleDateString(locale, "d 'de' MMMM"))
            + ". Se renuevan solas cada 4 días. Bloqueado desde que abriste Mitis: "
            + BrowserProfile.adBlockBlocked.toLocaleString(locale, "f", 0) + "."
    }
    function allowAdsOn(site) {
        if (!Settings.adBlockAllowedSites.includes(site))
            Settings.adBlockAllowedSites = Settings.adBlockAllowedSites.concat([site]).sort()
    }

    // Página al iniciar: lo escrito → dirección ("" = ninguna)
    function saveStartupUrl() {
        Settings.startupUrl = startupField.text.trim() === "" ? "" : SearchEngines.resolve(startupField.text)
        startupField.text = Settings.startupUrl
    }

    // DNS cifrado: el del sistema, cifrado con respaldo o solo cifrado
    readonly property var secureDnsModes: [
        { value: "off", label: "Desactivado" }, { value: "auto", label: "Automático" },
        { value: "secure", label: "Siempre" }
    ]

    // Atajos de teclado (los de Main.qml), por grupos: un grupo por página
    // para que la sección no se haga larga. Cada atajo: qué hace, una o
    // varias combinaciones y, si hace falta, cuándo funciona
    readonly property var shortcutGroups: [
        { title: "Pestañas", items: [
            { action: "Nueva pestaña", keys: ["Ctrl+T"] },
            { action: "Cerrar la pestaña", keys: ["Ctrl+W"] },
            { action: "Reabrir la última cerrada", keys: ["Ctrl+Shift+T"] },
            { action: "Pestaña siguiente", keys: ["Ctrl+Tab"] },
            { action: "Pestaña anterior", keys: ["Ctrl+Shift+Tab"] },
            { action: "Lista de pestañas", keys: ["Ctrl+Shift+A"] }
        ] },
        { title: "Esenciales", items: [
            { action: "Primera esencial", keys: ["Ctrl+1"] },
            { action: "Segunda esencial", keys: ["Ctrl+2"] },
            { action: "Tercera esencial", keys: ["Ctrl+3"] },
            { action: "Cuarta esencial", keys: ["Ctrl+4"] }
        ] },
        { title: "Navegar", items: [
            { action: "Escribir una dirección o buscar", keys: ["Ctrl+L"] },
            { action: "Atrás", keys: ["Alt+Left"] },
            { action: "Adelante", keys: ["Alt+Right"] },
            { action: "Recargar la página", keys: ["Ctrl+R", "F5"] },
            { action: "Guardar en marcadores", keys: ["Ctrl+D"] },
            { action: "Historial", keys: ["Ctrl+H"] }
        ] },
        { title: "Buscar y zoom", items: [
            { action: "Buscar en la página", keys: ["Ctrl+F"] },
            { action: "Siguiente coincidencia", keys: ["F3", "Ctrl+G"] },
            { action: "Coincidencia anterior", keys: ["Shift+F3", "Ctrl+Shift+G"] },
            { action: "Acercar", keys: ["Ctrl++"] },
            { action: "Alejar", keys: ["Ctrl+-"] },
            { action: "Tamaño normal", keys: ["Ctrl+0"] }
        ] },
        { title: "Ventana y herramientas", items: [
            { action: "Nueva ventana privada", keys: ["Ctrl+Shift+N"] },
            { action: "Pantalla completa", keys: ["F11"] },
            { action: "Imprimir o guardar como PDF", keys: ["Ctrl+P"] },
            { action: "Captura de pantalla", keys: ["Ctrl+Shift+S"] },
            { action: "Monitor de rendimiento", note: "Si está activado en Desarrollo", keys: ["Shift+Esc"] },
            { action: "Herramientas de desarrollo", note: "Si están activadas en Desarrollo", keys: ["F12"] }
        ] }
    ]
    property int shortcutPage: 0
    readonly property bool macKeys: Qt.platform.os === "osx" || Qt.platform.os === "macos"
    // Teclas de una combinación, como se ven en el teclado (en macOS, Qt
    // cambia Ctrl por Cmd y Alt es Opción)
    function shortcutKeys(sequence) {
        const names = macKeys ? { "Ctrl": "⌘", "Alt": "⌥", "Shift": "⇧", "Left": "←", "Right": "→", "Tab": "⇥" }
                              : { "Shift": "Mayús", "Left": "←", "Right": "→" }
        // "Ctrl++": el último «+» es la tecla, no el separador
        const parts = sequence.endsWith("++") ? sequence.slice(0, -2).split("+").concat(["+"]) : sequence.split("+")
        return parts.map(part => names[part] ?? part)
    }

    // «Restablecer»: el primer clic pide confirmación
    property bool resetPending: false
    // Sección a la vista, resaltada en el índice
    property string currentSection: "startup"
    readonly property bool wide: width >= Theme.settingsNavBreakpoint
    // Índice y columna van juntos y centrados; sin índice, la columna sola
    readonly property real contentWidth: Math.min(width - 4 * Theme.margin - (wide ? Theme.settingsNavWidth + Theme.settingsSectionSpacing : 0),
                                                  Theme.settingsMaxWidth)
    readonly property real layoutX: Math.max(2 * Theme.margin,
                                             (width - contentWidth - (wide ? Theme.settingsNavWidth + Theme.settingsSectionSpacing : 0)) / 2)

    // Se intentó guardar un buscador personalizado no válido
    property bool customError: false

    // ── Borrar datos de navegación ───────────────────────────────────
    // Periodo del historial y del listado de descargas: { key, label, ms }
    // (ms = 0: desde siempre). Cookies, caché y permisos se borran enteros.
    readonly property var clearPeriods: [
        { key: "hour", label: "Última hora", ms: 3600000 },
        { key: "day", label: "Último día", ms: 86400000 },
        { key: "week", label: "Última semana", ms: 7 * 86400000 },
        { key: "all", label: "Desde siempre", ms: 0 }
    ]
    property string clearPeriod: "hour"
    property bool clearHistory: true
    property bool clearDownloads: false
    property bool clearCookies: false
    property bool clearCache: true
    property bool clearPermissions: false
    readonly property bool clearSomething: clearHistory || clearDownloads || clearCookies
                                           || clearCache || clearPermissions
    // Se acaba de borrar: se muestra «Datos borrados» un momento
    property bool cleared: false

    function clearBrowsingData() {
        const period = clearPeriods.find(item => item.key === clearPeriod)
        const since = period.ms > 0 ? Date.now() - period.ms : 0
        if (clearHistory)
            History.clear(since)
        if (clearDownloads)
            Downloads.clearFinished(since)
        if (clearCookies)
            BrowserProfile.clearCookies()
        if (clearCache)
            BrowserProfile.clearCache()
        if (clearPermissions)
            BrowserProfile.clearPermissions()
        cleared = true
        clearedTimer.restart()
    }

    Timer {
        id: clearedTimer
        interval: Theme.clearedNoticeHold
        onTriggered: root.cleared = false
    }

    function sectionItem(key) {
        switch (key) {
        case "profile": return profileSection
        case "startup": return startupSection
        case "appearance": return appearanceSection
        case "search": return searchSection
        case "newtab": return newTabSection
        case "privacy": return privacySection
        case "blocker": return blockerSection
        case "security": return securitySection
        case "permissions": return permissionsSection
        case "sites": return sitesSection
        case "content": return contentSection
        case "history": return historySection
        case "downloads": return downloadsSection
        case "performance": return performanceSection
        case "shortcuts": return shortcutsSection
        case "developer": return developerSection
        case "about": return aboutSection
        default: return startupSection
        }
    }

    // Ir a una sección en cuanto esté colocada. Recién creada (Main la crea
    // al abrirla), sus columnas se colocan en los primeros fotogramas y con
    // un ancho aún provisional: se espera a que la altura del contenido no
    // cambie de un fotograma al siguiente (durante el fundido de entrada se
    // pintan varios). Desde entonces se va directamente
    function showSection(key) {
        // Desde el panel del sitio: el de la pestaña activa, desplegado
        if (key === "sites" && siteSettings.some(group => group.site === currentSite)) {
            openSite = currentSite
            sitesShown = Math.max(sitesShown, siteSettings.findIndex(group => group.site === currentSite) + 1)
        }
        if (root._laidOut)
            root.scrollTo(key)
        else
            root._pendingSection = key
    }
    property string _pendingSection: ""
    property bool _laidOut: false
    property real _lastHeight: -1
    Connections {
        target: root.Window.window
        enabled: !root._laidOut
        function onFrameSwapped() {
            if (content.height <= 0 || content.height !== root._lastHeight) {
                root._lastHeight = content.height
                return
            }
            root._laidOut = true
            if (root._pendingSection === "")
                return
            const key = root._pendingSection
            root._pendingSection = ""
            root.scrollTo(key)
        }
    }

    function scrollTo(key) {
        const target = Math.min(Math.max(0, sectionItem(key).y - Theme.settingsSectionSpacing),
                                Math.max(0, flick.contentHeight - flick.height))
        scroll.to = target
        scroll.restart()
        currentSection = key
    }

    // La sección cuyo título ya pasó el borde superior; al final, la última
    function updateCurrentSection() {
        if (scroll.running)
            return
        if (flick.contentY >= flick.contentHeight - flick.height - 1) {
            currentSection = sections[sections.length - 1].key
            return
        }
        let key = sections[0].key
        for (const section of sections) {
            if (sectionItem(section.key).y - Theme.settingsSectionSpacing <= flick.contentY + 1)
                key = section.key
        }
        currentSection = key
    }

    function useCustomEngine() {
        if (!SearchEngines.setCustom(customName.text, customUrl.text)) {
            customError = true
            customUrl.forceActiveFocus()
        }
    }

    // Cada vez que se abre: arriba del todo y con el foco (para Esc)
    onOpenChanged: {
        if (!open)
            return
        scroll.stop()
        flick.contentY = 0
        currentSection = sections[0].key
        customName.text = SearchEngines.customName
        customUrl.text = SearchEngines.customUrl
        customError = false
        cleared = false
        resetPending = false
        startupField.text = Settings.startupUrl
        profileNameField.text = Settings.profileName
        refreshSitePermissions()
        BrowserProfile.refreshCacheUsage()
        forceActiveFocus()
    }

    visible: opacity > 0
    opacity: open ? 1 : 0
    enabled: open
    Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

    Keys.onEscapePressed: root.closeRequested()

    // Bloquea el ratón: nada llega a la página de debajo, tampoco el paso
    // por encima (sin hoverEnabled, la página seguía viéndolo y mostraba sus
    // avisos de enlaces sobre Configuración)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    GlassBackdrop {
        id: backdrop
        anchors.fill: parent

        ThemeBackground {
            anchors.fill: parent
        }
    }

    FileDialog {
        id: backgroundPicker
        title: "Elegir imagen de fondo"
        nameFilters: ["Imágenes (*.png *.jpg *.jpeg *.webp *.bmp)"]
        currentFolder: Core.StandardPaths.standardLocations(Core.StandardPaths.PicturesLocation)[0]
        onAccepted: Settings.newTabBackground = selectedFile.toString()
    }

    FileDialog {
        id: photoPicker
        title: "Elegir foto de perfil"
        nameFilters: ["Imágenes (*.png *.jpg *.jpeg *.webp *.bmp)"]
        currentFolder: Core.StandardPaths.standardLocations(Core.StandardPaths.PicturesLocation)[0]
        onAccepted: Settings.profilePhoto = selectedFile.toString()
    }

    FolderDialog {
        id: downloadPicker
        title: "Carpeta de descargas"
        currentFolder: Urls.fileUrl(BrowserProfile.downloadPath)
        onAccepted: Settings.downloadFolder = Urls.localPath(selectedFolder)
    }

    // ── Cabecera ─────────────────────────────────────────────────────
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.settingsHeaderHeight
        // Entra bajando un poco, como los paneles grandes
        transform: Translate {
            y: root.open ? 0 : -Theme.spacing
            Behavior on y {
                NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            }
        }

        Row {
            x: root.layoutX
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.margin

            Rectangle {
                width: Theme.settingsHeaderIconBox
                height: Theme.settingsHeaderIconBox
                radius: width / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Colors.brand1 }
                    GradientStop { position: 1.0; color: Colors.brand2 }
                }
                Icon {
                    anchors.centerIn: parent
                    name: "settings"
                    size: Theme.settingsHeaderIconSize
                    color: Colors.onBrand
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Configuración"
                color: Colors.ink
                font.pixelSize: Theme.fontSizeHeading
                font.weight: Font.Bold
            }
        }

        IconButton {
            anchors.right: parent.right
            anchors.rightMargin: Theme.margin * 2
            anchors.verticalCenter: parent.verticalCenter
            icon: "close"
            tooltip: "Cerrar"
            shortcut: "Esc"
            tooltipBelow: true
            onClicked: root.closeRequested()
        }
    }

    // ── Índice ───────────────────────────────────────────────────────
    // Lista con su propio desplazamiento: como mucho, `settingsNavHeightRatio`
    // del alto. Sigue a la sección a la vista (la mantiene en su tercio
    // central) y sus bordes se funden con el fondo (EdgeFade).
    ListView {
        id: nav
        // Encima de la lista de ajustes, que ocupa todo el ancho para
        // desplazarse con la rueda desde cualquier punto
        z: 1
        visible: root.wide
        anchors.top: header.bottom
        anchors.topMargin: Theme.margin
        x: root.layoutX
        width: Theme.settingsNavWidth
        // Deja sitio debajo al logo de Mitis, que siempre se ve
        height: Math.min(contentHeight, (root.height - header.height - Theme.margin) * Theme.settingsNavHeightRatio,
                         Math.max(0, mitisLogo.y - y - Theme.margin))
        clip: true
        spacing: Theme.spacing / 2
        boundsBehavior: Flickable.StopAtBounds
        model: root.sections
        currentIndex: root.sections.findIndex(section => section.key === root.currentSection)
        highlight: Item {}
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: height / 3
        preferredHighlightEnd: height * 2 / 3
        highlightMoveDuration: Theme.durationSlow

        delegate: Item {
            id: navRow

            required property var modelData
            readonly property bool selected: root.currentSection === modelData.key

            width: nav.width
            height: Theme.popupRowHeight

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: navRow.selected ? Colors.tintActive : (navHover.hovered ? Colors.tintHover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            // Marca de la sección a la vista
            Rectangle {
                visible: navRow.selected
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.markerWidth
                height: parent.height - Theme.spacing * 2
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Colors.brand1 }
                    GradientStop { position: 1.0; color: Colors.brand2 }
                }
            }

            Icon {
                id: navIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.margin
                anchors.verticalCenter: parent.verticalCenter
                name: navRow.modelData.icon
                color: navRow.selected ? Colors.brandLight1 : Colors.inkMuted
            }

            Text {
                anchors.left: navIcon.right
                anchors.leftMargin: Theme.spacing + Theme.spacing / 2
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: navRow.modelData.title
                color: navRow.selected ? Colors.ink : Colors.inkSecondary
                font.pixelSize: Theme.fontSize
                font.weight: navRow.selected ? Font.Bold : Font.DemiBold
                elide: Text.ElideRight
            }

            HoverHandler {
                id: navHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.scrollTo(navRow.modelData.key)
            }
        }
    }

    // La rueda sobre la columna del índice solo mueve el índice: sin esto,
    // al llegar a su final (o con el índice entero a la vista) pasaba a la
    // lista de ajustes, que ocupa todo el ancho por debajo. Recoge la rueda
    // que el índice no usa; los clics siguen llegando al índice
    MouseArea {
        visible: nav.visible
        // Entre la lista de ajustes (z 0) y el índice (z 1): el índice
        // recibe la rueda primero y esto solo se queda con la que le sobra
        z: 0.5
        x: nav.x
        y: nav.y
        width: nav.width
        height: root.height - nav.y
        acceptedButtons: Qt.NoButton
        onWheel: wheel => wheel.accepted = true
    }

    // Logo completo de Mitis (el de temas oscuros o claros), centrado en la
    // columna del índice y al pie de la ventana. Siempre visible: el índice
    // se acorta (y se desplaza) para dejarle sitio
    Image {
        id: mitisLogo
        visible: nav.visible
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.settingsSectionSpacing
        x: nav.x + (nav.width - width) / 2
        width: Theme.settingsMitisLogoWidth
        height: width * implicitHeight / Math.max(1, implicitWidth)
        source: Colors.dark ? "qrc:/branding/mitis-logo-dark.png" : "qrc:/branding/mitis-logo-light.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    // Bordes que se funden con el fondo: en el índice y, más altos, en la
    // columna de ajustes (los ajustes parecen salir del fondo y volver a él)
    EdgeFade {
        visible: nav.visible && !nav.atYBeginning
        x: nav.x
        y: nav.y
        width: nav.width
    }
    EdgeFade {
        visible: nav.visible && !nav.atYEnd
        atTop: false
        x: nav.x
        y: nav.y + nav.height - height
        width: nav.width
    }
    EdgeFade {
        visible: !flick.atYBeginning
        x: content.x - Theme.margin
        y: flick.y
        width: root.contentWidth + 2 * Theme.margin
        height: Theme.settingsContentFadeHeight
        steps: Theme.settingsContentFadeSteps
    }
    EdgeFade {
        visible: !flick.atYEnd
        atTop: false
        x: content.x - Theme.margin
        y: flick.y + flick.height - height
        width: root.contentWidth + 2 * Theme.margin
        height: Theme.settingsContentFadeHeight
        steps: Theme.settingsContentFadeSteps
    }

    // ── Secciones ────────────────────────────────────────────────────
    Flickable {
        id: flick
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        contentHeight: content.height + Theme.settingsSectionSpacing * 2
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        onContentYChanged: root.updateCurrentSection()

        NumberAnimation {
            id: scroll
            target: flick
            property: "contentY"
            duration: Theme.durationSlow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }

        Column {
            id: content
            width: root.contentWidth
            x: root.layoutX + (root.wide ? Theme.settingsNavWidth + Theme.settingsSectionSpacing : 0)
            y: Theme.margin
            spacing: Theme.settingsSectionSpacing

            SettingsSection {
                id: profileSection
                title: "Perfil"
                icon: "profile"
                description: "Cómo aparece tu perfil en Mitis. Se guarda solo en este equipo."

                // Avatar grande y nombre
                Item {
                    width: parent ? parent.width : 0
                    implicitHeight: Theme.avatarSizeLarge + 2 * Theme.margin

                    Avatar {
                        id: profileAvatar
                        x: Theme.margin + Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.avatarSizeLarge
                        name: profileNameField.text.trim()
                        photo: Settings.profilePhoto
                        colorKey: Settings.profileColor
                    }
                    Column {
                        anchors.left: profileAvatar.right
                        anchors.leftMargin: Theme.margin + Theme.spacing
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.margin + Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing / 2

                        Text {
                            text: "Nombre"
                            color: Colors.ink
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.DemiBold
                        }
                        FormField {
                            id: profileNameField
                            width: parent.width
                            placeholderText: "Tu nombre"
                            maximumLength: 40
                            onEditingFinished: Settings.profileName = text
                        }
                    }
                }
                SettingRow {
                    title: "Foto"
                    description: Settings.profilePhoto === ""
                                 ? "Sin foto se ve tu inicial sobre el color de abajo."
                                 : Urls.localPath(Settings.profilePhoto).split("/").pop()

                    TextButton {
                        visible: Settings.profilePhoto !== ""
                        text: "Quitar"
                        onClicked: Settings.profilePhoto = ""
                    }
                    TextButton {
                        text: "Elegir foto…"
                        onClicked: photoPicker.open()
                    }
                }
                AvatarColorRow {}
            }

            SettingsSection {
                id: startupSection
                title: "Al iniciar"
                icon: "reopen"

                OptionRow {
                    title: "Continuar donde lo dejaste"
                    description: "Vuelven las pestañas de la última vez. Solo carga la que estaba activa: las demás, al seleccionarlas."
                    checked: Settings.startupMode === "restore"
                    onClicked: Settings.startupMode = "restore"
                }
                OptionRow {
                    title: "Abrir una pestaña nueva"
                    description: "Con el buscador, los accesos rápidos y las noticias."
                    checked: Settings.startupMode === "newtab"
                    onClicked: Settings.startupMode = "newtab"
                }
                OptionRow {
                    title: "Abrir una página concreta"
                    description: Settings.startupUrl !== "" ? Settings.startupUrl : "Escribe su dirección debajo."
                    checked: Settings.startupMode === "page"
                    onClicked: {
                        Settings.startupMode = "page"
                        if (Settings.startupUrl === "")
                            startupField.forceActiveFocus()
                    }
                }

                // Dirección de la página de inicio
                Item {
                    visible: Settings.startupMode === "page"
                    width: parent.width
                    height: Theme.settingsRowHeight

                    FormField {
                        id: startupField
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin + Theme.spacing
                        anchors.right: useCurrent.left
                        anchors.rightMargin: Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        placeholderText: "Dirección, p. ej. duckduckgo.com"
                        onAccepted: root.saveStartupUrl()
                        onActiveFocusChanged: if (!activeFocus) root.saveStartupUrl()
                    }
                    TextButton {
                        id: useCurrent
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.margin + Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Usar la página actual"
                        enabled: /^https?:\/\//.test(root.currentPageUrl)
                        onClicked: {
                            startupField.text = root.currentPageUrl
                            root.saveStartupUrl()
                        }
                    }
                }
            }

            SettingsSection {
                id: appearanceSection
                title: "Apariencia e idioma"
                icon: "appearance"
                description: "El tema de Mitis y cómo se ven las páginas web."

                ThemeRow {}
                ChoiceRow {
                    title: "Zoom de las páginas"
                    description: "Con el que abren todas (también agranda o reduce la letra). Ctrl+0 vuelve a él."
                    options: root.zoomOptions
                    isSelected: value => Math.abs(Settings.defaultZoom - value) < 0.001
                    onChosen: value => Settings.defaultZoom = value
                }
                SettingRow {
                    title: "Modo oscuro en las páginas"
                    description: "Oscurece las páginas claras. Puede alterar los colores de algunas imágenes y gráficos."

                    Toggle {
                        checked: Settings.darkPages
                        onToggled: Settings.darkPages = checked
                    }
                }
                SettingRow {
                    title: "Ocultar la barra de desplazamiento"
                    description: "Las páginas no la muestran, pero se siguen desplazando con la rueda, el teclado o el dedo."

                    Toggle {
                        checked: Settings.hideScrollbars
                        onToggled: Settings.hideScrollbars = checked
                    }
                }
                SettingRow {
                    title: "Transparencia con desenfoque (experimental)"
                    description: "Toda la interfaz pasa a ser de vidrio: los controles, las listas, los avisos, los diálogos, la barra de título y las tarjetas y el buscador de la nueva pestaña y de Configuración dejan ver lo de detrás, difuminado, con un velo morado, y los fondos ganan manchas de color de la marca. "
                                 + (root.gpuRendering
                                    ? "Se dibuja con la GPU (" + root.graphicsApiName + "). Si se ven transparentes pero sin difuminar, apágala."
                                    : "No disponible: Mitis se está dibujando sin GPU (" + root.graphicsApiName + ").")

                    Toggle {
                        enabled: root.gpuRendering
                        checked: Settings.glassEffect && root.gpuRendering
                        onToggled: Settings.glassEffect = checked
                    }
                }
                ChoiceRow {
                    visible: Settings.glassEffect && root.gpuRendering
                    title: "Tono del velo"
                    description: "El morado que tiñe lo difuminado: lavanda (suave), violeta o profundo (más oscuro)."
                    options: Theme.glassTones
                    isSelected: value => Settings.glassTone === value
                    onChosen: value => Settings.glassTone = value
                }
                ChoiceRow {
                    title: "Idiomas de las páginas"
                    description: "Los sitios que tengan varias versiones mostrarán la primera disponible, por este orden: "
                                 + Settings.languages.map(code => root.languageName(code)).join(", ") + "."
                    options: root.languageOptions
                    isSelected: value => Settings.languages.includes(value)
                    onChosen: value => root.toggleLanguage(value)
                }
                SettingRow {
                    title: "Revisar la ortografía"
                    description: "Subraya en rojo las palabras mal escritas en español mientras escribes en las páginas. Con clic derecho sobre una, te propone cómo corregirla."

                    Toggle {
                        checked: Settings.spellCheck
                        onToggled: Settings.spellCheck = checked
                    }
                }
                ChoiceRow {
                    title: "Tamaño de los controles de abajo"
                    description: "Los botones y la barra de búsqueda de abajo (atrás, adelante, pestañas, marcadores, opciones…)."
                    options: root.controlsSizeOptions
                    isSelected: value => Settings.controlsSize === value
                    onChosen: value => Settings.controlsSize = value
                }
            }

            // Búsqueda: el buscador de la barra de dirección, la nueva pestaña
            // y el menú contextual
            SettingsSection {
                id: searchSection
                title: "Búsqueda"
                icon: "search"
                description: "El buscador que usan la barra de dirección, la página de nueva pestaña y «Buscar» del menú contextual."

                Repeater {
                    // Los incluidos y, si existe, el personalizado
                    model: SearchEngines.hasCustom
                           ? SearchEngines.engines.concat([{ key: "custom", name: SearchEngines.customName,
                                                             url: SearchEngines.customUrl }])
                           : SearchEngines.engines

                    delegate: EngineRow {}
                }

                // Buscador personalizado
                Item {
                    width: parent.width
                    height: custom.height + 2 * Theme.margin

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.margin
                        anchors.rightMargin: Theme.margin
                        height: 1
                        color: Colors.line
                    }

                    Column {
                        id: custom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Theme.margin + Theme.spacing
                        y: Theme.margin
                        spacing: Theme.spacing

                        Text {
                            text: "Personalizado"
                            color: Colors.ink
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.DemiBold
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacing

                            FormField {
                                id: customName
                                width: (parent.width - Theme.spacing) / 3
                                placeholderText: "Nombre, p. ej. Wikipedia"
                                onAccepted: root.useCustomEngine()
                            }
                            FormField {
                                id: customUrl
                                width: parent.width - customName.width - Theme.spacing
                                placeholderText: "Dirección con %s en lugar del texto"
                                onTextChanged: root.customError = false
                                onAccepted: root.useCustomEngine()
                            }
                        }

                        Item {
                            width: parent.width
                            height: Math.max(customHint.implicitHeight, saveCustom.height)

                            Text {
                                id: customHint
                                anchors.left: parent.left
                                anchors.right: saveCustom.left
                                anchors.rightMargin: Theme.margin
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.customError
                                      ? "Dirección no válida: falta el dominio o el %s"
                                      : "Ejemplo: es.wikipedia.org/w/index.php?search=%s"
                                color: root.customError ? Colors.danger : Colors.inkMuted
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.Wrap
                            }

                            TextButton {
                                id: saveCustom
                                anchors.right: parent.right
                                text: "Guardar y usar"
                                primary: true
                                enabled: customUrl.text.trim() !== ""
                                onClicked: root.useCustomEngine()
                            }
                        }
                    }
                }
            }

            SettingsSection {
                id: newTabSection
                title: "Nueva pestaña"
                icon: "new-tab"

                SettingRow {
                    divider: false
                    title: "Imagen de fondo"
                    description: Settings.newTabBackground === ""
                                 ? "La del tema"
                                 : Urls.localPath(Settings.newTabBackground).split("/").pop()

                    TextButton {
                        visible: Settings.newTabBackground !== ""
                        text: "Quitar"
                        onClicked: Settings.newTabBackground = ""
                    }
                    TextButton {
                        text: "Elegir imagen…"
                        onClicked: backgroundPicker.open()
                    }
                }
            }

            SettingsSection {
                id: privacySection
                title: "Privacidad"
                icon: "privacy"
                description: "Las ventanas privadas (Ctrl+Shift+N) no guardan historial y olvidan cookies y caché al cerrarse."

                SettingRow {
                    divider: false
                    title: "Bloquear cookies de terceros"
                    description: "Las de otros sitios dentro de la página: anuncios, rastreadores, botones de redes sociales. Algunos inicios de sesión integrados pueden fallar."

                    Toggle {
                        checked: Settings.blockThirdPartyCookies
                        onToggled: Settings.blockThirdPartyCookies = checked
                    }
                }
                SettingRow {
                    title: "Borrar cookies y caché al cerrar Mitis"
                    description: "Se cerrará la sesión en los sitios cada vez. El historial y los marcadores se conservan."

                    Toggle {
                        checked: Settings.clearOnExit
                        onToggled: Settings.clearOnExit = checked
                    }
                }
                SettingRow {
                    title: "Pedir a los sitios que no me rastreen"
                    description: "Envía las señales Do Not Track y Global Privacy Control. Cada sitio decide si las respeta."

                    Toggle {
                        checked: Settings.doNotTrack
                        onToggled: Settings.doNotTrack = checked
                    }
                }
                SettingRow {
                    title: "Ocultar mi dirección IP local"
                    description: "Las videollamadas (WebRTC) usan solo la conexión a internet y no revelan la dirección de tu red local."

                    Toggle {
                        checked: Settings.hideLocalIp
                        onToggled: Settings.hideLocalIp = checked
                    }
                }
                ChoiceRow {
                    title: "DNS cifrado"
                    description: (Settings.secureDns === "off"
                                  ? "Al abrir un sitio, Mitis pregunta su dirección a tu proveedor de internet sin cifrar: la red y el proveedor ven a qué sitios entras."
                                  : Settings.secureDns === "auto"
                                    ? "Mitis pregunta las direcciones de los sitios cifradas, a un servidor que eliges. Si no responde, usa el de tu red."
                                    : "Siempre cifrado. Si el servidor no responde, las páginas no cargan; los nombres de tu red local (impresoras, servidores de casa o de la empresa) pueden dejar de funcionar.")
                                 + (Settings.secureDns === "off" ? "" : " Vale para todas las ventanas, también las privadas.")
                    options: root.secureDnsModes
                    isSelected: value => Settings.secureDns === value
                    onChosen: value => Settings.secureDns = value
                }
                ChoiceRow {
                    visible: Settings.secureDns !== "off"
                    title: "Servidor del DNS cifrado"
                    description: Settings.secureDnsProviders.find(item => item.key === Settings.secureDnsProvider)?.detail ?? ""
                    options: Settings.secureDnsProviders.map(item => ({ value: item.key, label: item.name }))
                    isSelected: value => Settings.secureDnsProvider === value
                    onChosen: value => Settings.secureDnsProvider = value
                }
                // El motor solo lo cambia al arrancar
                SettingRow {
                    visible: Settings.secureDnsPending
                    icon: "reload"
                    title: "Se aplicará al volver a abrir Mitis"
                    description: "El DNS cifrado se elige al arrancar. Cierra Mitis y ábrelo de nuevo para usar el cambio."
                }
            }

            SettingsSection {
                id: blockerSection
                title: "Anuncios y rastreadores"
                icon: "blocker"
                description: "Se bloquean antes de descargarse: las páginas cargan antes y gastan menos memoria y datos."

                SettingRow {
                    divider: false
                    title: "Bloquear anuncios y rastreadores"
                    description: "Con EasyList, EasyPrivacy, EasyList en español y HaGeZi Pro (la lista de dominios que se usa con Pi-hole). La página que abres nunca se bloquea: solo lo que carga dentro."

                    Toggle {
                        checked: Settings.blockAds
                        onToggled: Settings.blockAds = checked
                    }
                }
                SettingRow {
                    title: "Listas de filtros"
                    description: root.filterListsStatus

                    TextButton {
                        text: BrowserProfile.adBlockUpdating ? "Actualizando…" : "Actualizar ahora"
                        enabled: Settings.blockAds && !BrowserProfile.adBlockUpdating
                        onClicked: BrowserProfile.updateFilterLists()
                    }
                }
                SettingRow {
                    title: "Quitar el rastreo de los enlaces"
                    description: "Borra de las direcciones que abres los datos que solo sirven para seguirte de un sitio a otro (utm_…, fbclid, gclid…)."

                    Toggle {
                        checked: Settings.stripTrackingParams
                        onToggled: Settings.stripTrackingParams = checked
                    }
                }
                SettingRow {
                    title: "Permitir anuncios en un sitio"
                    description: "Si una página no funciona bien, desactiva el bloqueador solo en ella."

                    TextButton {
                        visible: root.currentSite !== "" && !Settings.adBlockAllowedSites.includes(root.currentSite)
                        text: "Permitir en " + root.currentSite
                        onClicked: root.allowAdsOn(root.currentSite)
                    }
                }
                SettingRow {
                    visible: Settings.adBlockAllowedSites.length > 0
                    title: "Sitios permitidos"
                    description: (Settings.adBlockAllowedSites.length === 1
                                  ? "1 sitio: en él no se bloquea nada."
                                  : Settings.adBlockAllowedSites.length + " sitios: en ellos no se bloquea nada.")
                                 + " Se revisan y se quitan en Ajustes por sitio."

                    TextButton {
                        text: "Ver"
                        onClicked: root.scrollTo("sites")
                    }
                }
            }

            SettingsSection {
                id: securitySection
                title: "Seguridad"
                icon: "security"
                description: "Ante un certificado no válido, Mitis siempre avisa antes de abrir el sitio."

                SettingRow {
                    divider: false
                    title: "Usar conexiones seguras"
                    description: "Abre por https:// las direcciones http://. Si el sitio no lo admite, vuelve a http://. No se aplica en la red local."

                    Toggle {
                        checked: Settings.httpsUpgrade
                        onToggled: Settings.httpsUpgrade = checked
                    }
                }
                SettingRow {
                    title: "Bloquear ventanas emergentes"
                    description: "Solo se abren las que siguen a un clic tuyo."

                    Toggle {
                        checked: Settings.blockPopups
                        onToggled: Settings.blockPopups = checked
                    }
                }
                SettingRow {
                    title: "JavaScript"
                    description: "Desactivarlo reduce riesgos y memoria, pero muchas páginas dejarán de funcionar."

                    Toggle {
                        checked: Settings.javascript
                        onToggled: Settings.javascript = checked
                    }
                }
            }

            SettingsSection {
                id: permissionsSection
                title: "Permisos de sitios"
                icon: "permissions"
                description: "Lo que los sitios pueden pedirte. Bloqueado se deniega sin preguntar; lo ya decidido para un sitio se mantiene."

                Repeater {
                    model: root.permissionKinds

                    delegate: SettingRow {
                        id: kindRow

                        required property var modelData
                        required property int index
                        readonly property bool blocked: Settings.blockedPermissions.includes(modelData.kind)

                        divider: index > 0
                        icon: modelData.icon
                        title: modelData.title

                        Chip {
                            text: "Preguntar"
                            selected: !kindRow.blocked
                            onClicked: root.setPermissionBlocked(kindRow.modelData.kind, false)
                        }
                        Chip {
                            text: "Bloquear"
                            selected: kindRow.blocked
                            onClicked: root.setPermissionBlocked(kindRow.modelData.kind, true)
                        }
                    }
                }

                // Lo decidido para cada sitio está en Ajustes por sitio
                SettingRow {
                    title: "Sitios con permisos guardados"
                    description: (root.sitePermissions.length === 0 ? "Ningún sitio tiene permisos guardados."
                                : root.sitePermissions.length === 1 ? "1 permiso decidido para un sitio."
                                : root.sitePermissions.length + " permisos decididos para sitios concretos.")
                                 + (root.sitePermissions.length > 0 ? " Se revisan y se quitan en Ajustes por sitio." : "")

                    TextButton {
                        visible: root.sitePermissions.length > 0
                        text: "Ver"
                        onClicked: root.scrollTo("sites")
                    }
                }
            }

            // Lo propio de cada sitio, junto: zoom, permisos y bloqueador
            SettingsSection {
                id: sitesSection
                title: "Ajustes por sitio"
                icon: "sites"
                description: "Lo que Mitis recuerda de cada sitio: el zoom que le pusiste, los permisos que decidiste y si le permites los anuncios. Despliega un sitio para quitar algo; volverá a lo de siempre."

                SettingRow {
                    visible: root.siteSettings.length === 0
                    divider: false
                    title: "Ningún sitio tiene ajustes propios"
                    description: "Aparecerán aquí al cambiar el zoom de una página, responder a un permiso o permitir los anuncios en un sitio."
                }
                Repeater {
                    model: root.siteSettings.slice(0, root.sitesShown)

                    delegate: Column {
                        id: siteGroup

                        required property var modelData
                        required property int index
                        readonly property bool open: root.openSite === modelData.site

                        width: parent ? parent.width : 0

                        ExpandRow {
                            title: siteGroup.modelData.site
                            description: root.siteSummary(siteGroup.modelData)
                            expanded: siteGroup.open
                            onToggled: root.openSite = siteGroup.open ? "" : siteGroup.modelData.site
                        }
                        Repeater {
                            model: siteGroup.open ? siteGroup.modelData.items : []

                            delegate: SiteItemRow {
                                site: siteGroup.modelData.site
                            }
                        }
                        SettingRow {
                            visible: siteGroup.open && siteGroup.modelData.items.length > 1
                            title: "Todo lo de " + siteGroup.modelData.site
                            description: "Quita su zoom, sus permisos y los anuncios permitidos."

                            TextButton {
                                text: "Quitar todo"
                                danger: true
                                onClicked: root.forgetSite(siteGroup.modelData)
                            }
                        }
                    }
                }
                SettingRow {
                    visible: root.siteSettings.length > root.sitesShown
                    title: "Hay " + (root.siteSettings.length - root.sitesShown) + " sitios más"

                    TextButton {
                        text: "Mostrar todos"
                        onClicked: root.sitesShown = root.siteSettings.length
                    }
                }
            }

            SettingsSection {
                id: contentSection
                title: "Contenido"
                icon: "open-image"

                SettingRow {
                    divider: false
                    title: "Mostrar imágenes"
                    description: "Sin ellas las páginas cargan antes y gastan menos datos y memoria."

                    Toggle {
                        checked: Settings.images
                        onToggled: Settings.images = checked
                    }
                }
                SettingRow {
                    title: "Reproducción automática"
                    description: "Que los vídeos y el audio empiecen solos, sin que toques la página."

                    Toggle {
                        checked: Settings.autoplay
                        onToggled: Settings.autoplay = checked
                    }
                }
                SettingRow {
                    title: "Atrás y adelante con gestos y botones del ratón"
                    description: Qt.platform.os === "osx" || Qt.platform.os === "macos"
                                 ? "Deslizar en el panel táctil o el Magic Mouse (con dos o tres dedos, según «Deslizar entre páginas» en Ajustes del Sistema) y los botones laterales del ratón te llevan a la página anterior o a la siguiente."
                                 : "Los botones laterales del ratón te llevan a la página anterior o a la siguiente."

                    Toggle {
                        checked: Settings.navigationGestures
                        onToggled: Settings.navigationGestures = checked
                    }
                }
            }

            SettingsSection {
                id: historySection
                title: "Borrar datos de navegación"
                icon: "history"

                // Periodo
                Item {
                    width: parent.width
                    height: Theme.settingsRowHeight

                    Text {
                        id: periodLabel
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin + Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Borrar datos de"
                        color: Colors.ink
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.DemiBold
                    }

                    Flow {
                        anchors.left: periodLabel.right
                        anchors.leftMargin: Theme.margin
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.margin + Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        layoutDirection: Qt.RightToLeft
                        spacing: Theme.spacing

                        Repeater {
                            // Al revés: el Flow coloca de derecha a izquierda
                            model: root.clearPeriods.slice().reverse()

                            delegate: Chip {
                                required property var modelData
                                text: modelData.label
                                selected: root.clearPeriod === modelData.key
                                onClicked: root.clearPeriod = modelData.key
                            }
                        }
                    }
                }

                CheckRow {
                    title: "Historial de navegación"
                    description: "Páginas visitadas y sugerencias de la barra de dirección"
                    checked: root.clearHistory
                    onToggled: root.clearHistory = !root.clearHistory
                }
                CheckRow {
                    title: "Listado de descargas"
                    description: "Solo el listado: los archivos descargados no se borran"
                    checked: root.clearDownloads
                    onToggled: root.clearDownloads = !root.clearDownloads
                }
                CheckRow {
                    title: "Cookies"
                    description: "Se cerrará la sesión en la mayoría de los sitios. Siempre todas, sea cual sea el periodo"
                    checked: root.clearCookies
                    onToggled: root.clearCookies = !root.clearCookies
                }
                CheckRow {
                    title: "Imágenes y archivos en caché"
                    description: "Se vuelven a descargar al visitar los sitios. Siempre toda"
                    checked: root.clearCache
                    onToggled: root.clearCache = !root.clearCache
                }
                CheckRow {
                    title: "Permisos de sitios"
                    description: "Cámara, micrófono, ubicación, notificaciones…: se volverá a preguntar"
                    checked: root.clearPermissions
                    onToggled: root.clearPermissions = !root.clearPermissions
                }

                // Acción
                Item {
                    width: parent.width
                    height: Theme.settingsRowHeight

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.margin
                        anchors.rightMargin: Theme.margin
                        height: 1
                        color: Colors.line
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin + Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing
                        opacity: root.cleared ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            color: Colors.ok
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Datos borrados"
                            color: Colors.ok
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.DemiBold
                        }
                    }

                    TextButton {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.margin + Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Borrar datos"
                        danger: true
                        enabled: root.clearSomething
                        onClicked: root.clearBrowsingData()
                    }
                }
            }

            SettingsSection {
                id: downloadsSection
                title: "Descargas"
                icon: "downloads"

                SettingRow {
                    divider: false
                    title: "Carpeta de descargas"
                    description: BrowserProfile.downloadPath

                    TextButton {
                        visible: Settings.downloadFolder !== ""
                        text: "Restablecer"
                        onClicked: Settings.downloadFolder = ""
                    }
                    TextButton {
                        text: "Cambiar…"
                        onClicked: downloadPicker.open()
                    }
                }
                SettingRow {
                    title: "Preguntar dónde guardar cada archivo"
                    description: "Antes de cada descarga se elige la carpeta."

                    Toggle {
                        checked: Settings.askDownloadFolder
                        onToggled: Settings.askDownloadFolder = checked
                    }
                }
            }

            SettingsSection {
                id: performanceSection
                title: "Rendimiento"
                icon: "performance"
                description: "Para que Mitis gaste menos memoria y las páginas se abran antes."

                ChoiceRow {
                    divider: false
                    title: "Suspender las pestañas que no usas"
                    description: "A los 5 minutos sin verla, una pestaña se congela; tras el tiempo elegido, se descarga de la memoria y se vuelve a cargar al abrirla. Nunca se suspenden las fijadas, las que suenan, las que pueden mandarte notificaciones ni las que tienen un formulario a medio rellenar."
                    options: root.suspendOptions
                    isSelected: value => Settings.suspendAfter === value
                    onChosen: value => Settings.suspendAfter = value
                }
                SettingRow {
                    title: "Liberar memoria cuando el equipo va justo"
                    description: "Si al equipo le queda poca memoria, Mitis descarga antes las pestañas que llevas más tiempo sin ver, aunque no haya pasado el tiempo de arriba, hasta que se recupera. Con las mismas excepciones."

                    Toggle {
                        checked: Settings.memorySaver
                        onToggled: Settings.memorySaver = checked
                    }
                }
                ChoiceRow {
                    title: "Atrás y adelante al instante"
                    description: "Al salir de una página, Mitis la guarda tal como estaba durante 3 minutos: si vuelves con Atrás, aparece al momento, sin volver a cargarse y con lo que hubieras escrito. Cada página guardada usa algo de memoria (unos 10 MB una página sencilla). Si al equipo le queda poca memoria, deja de guardarlas."
                    options: root.instantBackOptions
                    isSelected: value => Settings.instantBackPages === value
                    onChosen: value => Settings.instantBackPages = value
                }
                // Cuántas guarda, el motor lo toma al arrancar
                SettingRow {
                    visible: Settings.instantBackPending
                    icon: "reload"
                    title: "Se aplicará al volver a abrir Mitis"
                    description: "Cuántas páginas se guardan se elige al arrancar. Cierra Mitis y ábrelo de nuevo para usar el cambio."
                }
                SettingRow {
                    title: "Precargar páginas"
                    description: "Cuando dejas el ratón un momento sobre un enlace, Mitis empieza a cargar esa página para que se abra antes al pulsarlo. Gasta algo más de datos y el sitio sabe sobre qué enlaces pasas el ratón. Nunca en las ventanas privadas."

                    Toggle {
                        checked: Settings.preloadPages
                        onToggled: Settings.preloadPages = checked
                    }
                }
                ChoiceRow {
                    title: "Espacio para la caché"
                    description: "Mitis guarda en el disco imágenes y archivos de las páginas para que vuelvan a abrirse antes. Cuando llega al límite, borra solo lo más antiguo. Con «Automático», el límite lo decide el motor según el espacio libre del disco."
                    options: root.cacheSizeOptions
                    isSelected: value => Settings.cacheSize === value
                    onChosen: value => Settings.cacheSize = value
                }
                SettingRow {
                    title: "Caché de las páginas"
                    description: BrowserProfile.cacheUsage < 0 ? "Calculando cuánto ocupa…"
                                 : "Ocupa " + root.formatSize(BrowserProfile.cacheUsage)
                                   + ". Al vaciarla no se pierde nada: las páginas solo tardarán algo más la primera vez."

                    TextButton {
                        text: "Vaciar"
                        enabled: BrowserProfile.cacheUsage > 0
                        onClicked: BrowserProfile.clearCache()
                    }
                }
            }

            SettingsSection {
                id: shortcutsSection
                title: "Atajos de teclado"
                icon: "keyboard"

                // Grupos en píldoras y flechas para pasar de uno a otro
                Item {
                    width: parent.width
                    height: Theme.settingsRowHeight

                    Flow {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin + Theme.spacing
                        anchors.right: shortcutPager.left
                        anchors.rightMargin: Theme.margin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing

                        Repeater {
                            model: root.shortcutGroups
                            delegate: Chip {
                                required property var modelData
                                required property int index
                                text: modelData.title
                                selected: root.shortcutPage === index
                                onClicked: root.shortcutPage = index
                            }
                        }
                    }

                    Row {
                        id: shortcutPager
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.margin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing / 2

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.buttonSizeSmall
                            height: Theme.buttonSizeSmall
                            flat: true
                            icon: "back"
                            iconSize: Theme.iconSizeSmall
                            tooltip: "Anteriores"
                            enabled: root.shortcutPage > 0
                            opacity: enabled ? 1 : 0.35
                            onClicked: root.shortcutPage--
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (root.shortcutPage + 1) + " de " + root.shortcutGroups.length
                            color: Colors.inkMuted
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.buttonSizeSmall
                            height: Theme.buttonSizeSmall
                            flat: true
                            icon: "forward"
                            iconSize: Theme.iconSizeSmall
                            tooltip: "Siguientes"
                            enabled: root.shortcutPage < root.shortcutGroups.length - 1
                            opacity: enabled ? 1 : 0.35
                            onClicked: root.shortcutPage++
                        }
                    }
                }

                Repeater {
                    model: root.shortcutGroups[root.shortcutPage].items
                    delegate: ShortcutRow {}
                }
            }

            SettingsSection {
                id: developerSection
                title: "Desarrollo"
                icon: "devtools"

                SettingRow {
                    divider: false
                    title: "Herramientas de desarrollo"
                    description: "Muestra «Inspeccionar» en el menú contextual y abre el panel con F12."

                    Toggle {
                        checked: Settings.devTools
                        onToggled: Settings.devTools = checked
                    }
                }
                SettingRow {
                    title: "Monitor de rendimiento"
                    description: "Muestra un panel con la memoria, la CPU y la GPU que usan Mitis y cada pestaña. Se abre y se cierra con Shift+Esc o desde el menú de opciones."

                    Toggle {
                        checked: Settings.performanceMonitor
                        onToggled: Settings.performanceMonitor = checked
                    }
                }
                SettingRow {
                    id: crashRow
                    readonly property var last: CrashReports.reports.length > 0 ? CrashReports.reports[0] : null

                    title: "Informes de cierres inesperados"
                    description: (last
                                  ? "Último: " + last.date.toLocaleString(Qt.locale(), "d MMM yyyy, HH:mm") + " · "
                                    + (last.kind === "caida" ? "caída, con la pila" : "sin pila (se colgó, se cerró a la fuerza o le faltó memoria)")
                                    + (CrashReports.reports.length > 1 ? " · " + CrashReports.reports.length + " guardados" : "")
                                  : "Ninguno.")
                                 + " Mitis guarda un registro de cada sesión; si se cierra sin despedirse, queda como informe. No se envía nada."

                    TextButton {
                        visible: crashRow.last !== null
                        text: "Copiar el último"
                        onClicked: CrashReports.copy(crashRow.last.path)
                    }
                    TextButton {
                        text: "Abrir carpeta"
                        onClicked: CrashReports.openFolder()
                    }
                }
            }

            SettingsSection {
                id: aboutSection
                title: "Acerca de Mitis"
                icon: "info"

                SettingRow {
                    divider: false
                    title: "Mitis " + Qt.application.version
                    description: "Navegador ligero con interfaz propia"
                }
                SettingRow {
                    title: "Actualizaciones"
                    description: Updates.checking ? "Buscando…"
                               : Updates.installing
                                 ? "Descargando Mitis " + Updates.available + "…"
                                   + (Updates.progress >= 0 ? " " + Math.round(Updates.progress * 100) + " %" : "")
                               : Updates.error !== "" && Updates.available !== "" && Updates.canInstall ? Updates.error
                               : Updates.available !== ""
                                 ? "Hay una versión nueva: " + Updates.available + "."
                                   + (Updates.canInstall ? " Al actualizar, Mitis se cierra y vuelve a abrirse con tus pestañas."
                                                         : " Descárgala e instálala para actualizar (o, en Linux, con el sistema de paquetes).")
                               : Updates.error !== "" ? Updates.error
                               : "Mitis busca versiones nuevas al abrirse y cada 6 horas."

                    TextButton {
                        visible: Updates.available === ""
                        enabled: !Updates.checking
                        text: "Buscar ahora"
                        onClicked: Updates.check()
                    }
                    TextButton {
                        visible: Updates.available !== "" && Updates.canInstall && !Updates.installing
                        primary: true
                        text: "Actualizar"
                        onClicked: root.updateRequested()
                    }
                }
                SettingRow {
                    title: "Motor"
                    description: BrowserProfile.chromiumVersion !== ""
                                 ? "Chromium " + BrowserProfile.chromiumVersion + " (Qt WebEngine)"
                                 : "Qt WebEngine"
                }
                SettingRow {
                    title: "Contenido protegido (Widevine)"
                    description: BrowserProfile.widevineAvailable
                                 ? "Netflix, Spotify y otros servicios con DRM pueden reproducirse."
                                 : "No se encontró. Instala Google Chrome (en Arch, también chromium-widevine) y reinicia Mitis."

                    StatusBadge {
                        ok: BrowserProfile.widevineAvailable
                        text: ok ? "Disponible" : "No disponible"
                    }
                }
                SettingRow {
                    title: "Licencias"
                    description: "Mitis es software libre (GPL-3.0). Usa Qt y Qt WebEngine (LGPL-3.0), Chromium y otros componentes de terceros, cada uno con su licencia."

                    TextButton {
                        visible: BrowserProfile.licensesPath !== ""
                        text: "Ver licencias"
                        onClicked: Qt.openUrlExternally(Urls.fileUrl(BrowserProfile.licensesPath))
                    }
                }
                SettingRow {
                    title: "Restablecer la configuración"
                    description: root.resetPending
                                 ? "Todos los ajustes volverán a sus valores de serie. ¿Continuar?"
                                 : "Vuelve a los valores de serie. Se conservan el historial, los marcadores, las cookies, los accesos rápidos y los permisos de los sitios."

                    TextButton {
                        visible: root.resetPending
                        text: "Cancelar"
                        onClicked: root.resetPending = false
                    }
                    TextButton {
                        text: root.resetPending ? "Restablecer" : "Restablecer…"
                        danger: true
                        onClicked: {
                            if (!root.resetPending) {
                                root.resetPending = true
                                return
                            }
                            Settings.resetPreferences()
                            root.resetPending = false
                        }
                    }
                }
            }
            // «by StartCode», al final de los ajustes y más pequeño
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "by"
                    color: Colors.inkMuted
                    font.pixelSize: Theme.fontSizeSmall
                }
                // Versión clara (temas oscuros) u oscura (tema Claro), sin fondo
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.settingsLogoWidth
                    height: width / 2

                    Image {
                        anchors.fill: parent
                        source: Colors.dark ? "qrc:/branding/startcode.png" : "qrc:/branding/startcode-light.png"
                        sourceSize: Qt.size(2 * width, 2 * height)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        opacity: startcodeHover.hovered ? 1 : 0.7
                        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                    }
                    HoverHandler { id: startcodeHover }
                    Tooltip {
                        text: "StartCode"
                        visible: startcodeHover.hovered
                    }
                }
            }
        }
    }

    // ── Piezas de la página ──────────────────────────────────────────

    // Franja que funde un borde con el fondo del tema: escalones del propio
    // fondo (ThemeBackground, colocado donde está el de la página) con opacidad
    // creciente hacia el borde. Debe ser hija directa de la página: x e y son
    // también las de la página. Sin shaders, así funciona también sin GPU.
    component EdgeFade: Item {
        id: fade

        // Borde de arriba (opaco arriba) o de abajo (opaco abajo)
        property bool atTop: true
        // Escalones de la franja (más en las franjas altas, para que no se noten)
        property int steps: Theme.settingsFadeSteps
        readonly property real step: height / steps

        z: 2
        height: Theme.settingsFadeHeight

        Repeater {
            model: fade.steps

            delegate: Item {
                id: slice

                required property int index

                y: index * fade.step
                width: fade.width
                height: Math.ceil(fade.step)
                clip: true
                // Curva suave (smoothstep): opaco junto al borde y se va
                // desvaneciendo sin escalón visible hacia dentro
                readonly property real t: fade.atTop ? 1 - (index + 0.5) / fade.steps
                                                     : (index + 0.5) / fade.steps
                opacity: t * t * (3 - 2 * t)

                ThemeBackground {
                    x: -fade.x
                    y: -(fade.y + slice.y)
                    width: fade.parent ? fade.parent.width : 0
                    height: fade.parent ? fade.parent.height : 0
                }
            }
        }
    }

    // Título de sección y su tarjeta; las filas van dentro de la tarjeta
    component SettingsSection: Column {
        id: section

        property string title: ""
        property string icon: ""
        property string description: ""
        default property alias rows: card.data

        width: parent ? parent.width : 0
        spacing: Theme.margin

        Row {
            spacing: Theme.spacing + Theme.spacing / 2

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: section.icon
                color: Colors.brandLight1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: section.title
                color: Colors.ink
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
            }
        }

        Text {
            visible: section.description !== ""
            width: parent.width
            text: section.description
            color: Colors.inkSecondary
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }

        Surface {
            width: parent.width
            height: card.height
            radius: Theme.radius
            fill: Colors.surfaceFloat

            Column {
                id: card
                width: parent.width
                topPadding: Theme.spacing / 2
                bottomPadding: Theme.spacing / 2
            }
        }
    }

    // Un ajuste: título y descripción a la izquierda, controles a la derecha
    component SettingRow: Item {
        id: row

        property string title: ""
        property string description: ""
        // Icono opcional a la izquierda (inkSoft)
        property string icon: ""
        // Separador con la fila anterior
        property bool divider: true
        default property alias controls: slot.data

        width: parent ? parent.width : 0
        implicitHeight: Math.max(Theme.settingsRowHeight, texts.implicitHeight + 2 * Theme.margin)

        Rectangle {
            visible: row.divider
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.margin
            anchors.rightMargin: Theme.margin
            height: 1
            color: Colors.line
        }

        Icon {
            id: rowIcon
            visible: row.icon !== ""
            anchors.left: parent.left
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            name: row.icon
            color: Colors.inkSoft
        }

        Column {
            id: texts
            anchors.left: row.icon !== "" ? rowIcon.right : parent.left
            anchors.leftMargin: row.icon !== "" ? Theme.margin : Theme.margin + Theme.spacing
            anchors.right: slot.left
            anchors.rightMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing / 4

            Text {
                width: parent.width
                text: row.title
                color: Colors.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            Text {
                visible: text !== ""
                width: parent.width
                text: row.description
                color: Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }

        Row {
            id: slot
            anchors.right: parent.right
            anchors.rightMargin: Theme.margin + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing
        }
    }

    // Fila que pliega o despliega la lista de debajo (sitios permitidos,
    // permisos guardados): título, cuántos hay y la flecha
    component ExpandRow: Item {
        id: expandRow

        property string title: ""
        property string description: ""
        property bool expandable: true
        property bool expanded: false

        signal toggled()

        width: parent ? parent.width : 0
        implicitHeight: Math.max(Theme.settingsRowHeight, expandTexts.implicitHeight + 2 * Theme.margin)

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing / 2
            anchors.rightMargin: Theme.spacing / 2
            radius: Theme.radiusSmall
            color: expandHover.hovered && expandRow.expandable ? Colors.tintHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.margin
            anchors.rightMargin: Theme.margin
            height: 1
            color: Colors.line
        }
        Column {
            id: expandTexts
            anchors.left: parent.left
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.right: expandIcon.left
            anchors.rightMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing / 4

            Text {
                width: parent.width
                text: expandRow.title
                color: Colors.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                visible: text !== ""
                width: parent.width
                text: expandRow.description
                color: Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
        }
        Icon {
            id: expandIcon
            visible: expandRow.expandable
            anchors.right: parent.right
            anchors.rightMargin: Theme.margin + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            name: "expand"
            size: Theme.iconSizeSmall
            color: Colors.inkMuted
            rotation: expandRow.expanded ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.durationFast } }
        }
        HoverHandler {
            id: expandHover
            cursorShape: expandRow.expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
        TapHandler {
            enabled: expandRow.expandable
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: expandRow.toggled()
        }
    }

    // Un buscador de la lista: pulsarlo lo elige
    component EngineRow: Item {
        id: engine

        required property var modelData
        required property int index
        readonly property bool selected: modelData.key === SearchEngines.key

        width: parent ? parent.width : 0
        height: Theme.settingsRowHeight

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing / 2
            anchors.rightMargin: Theme.spacing / 2
            radius: Theme.radiusSmall
            color: engine.selected ? Colors.tintActive : (engineHover.hovered ? Colors.tintHover : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        // Favicon sobre un círculo claro (muchos son negros)
        Rectangle {
            id: faviconBox
            anchors.left: parent.left
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.settingsIconBox
            height: Theme.settingsIconBox
            radius: width / 2
            color: favicon.visible ? Colors.faviconBackdrop : Colors.tintActive

            Image {
                id: favicon
                anchors.centerIn: parent
                width: Theme.faviconSize
                height: Theme.faviconSize
                sourceSize: Qt.size(2 * Theme.faviconSize, 2 * Theme.faviconSize)
                source: Urls.favicon(engine.modelData.url)
                asynchronous: true
                smooth: true
                mipmap: true
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }

            // Sin favicon (sin conexión): la lupa
            Icon {
                visible: !favicon.visible
                anchors.centerIn: parent
                name: "search"
                color: Colors.inkSoft
            }
        }

        Column {
            anchors.left: faviconBox.right
            anchors.leftMargin: Theme.margin
            anchors.right: radio.left
            anchors.rightMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: engine.modelData.name
                color: Colors.ink
                font.pixelSize: Theme.fontSize
                font.weight: engine.selected ? Font.Bold : Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: Urls.host(engine.modelData.url)
                color: Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        RadioMark {
            id: radio
            anchors.right: parent.right
            anchors.rightMargin: Theme.margin + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            checked: engine.selected
            hovered: engineHover.hovered
        }

        HoverHandler {
            id: engineHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: SearchEngines.select(engine.modelData.key)
        }
    }

    // Opción de un grupo de elección única: pulsar la fila la elige
    component OptionRow: Item {
        id: option

        property string title: ""
        property string description: ""
        property bool checked: false

        signal clicked()

        width: parent ? parent.width : 0
        implicitHeight: Math.max(Theme.settingsRowHeight, optionTexts.implicitHeight + 2 * Theme.margin)

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing / 2
            anchors.rightMargin: Theme.spacing / 2
            radius: Theme.radiusSmall
            color: option.checked ? Colors.tintActive : (optionHover.hovered ? Colors.tintHover : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Column {
            id: optionTexts
            anchors.left: parent.left
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.right: optionMark.left
            anchors.rightMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing / 4

            Text {
                width: parent.width
                text: option.title
                color: Colors.ink
                font.pixelSize: Theme.fontSize
                font.weight: option.checked ? Font.Bold : Font.DemiBold
                wrapMode: Text.Wrap
            }
            Text {
                width: parent.width
                text: option.description
                color: Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }

        RadioMark {
            id: optionMark
            anchors.right: parent.right
            anchors.rightMargin: Theme.margin + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            checked: option.checked
            hovered: optionHover.hovered
        }

        HoverHandler {
            id: optionHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: option.clicked()
        }
    }

    // Un ajuste con varias opciones en píldoras, debajo del título.
    // `options`: [{ value, label }]; `isSelected(value)` dice cuáles se marcan
    component ChoiceRow: Item {
        id: choice

        property string title: ""
        property string description: ""
        property bool divider: true
        property var options: []
        property var isSelected: value => false

        signal chosen(var value)

        width: parent ? parent.width : 0
        implicitHeight: choiceColumn.implicitHeight + 2 * Theme.margin

        Rectangle {
            visible: choice.divider
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.margin
            anchors.rightMargin: Theme.margin
            height: 1
            color: Colors.line
        }

        Column {
            id: choiceColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.rightMargin: Theme.margin + Theme.spacing
            y: Theme.margin
            spacing: Theme.spacing / 4

            Text {
                width: parent.width
                text: choice.title
                color: Colors.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            Text {
                visible: text !== ""
                width: parent.width
                text: choice.description
                color: Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
            // Separación con las píldoras
            Item {
                width: 1
                height: Theme.spacing / 2
            }
            Flow {
                width: parent.width
                spacing: Theme.spacing

                Repeater {
                    model: choice.options

                    delegate: Chip {
                        required property var modelData
                        text: modelData.label
                        selected: choice.isSelected(modelData.value)
                        onClicked: choice.chosen(modelData.value)
                    }
                }
            }
        }
    }

    // Un ajuste de un sitio (Ajustes por sitio): icono, qué es y cómo está;
    // la ✕, al pasar por encima, lo quita
    component SiteItemRow: Item {
        id: siteItem

        required property var modelData
        property string site: ""

        width: parent ? parent.width : 0
        height: Theme.pageRowHeight

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing / 2
            anchors.rightMargin: Theme.spacing / 2
            radius: Theme.radiusSmall
            color: siteItemHover.hovered ? Colors.tintHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Icon {
            id: siteItemIcon
            anchors.left: parent.left
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            name: siteItem.modelData.icon
            color: Colors.inkSoft
        }

        Column {
            anchors.left: siteItemIcon.right
            anchors.leftMargin: Theme.margin
            anchors.right: siteItemForget.left
            anchors.rightMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: siteItem.modelData.title
                color: Colors.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: siteItem.modelData.detail
                color: siteItem.modelData.warn ? Colors.warn : Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        IconButton {
            id: siteItemForget
            anchors.right: parent.right
            anchors.rightMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.buttonSizeSmall
            height: Theme.buttonSizeSmall
            flat: true
            icon: "close"
            iconSize: Theme.iconSizeSmall
            tooltip: siteItem.modelData.type === "zoom" ? "Quitar: volverá al zoom predeterminado"
                   : siteItem.modelData.type === "ads" ? "Volver a bloquear"
                   : "Olvidar: el sitio volverá a preguntar"
            opacity: siteItemHover.hovered ? 1 : 0
            onClicked: root.forgetSiteItem(Object.assign({ site: siteItem.site }, siteItem.modelData))
        }

        HoverHandler {
            id: siteItemHover
        }
    }

    // Color del avatar (sin foto): un círculo por color; el elegido, con anillo
    component AvatarColorRow: Item {
        width: parent ? parent.width : 0
        implicitHeight: colorColumn.implicitHeight + 2 * Theme.margin

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.margin
            anchors.rightMargin: Theme.margin
            height: 1
            color: Colors.line
        }

        Column {
            id: colorColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.rightMargin: Theme.margin + Theme.spacing
            y: Theme.margin
            spacing: Theme.spacing / 4

            Text {
                text: "Color"
                color: Colors.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: "El fondo de tu inicial cuando no hay foto."
                color: Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
            Item {
                width: 1
                height: Theme.spacing / 2
            }
            Flow {
                width: parent.width
                spacing: Theme.spacing

                Repeater {
                    model: Theme.avatarColors

                    delegate: Rectangle {
                        id: swatch

                        required property var modelData
                        readonly property bool selected: Settings.profileColor === modelData.key

                        width: Theme.buttonSize
                        height: Theme.buttonSize
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: selected ? Colors.focusRing
                                               : (swatchHover.hovered ? Colors.hairlineHover : "transparent")

                        Rectangle {
                            anchors.centerIn: parent
                            width: Theme.buttonSizeSmall
                            height: Theme.buttonSizeSmall
                            radius: width / 2
                            color: swatch.modelData.color
                        }
                        HoverHandler {
                            id: swatchHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: Settings.profileColor = swatch.modelData.key
                        }
                        Tooltip {
                            text: swatch.modelData.label
                            visible: swatchHover.hovered
                        }
                    }
                }
            }
        }
    }

    // Tema de la interfaz: una tarjeta con la vista previa de cada uno
    component ThemeRow: Item {
        width: parent ? parent.width : 0
        implicitHeight: themeColumn.implicitHeight + 2 * Theme.margin

        Column {
            id: themeColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.rightMargin: Theme.margin + Theme.spacing
            y: Theme.margin
            spacing: Theme.spacing / 4

            Text {
                width: parent.width
                text: "Tema"
                color: Colors.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: "Mitis cambia al momento. Las páginas que tienen versión oscura la usan con los temas oscuros (desde la próxima vez que abras Mitis)."
                color: Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
            // Separación con las tarjetas
            Item {
                width: 1
                height: Theme.spacing
            }
            Flow {
                width: parent.width
                spacing: Theme.spacing + Theme.spacing / 2

                Repeater {
                    model: Theme.themes

                    delegate: ThemeTile {}
                }
            }
        }
    }

    // Vista previa de un tema con sus propios colores (no los del tema en uso):
    // barra de título, una página con texto y los controles inferiores
    component ThemeTile: Item {
        id: tile

        required property var modelData
        readonly property var colors: Theme.palettes[modelData.key]
        readonly property bool selected: Theme.current === modelData.key

        width: Theme.themeTileWidth
        height: preview.height + Theme.spacing + label.height

        Rectangle {
            id: preview
            width: parent.width
            height: Theme.themeTilePreviewHeight
            radius: Theme.radiusSmall
            color: tile.colors.bgBase
            border.width: tile.selected ? 2 : 1
            border.color: tile.selected ? Colors.focusRing : (tileHover.hovered ? Colors.hairlineHover : Colors.hairline)

            // Barra de título con la marca
            Rectangle {
                id: miniTitle
                x: Theme.spacing / 2
                y: Theme.spacing / 2
                width: parent.width - Theme.spacing
                height: parent.height * 0.14
                radius: Theme.spacing / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: tile.colors.titleBarStart }
                    GradientStop { position: 1.0; color: tile.colors.titleBarEnd }
                }
                Rectangle {
                    x: height
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height * 0.6
                    height: width
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: tile.colors.brand1 }
                        GradientStop { position: 1.0; color: tile.colors.brand2 }
                    }
                }
            }
            // Una tarjeta con dos líneas de texto
            Rectangle {
                x: Theme.spacing
                anchors.top: miniTitle.bottom
                anchors.topMargin: Theme.spacing / 2
                width: parent.width * 0.6
                height: parent.height * 0.32
                radius: Theme.spacing / 2
                color: tile.colors.surfacePopup
                border.width: 1
                border.color: tile.colors.hairline

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.spacing / 2
                    spacing: Theme.spacing / 2

                    Rectangle {
                        width: tile.width * 0.38
                        height: Theme.spacing / 2
                        radius: height / 2
                        color: tile.colors.ink
                    }
                    Rectangle {
                        width: tile.width * 0.26
                        height: Theme.spacing / 2
                        radius: height / 2
                        color: tile.colors.inkMuted
                    }
                }
            }
            // Controles inferiores, con el acento de la marca
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacing / 2
                width: parent.width * 0.55
                height: parent.height * 0.16
                radius: height / 2
                border.width: 1
                border.color: tile.colors.hairline
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: tile.colors.controlsStart }
                    GradientStop { position: 1.0; color: tile.colors.controlsEnd }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.5
                    height: parent.height * 0.4
                    radius: height / 2
                    color: tile.colors.brandLight1
                }
            }
        }

        Row {
            id: label
            anchors.top: preview.bottom
            anchors.topMargin: Theme.spacing
            spacing: Theme.spacing / 2

            Icon {
                visible: tile.selected
                anchors.verticalCenter: parent.verticalCenter
                name: "check"
                size: Theme.iconSizeSmall
                color: Colors.brandLight1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tile.modelData.name
                color: tile.selected ? Colors.ink : Colors.inkSecondary
                font.pixelSize: Theme.fontSize
                font.weight: tile.selected ? Font.Bold : Font.Normal
            }
        }

        HoverHandler {
            id: tileHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: Settings.theme = tile.modelData.key
        }
    }

    // Un atajo: qué hace a la izquierda y sus teclas a la derecha
    component ShortcutRow: Item {
        id: shortcut

        required property var modelData

        width: parent ? parent.width : 0
        height: Theme.pageRowHeight

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.margin
            anchors.rightMargin: Theme.margin
            height: 1
            color: Colors.line
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.right: keysRow.left
            anchors.rightMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: shortcut.modelData.action
                color: Colors.ink
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }
            Text {
                visible: text !== ""
                width: parent.width
                text: shortcut.modelData.note ?? ""
                color: Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        // Combinaciones separadas por «o»; cada tecla, en su tecla dibujada
        Row {
            id: keysRow
            anchors.right: parent.right
            anchors.rightMargin: Theme.margin + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing

            Repeater {
                model: shortcut.modelData.keys
                delegate: Row {
                    id: combo
                    required property string modelData
                    required property int index
                    spacing: Theme.spacing / 2

                    Text {
                        visible: combo.index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: Theme.spacing / 2
                        text: "o"
                        color: Colors.inkMuted
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Repeater {
                        model: root.shortcutKeys(combo.modelData)
                        delegate: Rectangle {
                            id: key
                            required property string modelData
                            width: Math.max(Theme.buttonSizeSmall, keyText.implicitWidth + Theme.spacing * 2)
                            height: Theme.buttonSizeSmall
                            radius: Theme.radiusSmall
                            color: Colors.tintHover
                            border.width: 1
                            border.color: Colors.hairline

                            Text {
                                id: keyText
                                anchors.centerIn: parent
                                text: key.modelData
                                color: Colors.inkSecondary
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }
    }

    // Fila con casilla: pulsar en cualquier punto la marca o desmarca
    component CheckRow: Item {
        id: check

        property string title: ""
        property string description: ""
        property bool checked: false

        signal toggled()

        width: parent ? parent.width : 0
        implicitHeight: Math.max(Theme.settingsRowHeight, checkTexts.implicitHeight + 2 * Theme.margin)

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing / 2
            anchors.rightMargin: Theme.spacing / 2
            radius: Theme.radiusSmall
            color: checkHover.hovered ? Colors.tintHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        CheckMark {
            id: mark
            anchors.left: parent.left
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            checked: check.checked
            hovered: checkHover.hovered
        }

        Column {
            id: checkTexts
            anchors.left: mark.right
            anchors.leftMargin: Theme.margin
            anchors.right: parent.right
            anchors.rightMargin: Theme.margin + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing / 4

            Text {
                width: parent.width
                text: check.title
                color: Colors.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            Text {
                width: parent.width
                text: check.description
                color: Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
        }

        HoverHandler {
            id: checkHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: check.toggled()
        }
    }

    // Opción de un grupo de elección única, en píldora (p. ej. el periodo)
    component Chip: Rectangle {
        id: chip

        property string text: ""
        property bool selected: false

        signal clicked()

        width: chipText.implicitWidth + 2 * Theme.margin
        height: Theme.buttonSizeSmall + Theme.spacing / 2
        radius: height / 2
        color: chip.selected ? Colors.tintActive : (chipHover.hovered ? Colors.tintHover : "transparent")
        border.width: 1
        border.color: chip.selected ? Colors.brandLight1 : (chipHover.hovered ? Colors.hairlineHover : Colors.hairline)
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.text
            color: chip.selected ? Colors.ink : Colors.inkSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.weight: chip.selected ? Font.Bold : Font.DemiBold
        }

        HoverHandler {
            id: chipHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: chip.clicked()
        }
    }

    // Estado en una píldora: correcto (ok) o aviso (warn)
    component StatusBadge: Rectangle {
        id: badge

        property bool ok: true
        property string text: ""

        width: badgeText.implicitWidth + 2 * Theme.margin
        height: Theme.buttonSizeSmall
        radius: height / 2
        color: "transparent"
        border.width: 1
        border.color: badge.ok ? Colors.ok : Colors.warn

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: badge.text
            color: badge.ok ? Colors.ok : Colors.warn
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
        }
    }
}

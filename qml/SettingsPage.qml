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
    // Página de la pestaña activa (para «Usar la página actual» al iniciar)
    property string currentPageUrl: ""

    signal closeRequested()

    // Secciones del índice, en el orden de la página
    readonly property var sections: [
        { key: "startup", title: "Al iniciar", icon: "reopen" },
        { key: "appearance", title: "Apariencia e idioma", icon: "appearance" },
        { key: "search", title: "Búsqueda", icon: "search" },
        { key: "newtab", title: "Nueva pestaña", icon: "new-tab" },
        { key: "privacy", title: "Privacidad", icon: "privacy" },
        { key: "security", title: "Seguridad", icon: "security" },
        { key: "permissions", title: "Permisos de sitios", icon: "permissions" },
        { key: "content", title: "Contenido", icon: "open-image" },
        { key: "history", title: "Borrar datos", icon: "history" },
        { key: "downloads", title: "Descargas", icon: "downloads" },
        { key: "developer", title: "Desarrollo", icon: "devtools" },
        { key: "about", title: "Acerca de Mitis", icon: "info" }
    ]

    // ── Opciones de los ajustes ──────────────────────────────────────
    readonly property var zoomOptions: [
        { value: 0.8, label: "80 %" }, { value: 0.9, label: "90 %" }, { value: 1, label: "100 %" },
        { value: 1.1, label: "110 %" }, { value: 1.25, label: "125 %" }, { value: 1.5, label: "150 %" }
    ]
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

    // Página al iniciar: lo escrito → dirección ("" = ninguna)
    function saveStartupUrl() {
        Settings.startupUrl = startupField.text.trim() === "" ? "" : SearchEngines.resolve(startupField.text)
        startupField.text = Settings.startupUrl
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
        case "startup": return startupSection
        case "appearance": return appearanceSection
        case "search": return searchSection
        case "newtab": return newTabSection
        case "privacy": return privacySection
        case "security": return securitySection
        case "permissions": return permissionsSection
        case "content": return contentSection
        case "history": return historySection
        case "downloads": return downloadsSection
        case "developer": return developerSection
        case "about": return aboutSection
        default: return startupSection
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
        refreshSitePermissions()
        forceActiveFocus()
    }

    visible: opacity > 0
    opacity: open ? 1 : 0
    enabled: open
    Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

    Keys.onEscapePressed: root.closeRequested()

    // Bloquea el ratón: nada llega a la página de debajo
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    ThemeBackground {
        anchors.fill: parent
    }

    FileDialog {
        id: backgroundPicker
        title: "Elegir imagen de fondo"
        nameFilters: ["Imágenes (*.png *.jpg *.jpeg *.webp *.bmp)"]
        currentFolder: Core.StandardPaths.standardLocations(Core.StandardPaths.PicturesLocation)[0]
        onAccepted: Settings.newTabBackground = selectedFile.toString()
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
                width: Theme.settingsIconBox
                height: Theme.settingsIconBox
                radius: width / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.brand1 }
                    GradientStop { position: 1.0; color: Theme.brand2 }
                }
                Icon {
                    anchors.centerIn: parent
                    name: "settings"
                    color: Theme.onBrand
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Configuración"
                color: Theme.ink
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
    Column {
        id: nav
        // Encima de la lista, que ocupa todo el ancho para desplazarse con la
        // rueda desde cualquier punto
        z: 1
        visible: root.wide
        anchors.top: header.bottom
        anchors.topMargin: Theme.margin
        x: root.layoutX
        width: Theme.settingsNavWidth
        spacing: Theme.spacing / 2

        Repeater {
            model: root.sections

            delegate: Item {
                id: navRow

                required property var modelData
                readonly property bool selected: root.currentSection === modelData.key

                width: nav.width
                height: Theme.popupRowHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: navRow.selected ? Theme.tintActive : (navHover.hovered ? Theme.tintHover : "transparent")
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
                        GradientStop { position: 0.0; color: Theme.brand1 }
                        GradientStop { position: 1.0; color: Theme.brand2 }
                    }
                }

                Icon {
                    id: navIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    name: navRow.modelData.icon
                    color: navRow.selected ? Theme.brandLight1 : Theme.inkMuted
                }

                Text {
                    anchors.left: navIcon.right
                    anchors.leftMargin: Theme.spacing + Theme.spacing / 2
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: navRow.modelData.title
                    color: navRow.selected ? Theme.ink : Theme.inkSecondary
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
                description: "Cómo se ven las páginas web. La interfaz de Mitis no cambia."

                ChoiceRow {
                    divider: false
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
                ChoiceRow {
                    title: "Idiomas de las páginas"
                    description: "Los sitios que tengan varias versiones mostrarán la primera disponible, por este orden: "
                                 + Settings.languages.map(code => root.languageName(code)).join(", ") + "."
                    options: root.languageOptions
                    isSelected: value => Settings.languages.includes(value)
                    onChosen: value => root.toggleLanguage(value)
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
                        color: Theme.line
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
                            color: Theme.ink
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
                                color: root.customError ? Theme.danger : Theme.inkMuted
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

                // Lo decidido para cada sitio
                Item {
                    width: parent.width
                    height: savedTitle.implicitHeight + Theme.margin + Theme.spacing

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.margin
                        anchors.rightMargin: Theme.margin
                        height: 1
                        color: Theme.line
                    }
                    Text {
                        id: savedTitle
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin + Theme.spacing
                        anchors.bottom: parent.bottom
                        text: "Decidido para cada sitio"
                        color: Theme.inkSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                    }
                }
                Text {
                    visible: root.sitePermissions.length === 0
                    width: parent.width
                    height: Theme.settingsRowHeight
                    leftPadding: Theme.margin + Theme.spacing
                    verticalAlignment: Text.AlignVCenter
                    text: "Ningún sitio tiene permisos guardados."
                    color: Theme.inkMuted
                    font.pixelSize: Theme.fontSizeSmall
                }
                Repeater {
                    model: root.sitePermissions

                    delegate: SitePermissionRow {}
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
                        color: Theme.ink
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
                        color: Theme.line
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
                            color: Theme.ok
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Datos borrados"
                            color: Theme.ok
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
        }
    }

    // ── Piezas de la página ──────────────────────────────────────────

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
                color: Theme.brandLight1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: section.title
                color: Theme.ink
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
            }
        }

        Text {
            visible: section.description !== ""
            width: parent.width
            text: section.description
            color: Theme.inkSecondary
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }

        Rectangle {
            width: parent.width
            height: card.height
            radius: Theme.radius
            color: Theme.surfaceFloat
            border.width: 1
            border.color: Theme.hairline

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
            color: Theme.line
        }

        Icon {
            id: rowIcon
            visible: row.icon !== ""
            anchors.left: parent.left
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            name: row.icon
            color: Theme.inkSoft
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
                color: Theme.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            Text {
                visible: text !== ""
                width: parent.width
                text: row.description
                color: Theme.inkMuted
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
            color: engine.selected ? Theme.tintActive : (engineHover.hovered ? Theme.tintHover : "transparent")
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
            color: favicon.visible ? Theme.faviconBackdrop : Theme.tintActive

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
                color: Theme.inkSoft
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
                color: Theme.ink
                font.pixelSize: Theme.fontSize
                font.weight: engine.selected ? Font.Bold : Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: Urls.host(engine.modelData.url)
                color: Theme.inkMuted
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
            color: option.checked ? Theme.tintActive : (optionHover.hovered ? Theme.tintHover : "transparent")
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
                color: Theme.ink
                font.pixelSize: Theme.fontSize
                font.weight: option.checked ? Font.Bold : Font.DemiBold
                wrapMode: Text.Wrap
            }
            Text {
                width: parent.width
                text: option.description
                color: Theme.inkMuted
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
            color: Theme.line
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
                color: Theme.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            Text {
                visible: text !== ""
                width: parent.width
                text: choice.description
                color: Theme.inkMuted
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

    // Un permiso decidido para un sitio: sitio, permiso y respuesta; olvidar
    component SitePermissionRow: Item {
        id: site

        required property var modelData
        readonly property var info: root.permissionInfo(modelData.kind)

        width: parent ? parent.width : 0
        height: Theme.pageRowHeight

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing / 2
            anchors.rightMargin: Theme.spacing / 2
            radius: Theme.radiusSmall
            color: siteHover.hovered ? Theme.tintHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Icon {
            id: siteIcon
            anchors.left: parent.left
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            name: site.info.icon
            color: Theme.inkSoft
        }

        Column {
            anchors.left: siteIcon.right
            anchors.leftMargin: Theme.margin
            anchors.right: forget.left
            anchors.rightMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: site.modelData.origin.replace(/^https?:\/\//, "").replace(/\/$/, "")
                color: Theme.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: site.info.title + " · " + (site.modelData.allowed ? "Permitido" : "Bloqueado")
                color: site.modelData.allowed ? Theme.inkMuted : Theme.warn
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        IconButton {
            id: forget
            anchors.right: parent.right
            anchors.rightMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.buttonSizeSmall
            height: Theme.buttonSizeSmall
            flat: true
            icon: "close"
            iconSize: Theme.iconSizeSmall
            tooltip: "Olvidar: el sitio volverá a preguntar"
            opacity: siteHover.hovered ? 1 : 0
            onClicked: {
                BrowserProfile.forgetSitePermission(site.modelData.origin, site.modelData.kind)
                root.refreshSitePermissions()
            }
        }

        HoverHandler {
            id: siteHover
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
            color: checkHover.hovered ? Theme.tintHover : "transparent"
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
                color: Theme.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            Text {
                width: parent.width
                text: check.description
                color: Theme.inkMuted
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
        color: chip.selected ? Theme.tintActive : (chipHover.hovered ? Theme.tintHover : "transparent")
        border.width: 1
        border.color: chip.selected ? Theme.brandLight1 : (chipHover.hovered ? Theme.hairlineHover : Theme.hairline)
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.text
            color: chip.selected ? Theme.ink : Theme.inkSecondary
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
        border.color: badge.ok ? Theme.ok : Theme.warn

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: badge.text
            color: badge.ok ? Theme.ok : Theme.warn
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
        }
    }
}

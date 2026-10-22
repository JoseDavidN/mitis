import QtQuick
import QtWebEngine

import "urls.js" as Urls

// Una pestaña: la página web y todo lo que la interfaz necesita de ella.
// Es, con BrowserProfile.qml, el único archivo que conoce el motor (Qt
// WebEngine). Para cambiar de motor basta con reescribir estos dos archivos
// manteniendo esta interfaz; el resto de Mitis no se toca.
//
// Las propiedades son alias del motor: no cuestan nada en ejecución.
Item {
    id: root

    // Dirección que se carga al crear la pestaña; vacía = página de nueva pestaña
    property string initialUrl: ""

    // ── Estado de la página ──────────────────────────────────────────
    readonly property alias url: view.url
    readonly property alias title: view.title
    readonly property alias icon: view.icon
    readonly property alias loading: view.loading
    readonly property alias loadProgress: view.loadProgress
    readonly property alias canGoBack: view.canGoBack
    readonly property alias canGoForward: view.canGoForward
    // Suena ahora (o hace un momento)
    readonly property alias audible: view.recentlyAudible
    property alias muted: view.audioMuted

    // Buscar en la página: coincidencias de la última búsqueda y cuál está
    // seleccionada (1..findMatches; 0 si no hay)
    readonly property alias findMatches: findState.matches
    readonly property alias findActive: findState.active

    // Zoom de esta pestaña (1 = 100 %). Se mantiene al navegar dentro de ella.
    // Para cambiarlo, setZoom().
    readonly property alias zoom: zoomState.level

    // La página está en pantalla completa (p. ej. el botón de un vídeo)
    readonly property alias pageFullScreen: view.isFullScreen

    // ── Peticiones de la página ──────────────────────────────────────
    // Quiere abrir algo en una pestaña nueva (enlace con clic central,
    // target=_blank, window.open...). `request` es opaco: quien cree la
    // pestaña nueva se lo pasa a su adopt().
    signal newTabRequested(bool background, var request)
    // La página pidió cerrarse (window.close())
    signal closeRequested()
    // La página entra (`on`) o sale de pantalla completa. Ya está aceptado:
    // mientras dure, la página debería ocupar toda la ventana.
    signal pageFullScreenRequested(bool on)
    // Clic derecho en la página (el menú del motor no se muestra). `info`:
    // { x, y (coordenadas de la pestaña), linkUrl, linkText, mediaUrl,
    //   mediaType ("image", "video", "audio" o ""), selectedText, editable,
    //   canUndo, canRedo, canCut, canCopy, canPaste, canSelectAll }
    signal contextMenuRequested(var info)
    // La página abre un diálogo (alert, confirm, prompt, o el aviso de salir
    // con cambios sin guardar). Espera respuesta: hay que llamar a una de
    // las dos funciones exactamente una vez. `dialog`:
    // { type ("alert", "confirm", "prompt" o "beforeunload"), message,
    //   defaultText (prompt), origin (dominio que lo pide; "" si no tiene),
    //   accept(text), reject() }
    // Pueden llegar varios seguidos (de varios marcos): se responden en orden.
    signal javaScriptDialogRequested(var dialog)
    // Ese diálogo ya está respondido (se empezó a cargar otra página y se
    // canceló, como en Chrome): hay que cerrarlo sin responder
    signal javaScriptDialogCancelled(var dialog)
    // La página pide elegir archivos (<input type=file>, showOpenFilePicker…).
    // `dialog`: { multiple, folder (elegir una carpeta), save (guardar como),
    //   defaultName, filters (patrones: ["*.png", "*.jpg"]; vacío = todos),
    //   accept(urls), reject() }
    signal fileDialogRequested(var dialog)
    // La página pide un permiso. Solo llega lo que hay que preguntar: lo ya
    // decidido lo aplica el motor (BrowserProfile guarda las respuestas).
    // `permission`: { kind, origin (URL del sitio que lo pide), remembered
    // (la respuesta se guarda para ese sitio), grant(), deny(), dismiss() }.
    // kind: "camera", "microphone", "cameraMicrophone", "screen",
    // "screenAudio", "location", "notifications", "clipboard" o "fonts".
    // dismiss() deniega sin guardar nada: para descartar la petición cuando
    // el usuario no llegó a responder (la página cambió o se cerró).
    signal permissionRequested(var permission)
    // El certificado de la página no es válido: la carga queda en espera hasta
    // que se responda. `error`: { url, host, reason (motivo en español),
    // overridable (si se puede continuar), proceed(), reject(), back() }.
    // reject() deja la página de error del motor; back() además vuelve a la
    // página anterior, si la hay (la opción segura del aviso). Mientras
    // espera, certificateErrorPending es true; vuelve a false al responder o
    // si la espera se anula (otra navegación, pestaña cerrada: se rechaza).
    // Un host aceptado no vuelve a preguntar en toda la sesión.
    signal certificateErrorRequested(var error)
    // La página pidió contenido protegido (Widevine: Netflix, Spotify…) y el
    // motor no lo tiene. Solo llega si falta Widevine; la página sigue sin
    // poder reproducirlo (ver BrowserProfile.widevineAvailable).
    signal protectedContentUnavailable()
    readonly property bool certificateErrorPending: certState.pending !== null
    // La página actual es de un host cuyo certificado inválido se aceptó
    readonly property bool certificateBypassed: BrowserProfile.certificateExceptions[root._hostOf(view.url.toString())] === true

    // ── Acciones ─────────────────────────────────────────────────────
    function navigate(target) {
        root._cancelCertificateError()
        view.url = target
    }
    function goBack() {
        root._cancelCertificateError()
        view.goBack()
    }
    function goForward() {
        root._cancelCertificateError()
        view.goForward()
    }
    function reload() {
        root._cancelCertificateError()
        view.reload()
    }
    function stop() {
        view.stop()
    }
    // Da el foco del teclado a la página
    function focusPage() {
        view.forceActiveFocus()
    }
    // Busca `text` en la página y salta a la coincidencia siguiente (o la
    // anterior, con `backward`). Repetir la búsqueda avanza por ellas.
    function find(text, backward) {
        if (text === "") {
            stopFind()
            return
        }
        view.findText(text, backward ? WebEngineView.FindBackward : 0)
    }
    // Quita el resaltado de la búsqueda
    function stopFind() {
        view.findText("")
        findState.matches = 0
        findState.active = 0
    }
    // Cambia el zoom de esta pestaña (1 = 100 %)
    function setZoom(level) {
        zoomState.level = level
        view.zoomFactor = level
    }
    // Saca la página de pantalla completa sin esperar a que ella responda
    function exitFullScreen() {
        if (view.isFullScreen)
            view.fullScreenCancelled()
    }
    // Carga en esta pestaña lo que otra pidió abrir (ver newTabRequested)
    function adopt(request) {
        request.openIn(view)
    }

    // ── Menú contextual ──────────────────────────────────────────────
    // Acciones del motor por nombre neutral; actúan sobre lo que había bajo
    // el último clic derecho (enlace, imagen, campo…). Las descargas que
    // provocan las gestiona BrowserProfile como cualquier otra.
    readonly property var _webActions: ({
        back: WebEngineView.Back,
        forward: WebEngineView.Forward,
        reload: WebEngineView.Reload,
        undo: WebEngineView.Undo,
        redo: WebEngineView.Redo,
        cut: WebEngineView.Cut,
        copy: WebEngineView.Copy,
        paste: WebEngineView.Paste,
        selectAll: WebEngineView.SelectAll,
        copyLink: WebEngineView.CopyLinkToClipboard,
        saveLink: WebEngineView.DownloadLinkToDisk,
        copyImage: WebEngineView.CopyImageToClipboard,
        copyImageUrl: WebEngineView.CopyImageUrlToClipboard,
        saveImage: WebEngineView.DownloadImageToDisk,
        copyMediaUrl: WebEngineView.CopyMediaUrlToClipboard,
        saveMedia: WebEngineView.DownloadMediaToDisk,
        savePage: WebEngineView.SavePage,
        // Requiere las herramientas de desarrollo abiertas (openDevTools)
        inspect: WebEngineView.InspectElement
    })
    function runAction(name) {
        const action = _webActions[name]
        if (action !== undefined)
            view.triggerWebAction(action)
    }

    // ── Herramientas de desarrollo ───────────────────────────────────
    // La interfaz pone la ventana; la pestaña pone dentro la vista del motor
    // (otra página web: el panel de DevTools de Chromium). Solo existe
    // mientras está abierta: cerrarla libera su proceso.
    function openDevTools(container) {
        if (devTools.item)
            devTools.item.parent = container
        else {
            devTools.item = devToolsView.createObject(container)
            devTools.item.inspectedView = view
        }
    }
    function closeDevTools() {
        if (!devTools.item)
            return
        devTools.item.destroy()
        devTools.item = null
    }

    // ── Multimedia (assets/scripts/media.js) ─────────────────────────
    // `done(estado)`: { title, artist, playing, hasNext, hasPrevious } o null
    function mediaState(done) {
        view.runJavaScript("window.__mitisMedia ? window.__mitisMedia.state() : null",
                           result => done(result ?? null))
    }
    // `action`: "toggle", "next" o "previous"
    function mediaControl(action, done) {
        view.runJavaScript("window.__mitisMedia ? window.__mitisMedia.control('" + action + "') : null",
                           result => done(result ?? null))
    }

    // ── Certificados inválidos ───────────────────────────────────────
    // Motivo en español por tipo de error (nunca el texto en inglés del motor)
    readonly property var _certificateReasons: ({
        [WebEngineCertificateError.CertificateCommonNameInvalid]:
            "El certificado pertenece a otro sitio: no corresponde a esta dirección.",
        [WebEngineCertificateError.CertificateDateInvalid]:
            "El certificado ha caducado o aún no es válido. Si la fecha y la hora de tu equipo no son correctas, corrígelas.",
        [WebEngineCertificateError.CertificateAuthorityInvalid]:
            "El certificado no lo emitió una autoridad de confianza: puede ser autofirmado o falso.",
        [WebEngineCertificateError.CertificateContainsErrors]:
            "El certificado contiene errores.",
        [WebEngineCertificateError.CertificateNoRevocationMechanism]:
            "El certificado no indica cómo comprobar si ha sido revocado.",
        [WebEngineCertificateError.CertificateUnableToCheckRevocation]:
            "No se ha podido comprobar si el certificado ha sido revocado.",
        [WebEngineCertificateError.CertificateRevoked]:
            "El certificado ha sido revocado por quien lo emitió.",
        [WebEngineCertificateError.CertificateInvalid]:
            "El certificado no es válido.",
        [WebEngineCertificateError.CertificateWeakSignatureAlgorithm]:
            "El certificado usa un algoritmo de firma inseguro.",
        [WebEngineCertificateError.CertificateNonUniqueName]:
            "El certificado es para un nombre de red interna, que no identifica a un único sitio.",
        [WebEngineCertificateError.CertificateWeakKey]:
            "El certificado usa una clave demasiado débil.",
        [WebEngineCertificateError.CertificateNameConstraintViolation]:
            "Quien emitió el certificado no está autorizado para este nombre.",
        [WebEngineCertificateError.CertificateValidityTooLong]:
            "El certificado es válido durante demasiado tiempo para ser de confianza.",
        [WebEngineCertificateError.CertificateTransparencyRequired]:
            "El certificado no figura en los registros públicos de certificados.",
        [WebEngineCertificateError.CertificateSymantecLegacy]:
            "El certificado lo emitió una autoridad antigua (Symantec) en la que ya no se confía.",
        [WebEngineCertificateError.CertificateKnownInterceptionBlocked]:
            "El certificado es de un programa conocido por espiar conexiones.",
        [WebEngineCertificateError.SslPinnedKeyNotInCertificateChain]:
            "El certificado no es el que este sitio declara usar."
    })

    // Host completo de una dirección ("https://www.a.com:8443/x" → "www.a.com")
    function _hostOf(address) {
        const match = /^[a-z][a-z0-9+.-]*:\/\/(?:[^\/@?#]*@)?(\[[^\]]*\]|[^\/:?#]+)/i.exec(address)
        return match ? match[1].toLowerCase() : ""
    }

    // Rechaza el aviso pendiente (la pestaña va a otra parte o se cierra)
    function _cancelCertificateError() {
        if (certState.pending)
            certState.pending.reject()
    }

    QtObject {
        id: certState
        // Objeto del motor en espera de respuesta; guardarlo aquí evita además
        // que el recolector de JS lo destruya (lo que lo rechazaría)
        property var pending: null
        // Volver atrás en cuanto termine la página de error (back())
        property bool backAfterError: false
    }

    Component.onDestruction: root._cancelCertificateError()

    QtObject {
        id: devTools
        property Item item: null
    }

    Component {
        id: devToolsView

        WebEngineView {
            anchors.fill: parent
            profile: BrowserProfile
            // Los colores, de Theme: el script solo los aplica
            onLoadingChanged: info => {
                if (info.status !== WebEngineLoadingInfo.LoadSucceededStatus)
                    return
                const css = color => "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + ","
                                     + Math.round(color.b * 255) + "," + color.a + ")"
                const colors = {
                    bg: css(Theme.devtoolsBg),
                    surface: css(Theme.devtoolsSurface),
                    surfaceHover: css(Theme.devtoolsSurfaceHover),
                    line: css(Theme.devtoolsLine),
                    ink: css(Theme.devtoolsInk),
                    inkSoft: css(Theme.devtoolsInkSoft),
                    accent: css(Theme.devtoolsAccent),
                    onAccent: css(Theme.devtoolsOnAccent)
                }
                runJavaScript("window.__mitisDevToolsTheme && window.__mitisDevToolsTheme(" + JSON.stringify(colors) + ")")
            }
            // El panel de Chromium en oscuro, negro y con letra gruesa
            // (assets/scripts/devtools.js). Solo en esta vista, no en las páginas.
            Component.onCompleted: {
                const script = WebEngine.script()
                script.name = "mitis-devtools"
                script.sourceUrl = "qrc:/scripts/devtools.js"
                script.injectionPoint = WebEngineScript.DocumentReady
                script.worldId = WebEngineScript.MainWorld
                userScripts.insert(script)
            }
        }
    }

    QtObject {
        id: zoomState
        property real level: 1
    }

    // Diálogos JavaScript sin responder
    QtObject {
        id: dialogState
        property var pending: []
        // Lo quita de pendientes; false si ya estaba respondido
        function settle(dialog) {
            if (!pending.includes(dialog))
                return false
            pending = pending.filter(item => item !== dialog)
            return true
        }
    }

    QtObject {
        id: findState
        property int matches: 0
        property int active: 0
    }

    WebEngineView {
        id: view
        anchors.fill: parent
        profile: BrowserProfile
        // Visor de PDF integrado (también lo esperan algunos sitios: un
        // navegador sin él parece un motor embebido)
        settings.pluginsEnabled: true
        settings.pdfViewerEnabled: true
        // Sin esto el motor rechaza la pantalla completa de vídeos y páginas
        settings.fullScreenSupportEnabled: true

        onFindTextFinished: result => {
            findState.matches = result.numberOfMatches
            findState.active = result.activeMatch
        }
        // El motor puede volver al 100 % al cambiar de página: el zoom es de
        // la pestaña, así que se vuelve a aplicar. Con la página ya cargada,
        // un cambio es del usuario (p. ej. Ctrl+rueda) y se acepta.
        onZoomFactorChanged: {
            if (Math.abs(view.zoomFactor - zoomState.level) <= 0.001)
                return
            if (view.loading)
                view.zoomFactor = zoomState.level
            else
                zoomState.level = view.zoomFactor
        }
        onLoadingChanged: loadingInfo => {
            if (!view.loading && certState.backAfterError) {
                certState.backAfterError = false
                if (view.canGoBack)
                    view.goBack()
            }
            if (!view.loading && Math.abs(view.zoomFactor - zoomState.level) > 0.001)
                view.zoomFactor = zoomState.level
            // Al cargar otra página se cancelan los diálogos de la anterior:
            // mientras esperan, la página está bloqueada y la carga no avanza.
            // El de salir no, que es justo el que decide si se carga.
            if (loadingInfo.status === WebEngineView.LoadStartedStatus) {
                for (const dialog of dialogState.pending.slice()) {
                    if (dialog.type !== "beforeunload") {
                        dialog.reject()
                        root.javaScriptDialogCancelled(dialog)
                    }
                }
            }
        }

        // Otra página: las coincidencias anteriores ya no valen
        onUrlChanged: {
            findState.matches = 0
            findState.active = 0
        }

        // Chromium decide el destino según el clic:
        //  · central o Ctrl+clic → InNewBackgroundTab: segundo plano
        //  · Ctrl+Mayús+clic, target=_blank → InNewTab: primer plano
        //  · Mayús+clic → InNewWindow; window.open → InNewDialog/InNewWindow.
        //    Mitis aún no tiene varias ventanas: de momento, primer plano.
        onNewWindowRequested: request => {
            root.newTabRequested(request.destination === WebEngineNewWindowRequest.InNewBackgroundTab,
                                 request)
        }
        onWindowCloseRequested: root.closeRequested()

        // Certificado inválido: se aplaza y la interfaz decide. Los errores de
        // recursos de la página (no del marco principal) se rechazan sin
        // preguntar, como hace Chrome.
        onCertificateError: error => {
            if (!error.isMainFrame) {
                error.rejectCertificate()
                return
            }
            root._cancelCertificateError()
            error.defer()
            const host = root._hostOf(error.url.toString())
            let answered = false
            const request = {
                url: error.url.toString(),
                host: host,
                reason: root._certificateReasons[error.type] ?? "El certificado del sitio no es válido.",
                overridable: error.overridable,
                proceed() {
                    if (answered || !error.overridable)
                        return
                    answered = true
                    certState.pending = null
                    const exceptions = Object.assign({}, BrowserProfile.certificateExceptions)
                    exceptions[host] = true
                    BrowserProfile.certificateExceptions = exceptions
                    error.acceptCertificate()
                },
                reject() {
                    if (answered)
                        return
                    answered = true
                    certState.pending = null
                    error.rejectCertificate()
                },
                back() {
                    if (answered)
                        return
                    // Al rechazar, el motor añade al historial la página de
                    // error: hay que volver cuando termine de cargarla
                    certState.backAfterError = true
                    this.reject()
                }
            }
            certState.pending = request
            root.certificateErrorRequested(request)
        }
        // Pantalla completa: se acepta siempre; la ventana la decide Main.qml
        // Aviso de assets/scripts/drm.js
        onJavaScriptConsoleMessage: (level, message) => {
            if (message === "mitis:widevine-unavailable")
                root.protectedContentUnavailable()
        }
        onFullScreenRequested: request => {
            request.accept()
            root.pageFullScreenRequested(request.toggleOn)
        }

        // Permisos: se traducen a datos neutrales para PermissionDialog
        onPermissionRequested: permission => {
            const type = permission.permissionType
            // Bloquear el ratón (juegos, visores 3D): el motor solo lo permite
            // tras un clic del usuario y Esc lo suelta siempre, así que
            // preguntar no protege de nada. Se concede sin diálogo, como Chrome.
            if (type === WebEnginePermission.PermissionType.MouseLock) {
                permission.grant()
                return
            }
            const kinds = {
                [WebEnginePermission.PermissionType.MediaVideoCapture]: "camera",
                [WebEnginePermission.PermissionType.MediaAudioCapture]: "microphone",
                [WebEnginePermission.PermissionType.MediaAudioVideoCapture]: "cameraMicrophone",
                [WebEnginePermission.PermissionType.DesktopVideoCapture]: "screen",
                [WebEnginePermission.PermissionType.DesktopAudioVideoCapture]: "screenAudio",
                [WebEnginePermission.PermissionType.Geolocation]: "location",
                [WebEnginePermission.PermissionType.Notifications]: "notifications",
                [WebEnginePermission.PermissionType.ClipboardReadWrite]: "clipboard",
                [WebEnginePermission.PermissionType.LocalFontsAccess]: "fonts"
            }
            const kind = kinds[type]
            // Tipos que Mitis no conoce (de versiones futuras del motor): no
            // se puede explicar al usuario qué conceden, se deniegan
            if (kind === undefined) {
                permission.deny()
                return
            }
            // Cámara y micrófono los recuerda BrowserProfile (el motor no)
            const origin = permission.origin.toString()
            const media = kind === "camera" || kind === "microphone" || kind === "cameraMicrophone"
            const saved = media ? BrowserProfile.mediaPermission(origin, kind) : undefined
            if (saved !== undefined) {
                saved ? permission.grant() : permission.deny()
                return
            }
            root.permissionRequested({
                kind: kind,
                origin: origin,
                remembered: media || permission.isPersistent(type),
                grant: () => {
                    if (media)
                        BrowserProfile.setMediaPermission(origin, kind, true)
                    permission.grant()
                },
                deny: () => {
                    if (media)
                        BrowserProfile.setMediaPermission(origin, kind, false)
                    permission.deny()
                },
                // reset() borra la respuesta guardada: el sitio volverá a preguntar
                dismiss: () => {
                    permission.deny()
                    permission.reset()
                }
            })
        }

        // Menú contextual propio: se traduce la petición a datos neutrales
        onContextMenuRequested: request => {
            request.accepted = true
            const flags = request.editFlags
            const types = {
                [ContextMenuRequest.MediaTypeImage]: "image",
                [ContextMenuRequest.MediaTypeVideo]: "video",
                [ContextMenuRequest.MediaTypeAudio]: "audio"
            }
            root.contextMenuRequested({
                x: request.position.x,
                y: request.position.y,
                linkUrl: request.linkUrl.toString(),
                linkText: request.linkText,
                mediaUrl: request.mediaUrl.toString(),
                mediaType: types[request.mediaType] ?? "",
                selectedText: request.selectedText,
                editable: request.isContentEditable,
                canUndo: (flags & ContextMenuRequest.CanUndo) !== 0,
                canRedo: (flags & ContextMenuRequest.CanRedo) !== 0,
                canCut: (flags & ContextMenuRequest.CanCut) !== 0,
                canCopy: (flags & ContextMenuRequest.CanCopy) !== 0,
                canPaste: (flags & ContextMenuRequest.CanPaste) !== 0,
                canSelectAll: (flags & ContextMenuRequest.CanSelectAll) !== 0
            })
        }

        // Diálogos JavaScript propios: el motor no muestra los suyos
        onJavaScriptDialogRequested: request => {
            request.accepted = true
            const types = {
                [JavaScriptDialogRequest.DialogTypeAlert]: "alert",
                [JavaScriptDialogRequest.DialogTypeConfirm]: "confirm",
                [JavaScriptDialogRequest.DialogTypePrompt]: "prompt",
                [JavaScriptDialogRequest.DialogTypeBeforeUnload]: "beforeunload"
            }
            const dialog = {
                type: types[request.type] ?? "alert",
                message: request.message,
                defaultText: request.defaultText,
                origin: Urls.host(request.securityOrigin.toString()),
                // Se responde una sola vez; luego ya no está pendiente
                accept: text => {
                    if (dialogState.settle(dialog))
                        request.dialogAccept(text ?? "")
                },
                reject: () => {
                    if (dialogState.settle(dialog))
                        request.dialogReject()
                }
            }
            dialogState.pending = dialogState.pending.concat([dialog])
            root.javaScriptDialogRequested(dialog)
        }
        // Selector de archivos propio (lo abre la interfaz)
        onFileDialogRequested: request => {
            request.accepted = true
            const mode = request.mode
            root.fileDialogRequested({
                multiple: mode === FileDialogRequest.FileModeOpenMultiple,
                folder: mode === FileDialogRequest.FileModeUploadFolder,
                save: mode === FileDialogRequest.FileModeSave,
                defaultName: request.defaultFileName,
                filters: root._filePatterns(request.acceptedMimeTypes),
                accept: urls => request.dialogAccept(urls.map(u => u.toString())),
                reject: () => request.dialogReject()
            })
        }
    }

    // Tipos MIME de <input accept> → patrones de nombre de archivo
    readonly property var _mimePatterns: ({
        "image/*": ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.bmp", "*.svg", "*.ico"],
        "video/*": ["*.mp4", "*.webm", "*.mkv", "*.mov", "*.avi", "*.ogv"],
        "audio/*": ["*.mp3", "*.ogg", "*.oga", "*.opus", "*.wav", "*.flac", "*.m4a", "*.aac"],
        "text/plain": ["*.txt"],
        "image/jpeg": ["*.jpg", "*.jpeg"],
        "image/svg+xml": ["*.svg"]
    })
    function _filePatterns(accepted) {
        let patterns = []
        for (const item of accepted) {
            const type = item.trim().toLowerCase()
            let found = _mimePatterns[type]
            if (found === undefined) {
                if (type.startsWith("."))
                    found = ["*" + type]
                else if (/^[a-z]+\/[a-z0-9]+$/.test(type))
                    // application/pdf → *.pdf: vale para la mayoría
                    found = ["*." + type.split("/")[1]]
                else
                    return []   // Algo que no se sabe traducir: mejor sin filtro
            }
            for (const pattern of found)
                if (!patterns.includes(pattern))
                    patterns.push(pattern)
        }
        return patterns
    }

    Component.onCompleted: {
        if (initialUrl !== "")
            view.url = initialUrl
    }
}

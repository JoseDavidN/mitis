import QtQuick
import QtWebEngine
import Mitis.Core

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
    // Pestaña restaurada: no carga initialUrl hasta llamar a load() (al
    // seleccionarla). Mientras, está descargada y no gasta un proceso del
    // motor (aun sin dirección, el motor le daría uno con una página en blanco).
    property bool deferred: false
    // De una ventana privada: usa el perfil sin disco. Solo al crearla.
    property bool privateMode: false
    // Atrás y adelante al instante: al irse, la página se queda congelada en
    // memoria (caché de páginas anteriores) y Atrás la devuelve sin recargar.
    // Cuántas y cuánto tiempo, main.cpp (Settings.instantBackPages). Apagarlo
    // no vacía las ya guardadas: dejan de guardarse y caducan solas. Lo pone Main
    property bool instantBack: false
    // Página propia de Mitis que muestra esta pestaña, sin dirección ni web
    // ("notes": novedades tras actualizar; "" en las demás). La pone Main.qml
    property string special: ""

    // ── Estado de la página ──────────────────────────────────────────
    // Hasta que el motor empieza a cargar (o mientras espera, si es una
    // restaurada), la dirección es la que se le pidió
    readonly property url url: view.url.toString() !== "" ? view.url : initialUrl
    readonly property alias title: view.title
    // Icono de la página (image://favicon/…, del motor). Qt WebEngine se cae
    // al servir el icono de una vista que se descargó alguna vez: al
    // descargarla le cambia la página interna por otra sin gestor de iconos
    // (WebContentsAdapter::discard() no lo crea y undiscard() tampoco, ni
    // al recargarse), y pedírselo es un puntero nulo. Sirve el de la primera
    // vista con ese icono, así que basta con que otra pestaña (de cualquier
    // ventana) lo comparta. Por eso la interfaz nunca pide un icono retirado
    // (BrowserProfile.retiredIcons; ver displayIcon() en Main.qml)
    readonly property alias icon: view.icon
    // Se descargó alguna vez o está a punto (suspend() espera un momento tras
    // avisar, para que acabe lo que ya se pidió): su icono no se vuelve a
    // pedir al motor mientras viva la pestaña, aunque se haya reactivado
    readonly property bool iconRetired: _discardPending || _everDiscarded
    property bool _discardPending: false
    property bool _everDiscarded: false
    onIconRetiredChanged: if (iconRetired) BrowserProfile.retireIcon(icon.toString())
    onIconChanged: if (iconRetired) BrowserProfile.retireIcon(icon.toString())
    readonly property alias loading: view.loading
    readonly property alias loadProgress: view.loadProgress
    readonly property alias canGoBack: view.canGoBack
    readonly property alias canGoForward: view.canGoForward
    // Suena ahora (o hace un momento)
    readonly property alias audible: view.recentlyAudible
    property alias muted: view.audioMuted
    // Micrófono y cámara: 0 sin uso, 1 abierto pero silenciado, 2 en uso
    // (assets/scripts/media.js). Lo junta todo CaptureIndicator (icono de Mitis)
    readonly property int microphone: captureState.microphone
    readonly property int camera: captureState.camera

    // Buscar en la página: coincidencias de la última búsqueda y cuál está
    // seleccionada (1..findMatches; 0 si no hay)
    readonly property alias findMatches: findState.matches
    readonly property alias findActive: findState.active

    // Zoom de la página (1 = 100 %), por sitio como en Chrome: el guardado
    // para su host (BrowserProfile.siteZooms) o, si no hay, el predeterminado
    // de Configuración. Se cambia con setZoom() y se olvida con resetZoom().
    // En la ventana privada no se guarda: vale para esta pestaña (por host)
    // mientras dure.
    readonly property alias zoom: zoomState.level

    // La página está en pantalla completa (p. ej. el botón de un vídeo)
    readonly property alias pageFullScreen: view.isFullScreen

    // ── Memoria ──────────────────────────────────────────────────────
    // Proceso del motor que dibuja la página (para medir su memoria); 0 si
    // no tiene (sin cargar o descargada). Varias pestañas pueden compartirlo.
    readonly property alias renderProcessPid: view.renderProcessPid
    // "active"; "frozen" (congelada: no ejecuta nada pero sigue en memoria)
    // o "discarded" (descargada: sin proceso, se recarga al volver a ella).
    // Ver suspend(). Una restaurada sin cargar (deferred) cuenta como activa.
    readonly property string lifecycle: view.lifecycleState === WebEngineView.LifecycleState.Discarded ? "discarded"
                                      : view.lifecycleState === WebEngineView.LifecycleState.Frozen ? "frozen"
                                      : "active"
    // Desde cuándo está oculta (ms, como Date.now()); 0 mientras se ve
    readonly property alias hiddenSince: suspendState.hiddenSince

    // ── Peticiones de la página ──────────────────────────────────────
    // Quiere abrir algo en una pestaña nueva (enlace con clic central,
    // target=_blank, window.open...). `request` es opaco: quien cree la
    // pestaña nueva se lo pasa a su adopt().
    signal newTabRequested(bool background, var request)
    // La página pidió cerrarse (window.close())
    signal closeRequested()
    // La pestaña se abrió para un enlace (nueva pestaña o ventana) que resultó
    // ser una descarga: no tiene página y la interfaz la cierra, como Chrome
    signal openedOnlyForDownload()
    // Pestaña desde la que se abrió esta (enlace a nueva pestaña); la pone Main
    property Item openerTab: null
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
    // Se llegó a una página nueva: terminó de cargar bien o cambió de
    // dirección sin recargar (como en YouTube). Para el historial.
    signal pageLoaded()
    // La página pidió contenido protegido (Widevine: Netflix, Spotify…) y el
    // motor no lo tiene. Solo llega si falta Widevine; la página sigue sin
    // poder reproducirlo (ver BrowserProfile.widevineAvailable).
    signal protectedContentUnavailable()
    // Hay que mostrar la ventana de imprimir (PrintDialog): Ctrl+P, Opciones,
    // menú contextual (requestPrint()) o la propia página (window.print())
    signal printRequested()
    // La página quiere abrir un enlace de una aplicación del equipo
    // (msteams:, zoommtg:, mailto:…). El motor no la abre: se pregunta antes,
    // como Chrome. `request`: { url, scheme, site (dominio de la página que
    // lo pide, "" sin él), open() }. Si no se abre, no hay que avisar a nadie
    signal externalAppRequested(var request)
    // La página quiere compartir la pantalla (getDisplayMedia): hay que elegir
    // qué. `request`: { site, screens, windows, selectScreen(fila),
    // selectWindow(fila), cancel() }. Las listas son modelos del motor que se
    // llenan poco a poco (rol `display`: nombre) o, con la captura propia de
    // Wayland, listas [{ id, name, detail }]. Hay que responder siempre: sin
    // respuesta, la página se queda esperando
    signal screenShareRequested(var request)
    // Cuándo se eligió en ScreenShareDialog (ms): el permiso de ver la
    // pantalla llega justo después y no se vuelve a preguntar
    property real _screenShareChosen: 0
    // Gestor de contraseñas (assets/scripts/passwords.js), solo en el marco
    // principal. `type`:
    //   "focus"  { kind, rect, text }: el foco entra en un campo de usuario
    //            ("username"), de contraseña ("password") o de contraseña nueva
    //            de un registro ("new-password"); rect en coordenadas de la
    //            pestaña; text, lo escrito en el de usuario
    //   "move"   { rect }  ·  "filter" { text }  ·  "key" { key: down, up, enter, escape }
    //   "none"   el foco salió de esos campos
    //   "submit" { username, password }: se envió un inicio de sesión o registro
    signal passwordEvent(string type, var data)
    readonly property bool certificateErrorPending: certState.pending !== null
    // Esquemas que abre el propio motor; cualquier otro es de una aplicación externa
    readonly property var _webSchemes: ({ http: true, https: true, file: true, data: true, blob: true,
                                          about: true, javascript: true, "view-source": true, chrome: true,
                                          devtools: true, qrc: true, filesystem: true, ws: true, wss: true,
                                          "chrome-extension": true })
    // Se aceptó un certificado no válido de este sitio («Continuar» en el
    // aviso): la conexión está cifrada pero no se sabe con quién
    readonly property bool certificateOverridden: BrowserProfile.certificateExceptions[root._hostOf(root.url.toString())] === true
    // La página actual es de un host cuyo certificado inválido se aceptó
    readonly property bool certificateBypassed: BrowserProfile.certificateExceptions[root._hostOf(view.url.toString())] === true

    // ── Acciones ─────────────────────────────────────────────────────
    // Carga una pestaña restaurada (deferred); en las demás no hace nada
    function load() {
        if (!deferred)
            return
        deferred = false
        root._wake()
        if (initialUrl !== "")
            view.url = initialUrl
    }
    function navigate(target) {
        deferred = false
        root._cancelCertificateError()
        root._wake()
        view.url = target
    }
    // Ahorra memoria con la pestaña oculta: la congela o, con `discard`, la
    // descarga (si ya estaba congelada, pasa de una a otra). No hace nada si
    // la página suena o graba, tiene DevTools abiertas, puede mandar
    // notificaciones (un chat dejaría de avisar) o un formulario a medio
    // rellenar. Quién y cuándo la suspende lo decide la interfaz (fijadas no).
    function suspend(discard) {
        if (root.deferred || root.visible || root.audible || root.microphone || root.camera
                || devTools.item || root.sharingScreen)
            return
        const State = WebEngineView.LifecycleState
        let target = discard ? State.Discarded : State.Frozen
        if (view.lifecycleState >= target)
            return
        // El motor sabe más (cámara o pantalla en uso, aviso de salir…): Active
        // = no suspender; Frozen = como mucho congelar
        const recommended = view.recommendedState
        if (recommended === State.Active)
            return
        target = Math.min(target, recommended)
        if (view.lifecycleState >= target || root._canNotify())
            return
        // Congelada ya no ejecuta scripts: el formulario se miró al congelarla
        // (y oculta no ha podido cambiar)
        if (view.lifecycleState === State.Frozen) {
            root._applyState(target)
            return
        }
        // En un mundo aparte: la página no puede interferir. Si no responde
        // (JavaScript desactivado…), no se sabe y no se suspende.
        view.runJavaScript(root._editedFormScript, WebEngineScript.ApplicationWorld, edited => {
            if (edited === false && !root.visible && view.lifecycleState < target)
                root._applyState(target)
        })
    }
    // Deslizar entre páginas: `done(true)` si el gesto horizontal en curso no
    // es de la página (no desplaza nada ni se lo queda; assets/scripts/swipe.js)
    function swipeAllowed(done) {
        if (root.url.toString() === "") {
            done(true)
            return
        }
        view.runJavaScript("window.__mitisSwipe ? window.__mitisSwipe() : null",
                           WebEngineScript.ApplicationWorld,
                           result => done(!!result && result.recent && !result.claimed))
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
    // Cambia el zoom del sitio de la página (1 = 100 %)
    function setZoom(level) {
        const host = zoomState.host
        if (privateMode || host === "") {
            const own = Object.assign({}, zoomState.own)
            own[host] = level
            zoomState.own = own
        } else {
            BrowserProfile.setSiteZoom(host, level)
        }
    }
    // Vuelve al zoom predeterminado (y lo sigue si cambia)
    function resetZoom() {
        const host = zoomState.host
        if (host in zoomState.own) {
            const own = Object.assign({}, zoomState.own)
            delete own[host]
            zoomState.own = own
        }
        if (!privateMode)
            BrowserProfile.forgetSiteZoom(host)
    }
    // Saca la página de pantalla completa sin esperar a que ella responda
    function exitFullScreen() {
        if (view.isFullScreen)
            view.fullScreenCancelled()
    }
    // Carga en esta pestaña lo que otra pidió abrir (ver newTabRequested)
    function adopt(request) {
        pageState.adopted = true
        if (openerTab)
            (openerTab as BrowserTab)._openedTabs.push(root)
        request.openIn(view)
    }
    // Pestañas que esta abrió (adopt): su página puede seguir usando esta
    // vista aunque se cierre la pestaña (ver EngineBridge::keepOpenerView)
    property var _openedTabs: []

    QtObject {
        id: pageState
        // Se abrió con adopt() (enlace a otra pestaña, window.open…)
        property bool adopted: false
        // Ha llegado a mostrar alguna página
        property bool hasPage: false
    }
    Connections {
        target: BrowserProfile
        function onDownloadStarted(downloadView) {
            if (downloadView === view && pageState.adopted && !pageState.hasPage)
                root.openedOnlyForDownload()
        }
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

    // ── Imprimir ─────────────────────────────────────────────────────
    function requestPrint() {
        root.printRequested()
    }
    // La página como PDF en `filePath`, para imprimirla o guardarla:
    // `done(filePath)`, o `done("")` si no se pudo. paper: "a4", "letter" o
    // "legal". Una sola a la vez: el motor rechaza otra mientras dura una, así
    // que la que llegue entretanto espera (solo la última). Siempre la versión
    // que escribe un archivo: la que entrega los bytes a una función tumba a
    // Mitis si el motor la rechaza (Qt 6.11 usa el resultado vacío sin
    // comprobarlo; CLAUDE.md, problemas resueltos)
    function printToPdf(filePath, done, landscape, paper, backgrounds) {
        const job = { filePath: filePath, done: done, landscape: landscape, paper: paper, backgrounds: backgrounds }
        if (root._pdfJob)
            root._pdfNext = job
        else
            root._startPdf(job)
    }
    // Quien pidió el PDF ya no lo quiere (la ventana de imprimir se cerró)
    function cancelPdf() {
        if (root._pdfJob)
            root._pdfJob.done = null
        root._pdfNext = null
    }
    property var _pdfJob: null
    property var _pdfNext: null
    function _startPdf(job) {
        const sizes = { a4: WebEngineView.A4, letter: WebEngineView.Letter, legal: WebEngineView.Legal }
        root._pdfJob = job
        view.settings.printElementBackgrounds = job.backgrounds
        view.printToPdf(job.filePath, sizes[job.paper] ?? WebEngineView.A4,
                        job.landscape ? WebEngineView.Landscape : WebEngineView.Portrait)
    }

    // Corrector: cambia la palabra mal escrita del menú contextual por `word`
    function replaceMisspelledWord(word) {
        view.replaceMisspelledWord(word)
    }

    // ── Compartir pantalla propio (Wayland sin el portal) ────────────
    // assets/scripts/screenshare.js pide por consola «request <id>» (la página
    // llamó a getDisplayMedia) o «stop <clave>» (paró la pista). Se pregunta
    // con ScreenShareDialog (screenShareRequested, con las listas de Mitis) y
    // se responde a la página con __mitisScreenShare.answer(). La captura la
    // hace src/screencapture.*; las de esta pestaña se paran al cerrarla.
    property var _screenShares: []
    readonly property bool sharingScreen: _screenShares.length > 0
    function _screenShareMessage(text) {
        const space = text.indexOf(" ")
        const type = text.slice(0, space)
        const argument = text.slice(space + 1)
        if (type === "request") {
            root._ownScreenShare(Number(argument))
        } else if (type === "stop") {
            // qmllint disable unqualified
            MitisEngine.stopScreenCapture(argument)
            // qmllint enable unqualified
            root._screenShares = root._screenShares.filter(token => token !== argument)
        }
    }
    function _answerScreenShare(id, answer) {
        view.runJavaScript("window.__mitisScreenShare && window.__mitisScreenShare.answer("
                           + id + ", " + JSON.stringify(answer) + ")")
    }
    function _ownScreenShare(id) {
        const denied = { error: "NotAllowedError", message: "Permission denied" }
        // Bloqueado en Configuración, como el permiso del motor
        if (Settings.blockedPermissions.includes("screen")) {
            root._answerScreenShare(id, denied)
            return
        }
        // qmllint disable unqualified
        const engine = MitisEngine
        // qmllint enable unqualified
        // Copia en JavaScript: las listas de C++ no dan sus filas como objetos a un Repeater
        const sources = JSON.parse(JSON.stringify(engine.screenCaptureSources()))
        const page = view.url
        const share = (kind, item, surface) => {
            const token = item ? engine.startScreenCapture(kind, item.id, page) : ""
            if (token === "") {
                root._answerScreenShare(id, { error: "AbortError", message: "Could not start capture" })
                return
            }
            root._screenShares = root._screenShares.concat([token])
            root._answerScreenShare(id, {
                token: token,
                url: "mitis-captura://" + token + "/",
                surface: surface,
                label: item.name
            })
        }
        root.screenShareRequested({
            site: root._hostOf(page.toString()).replace(/^www\./, ""),
            screens: sources.screens,
            windows: sources.windows,
            selectScreen: row => share("screen", sources.screens[row], "monitor"),
            selectWindow: row => share("window", sources.windows[row], "window"),
            cancel: () => root._answerScreenShare(id, denied)
        })
    }
    Connections {
        // qmllint disable unqualified
        target: MitisEngine
        // qmllint enable unqualified
        function onScreenCaptureEnded(token) {
            root._screenShares = root._screenShares.filter(other => other !== token)
        }
    }

    // ── Llaves de acceso (passkeys) ──────────────────────────────────
    // Lo que muestra PasskeyDialog (en el delegado de Main), sin tipos del
    // motor. mode: "phone" (QR: Mitis habla con el móvil, src/hybrid.*) o
    // "key" (llave física: la pide el motor, webAuthUxRequested).
    // state, en "phone": scanning, bluetoothOff, noBluetooth, connecting,
    // confirm; en "key": account, pin, touch, failed
    readonly property QtObject passkey: QtObject {
        property bool active: false
        property string mode: ""
        property string kind: "get"
        property string site: ""
        property string qr: ""
        property string state: ""
        property var accounts: []
        // en "failed": timeout, notRegistered, alreadyRegistered, pinBlocked,
        // removed, unsupported, storageFull, denied
        property string failure: ""
        // en "pin": set, change o challenge; y el error del intento anterior
        property string pinReason: ""
        property string pinError: ""
        property int pinMinLength: 4
        property int pinAttempts: -1
    }
    property int _passkeyRequestId: 0
    property int _passkeySession: 0
    property string _passkeyOrigin: ""
    property bool _passkeySwitching: false
    property var _passkeyNative: null

    function _originOf(url) {
        const match = /^[a-z]+:\/\/[^\/?#]+/i.exec(url.toString())
        return match ? match[0].toLowerCase() : ""
    }
    // assets/scripts/webauthn.js: «request <id> <get|create> <publicKey JSON>»
    // o «cancel <id>» (la página abortó)
    function _passkeyMessage(text) {
        const parts = text.split(" ")
        if (parts[0] === "request") {
            root._passkeyRequest(Number(parts[1]), parts[2], parts.slice(3).join(" "))
        } else if (parts[0] === "cancel" && Number(parts[1]) === root._passkeyRequestId) {
            if (root._passkeySession !== 0) {
                // qmllint disable unqualified
                MitisEngine.cancelPasskey(root._passkeySession)
                // qmllint enable unqualified
            } else if (passkey.mode === "key" && !root._passkeyNative) {
                root._passkeyRequestId = 0
                passkey.active = false
            }
        } else if (parts[0] === "done" && Number(parts[1]) === root._passkeyRequestId && passkey.mode === "key") {
            // La llave física terminó (bien o mal) por el motor
            root._passkeyRequestId = 0
            if (!root._passkeyNative)
                passkey.active = false
        }
    }
    function _answerPasskey(id, answer) {
        view.runJavaScript("window.__mitisWebAuthn && window.__mitisWebAuthn.answer(" + id + ", " + JSON.stringify(answer) + ")")
    }
    function _passkeyRequest(id, kind, json) {
        // Una a la vez, como el motor
        if (passkey.active) {
            root._answerPasskey(id, { error: "NotAllowedError", message: "A request is already pending." })
            return
        }
        // qmllint disable unqualified
        const started = MitisEngine.startPasskey(kind, json, view.url)
        // qmllint enable unqualified
        if (started.error) {
            root._answerPasskey(id, { error: started.error })
            return
        }
        root._passkeyRequestId = id
        root._passkeySession = started.session
        root._passkeyOrigin = root._originOf(view.url)
        passkey.mode = "phone"
        passkey.kind = kind === "create" ? "create" : "get"
        passkey.site = root._hostOf(view.url.toString()).replace(/^www\./, "")
        passkey.qr = started.qr
        passkey.state = "scanning"
        passkey.active = true
    }
    Connections {
        // qmllint disable unqualified
        target: MitisEngine
        // qmllint enable unqualified
        function onPasskeyState(session, state) {
            if (session === root._passkeySession)
                root.passkey.state = state
        }
        function onPasskeyFinished(session, result) {
            if (session !== root._passkeySession)
                return
            root._passkeySession = 0
            // Mismo sitio que al pedirlo: si la página navegó, ya no espera
            const samePage = root._originOf(view.url) === root._passkeyOrigin
            if (root._passkeySwitching) {
                // «Usar una llave de seguridad»: la petición sigue por el
                // motor. La ventana sigue abierta: sin llave conectada, el
                // motor no avisa de nada hasta que la conectas
                root._passkeySwitching = false
                if (samePage) {
                    root.passkey.mode = "key"
                    root.passkey.state = "touch"
                    root._answerPasskey(root._passkeyRequestId, { native: true })
                } else {
                    root.passkey.active = false
                }
                return
            }
            if (samePage)
                root._answerPasskey(root._passkeyRequestId, result)
            root.passkey.active = false
        }
    }
    // Acciones de PasskeyDialog
    function passkeyUseKey() {
        root._passkeySwitching = true
        // qmllint disable unqualified
        MitisEngine.cancelPasskey(root._passkeySession)
        // qmllint enable unqualified
    }
    function passkeyBluetoothOn() {
        // qmllint disable unqualified
        MitisEngine.passkeyBluetoothOn(root._passkeySession)
        // qmllint enable unqualified
    }
    function passkeyCancel() {
        if (passkey.mode === "phone" && root._passkeySession !== 0) {
            // qmllint disable unqualified
            MitisEngine.cancelPasskey(root._passkeySession)
            // qmllint enable unqualified
        } else if (root._passkeyNative) {
            root._passkeyNative.cancel()
        }
        // Sin respuesta del motor (no hay llave conectada): la página recibe NotAllowedError
        if (passkey.mode === "key" && root._passkeyRequestId !== 0)
            root._answerPasskey(root._passkeyRequestId, { cancel: true })
        root._passkeyRequestId = 0
        passkey.active = false
    }
    function passkeySelectAccount(name) {
        if (root._passkeyNative)
            root._passkeyNative.setSelectedAccount(name)
    }
    function passkeySetPin(pin) {
        if (root._passkeyNative)
            root._passkeyNative.setPin(pin)
    }
    function passkeyRetry() {
        if (root._passkeyNative)
            root._passkeyNative.retry()
    }
    // Llave física: el motor pide la ventana (si no se atiende, la página
    // espera hasta que caduca, sin nada en pantalla)
    function _nativePasskey(request) {
        root._passkeyNative = request
        passkey.mode = "key"
        passkey.site = request.relyingPartyId
        passkey.active = true
        request.stateChanged.connect(root._nativePasskeyState)
        root._nativePasskeyState()
    }
    function _nativePasskeyState() {
        const request = root._passkeyNative
        if (!request)
            return
        const State = WebEngineWebAuthUxRequest.WebAuthUxState
        switch (request.state) {
        case State.SelectAccount:
            passkey.accounts = request.userNames
            passkey.state = "account"
            break
        case State.CollectPin: {
            const pin = request.pinRequest
            passkey.pinReason = ["set", "change", "challenge"][pin.reason] ?? "challenge"
            passkey.pinError = ["", "locked", "wrong", "short", "characters", "same"][pin.error] ?? ""
            passkey.pinMinLength = pin.minPinLength
            passkey.pinAttempts = pin.remainingAttempts
            passkey.state = "pin"
            break
        }
        case State.RequestFailed:
            passkey.failure = ["timeout", "notRegistered", "alreadyRegistered", "pinBlocked", "pinBlocked", "removed",
                               "unsupported", "unsupported", "unsupported", "unsupported", "storageFull", "denied",
                               "denied"][request.requestFailureReason] ?? "denied"
            passkey.state = "failed"
            break
        case State.Cancelled:
        case State.Completed:
            request.stateChanged.disconnect(root._nativePasskeyState)
            root._passkeyNative = null
            root._passkeyRequestId = 0
            passkey.active = false
            break
        default:
            passkey.state = "touch"
        }
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

    // ── Contraseñas (assets/scripts/passwords.js) ────────────────────
    // Rellena el campo con el foco y su pareja (usuario y contraseña)
    function fillCredentials(username, password) {
        view.runJavaScript("window.__mitisPasswords && window.__mitisPasswords.fill("
                           + JSON.stringify(username) + ", " + JSON.stringify(password) + ")",
                           WebEngineScript.ApplicationWorld)
    }
    // Pone una contraseña generada en los campos de contraseña nueva
    function fillNewPassword(password) {
        view.runJavaScript("window.__mitisPasswords && window.__mitisPasswords.fillNew("
                           + JSON.stringify(password) + ")", WebEngineScript.ApplicationWorld)
    }
    // Con la lista abierta, las flechas, Enter y Esc del campo son de ella
    function setPasswordListOpen(open) {
        view.runJavaScript("window.__mitisPasswords && window.__mitisPasswords.setOpen(" + (open ? "true" : "false") + ")",
                           WebEngineScript.ApplicationWorld)
    }
    function _passwordMessage(text) {
        const space = text.indexOf(" ")
        const type = space < 0 ? text : text.slice(0, space)
        let data = {}
        try {
            data = space < 0 ? {} : JSON.parse(text.slice(space + 1))
        } catch (e) {
            return
        }
        // De píxeles CSS de la página a los de la pestaña
        if (data.rect) {
            const zoom = view.zoomFactor
            data.rect = Qt.rect(data.rect.x * zoom, data.rect.y * zoom, data.rect.width * zoom, data.rect.height * zoom)
        }
        root.passwordEvent(type, data)
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

    QtObject {
        id: captureState
        property int microphone: 0
        property int camera: 0

        function set(microphone, camera) {
            captureState.microphone = Math.max(0, Math.min(2, microphone || 0))
            captureState.camera = Math.max(0, Math.min(2, camera || 0))
            CaptureIndicator.report(root, captureState.microphone, captureState.camera)
        }
        // Lo pregunta a la página (al terminar una carga: el documento nuevo
        // empieza sin nada y una navegación dentro de la misma página no
        // cambia lo que tenga abierto)
        function sync() {
            view.runJavaScript("window.__mitisMedia ? window.__mitisMedia.capture() : null",
                               result => captureState.set(result ? result[0] : 0, result ? result[1] : 0))
        }
    }

    // ── Captura de pantalla (ScreenshotOverlay) ──────────────────────
    // Todo en píxeles CSS del documento: la interfaz los pasa a los suyos con
    // `zoom`. En un mundo aparte: la página no puede interferir.
    // `done(m)`: { scrollX, scrollY, width, height (lo visible), pageHeight }
    readonly property string _pageMetricsScript: "({ scrollX: window.scrollX, scrollY: window.scrollY,"
        + " width: document.documentElement.clientWidth, height: window.innerHeight,"
        + " pageHeight: Math.max(document.documentElement.scrollHeight, document.body ? document.body.scrollHeight : 0) })"
    function pageMetrics(done) {
        view.runJavaScript(root._pageMetricsScript, WebEngineScript.ApplicationWorld, result => done(result ?? null))
    }
    // Desplaza la página (y luego mide)
    function scrollPageTo(y, done) {
        view.runJavaScript("window.scrollTo(window.scrollX, " + Math.max(0, Math.round(y)) + "); "
                           + root._pageMetricsScript, WebEngineScript.ApplicationWorld, result => done(result ?? null))
    }
    function scrollPageBy(dy, done) {
        view.runJavaScript("window.scrollBy(0, " + Math.round(dy) + "); " + root._pageMetricsScript,
                           WebEngineScript.ApplicationWorld, result => done(result ?? null))
    }
    // Sección de la página bajo el punto (x, y de lo visible): el primer
    // bloque, subiendo desde el elemento del punto, con un tamaño razonable y
    // que no sea la página entera. `done(r)`: { x, y, w, h } del documento o null
    function sectionAt(x, y, done) {
        view.runJavaScript("(function (x, y) {"
            + " let el = document.elementFromPoint(x, y);"
            + " const vw = document.documentElement.clientWidth, vh = window.innerHeight;"
            + " while (el && el !== document.documentElement && el !== document.body) {"
            + "  const r = el.getBoundingClientRect();"
            + "  const inline = getComputedStyle(el).display === 'inline';"
            + "  if (r.width >= vw * 0.98 && r.height >= vh * 0.98) return null;"
            + "  if (!inline && r.width >= 120 && r.height >= 48) {"
            + "   const left = Math.max(0, r.left), right = Math.min(vw, r.right);"
            + "   return { x: left + window.scrollX, y: r.top + window.scrollY, w: right - left, h: r.height };"
            + "  }"
            + "  el = el.parentElement;"
            + " }"
            + " return null;"
            + "})(" + Math.round(x) + ", " + Math.round(y) + ")", WebEngineScript.ApplicationWorld, result => done(result ?? null))
    }
    // Oculta (o vuelve a mostrar) lo que la página fija en pantalla (cabeceras,
    // avisos): al juntar varios trozos de una captura saldría repetido
    function setFloatingHidden(hidden, done) {
        view.runJavaScript("(function (hide) {"
            + " const mark = 'data-mitis-captura';"
            + " if (hide) {"
            + "  for (const el of document.querySelectorAll('body *')) {"
            + "   const position = getComputedStyle(el).position;"
            + "   if ((position === 'fixed' || position === 'sticky') && !el.hasAttribute(mark)) {"
            + "    el.setAttribute(mark, el.style.getPropertyValue('visibility'));"
            + "    el.style.setProperty('visibility', 'hidden', 'important');"
            + "   }"
            + "  }"
            + " } else {"
            + "  for (const el of document.querySelectorAll('[' + mark + ']')) {"
            + "   const before = el.getAttribute(mark);"
            + "   el.removeAttribute(mark);"
            + "   if (before) el.style.setProperty('visibility', before); else el.style.removeProperty('visibility');"
            + "  }"
            + " }"
            + " return true;"
            + "})(" + (hidden ? "true" : "false") + ")", WebEngineScript.ApplicationWorld, () => {
                if (done)
                    done()
            })
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

    Component.onDestruction: {
        // qmllint disable unqualified
        for (const token of root._screenShares)
            MitisEngine.stopScreenCapture(token)
        // qmllint enable unqualified
        root._cancelCertificateError()
        CaptureIndicator.report(root, 0, 0)
        // Las pestañas que abrió y siguen abiertas necesitan la vista viva
        const opened = _openedTabs.filter(tab => tab)
        // qmllint disable unqualified
        if (opened.length > 0 && typeof MitisEngine.keepOpenerView === "function")
            MitisEngine.keepOpenerView(view, opened)
        // qmllint enable unqualified
    }

    QtObject {
        id: devTools
        property Item item: null
    }

    Component {
        id: devToolsView

        WebEngineView {
            anchors.fill: parent
            profile: BrowserProfile.profile
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

    // ── Ocultar huecos de anuncios ───────────────────────────────────
    // El bloqueador (C++) quita las peticiones; lo que queda en la página
    // (cajas vacías, avisos de «publicidad») lo ocultan las reglas de
    // ocultación del sitio. Al empezar cada carga de la página (también al
    // recargar o ir atrás) se pone en la vista un script con el CSS de ese
    // sitio (solo el suyo: nada que cueste memoria en las demás), que se
    // aplica al crearse el documento.
    function _applyCosmetics(address) {
        // qmllint disable unqualified
        // En las ventanas privadas, siempre (sin mirar Configuración)
        const css = MitisEngine.cosmeticCss(address, root.privateMode)
        // qmllint enable unqualified
        const scripts = view.userScripts
        for (const old of scripts.find("mitis-cosmetic"))
            scripts.remove(old)
        if (css === "")
            return
        const script = WebEngine.script()
        script.name = "mitis-cosmetic"
        script.injectionPoint = WebEngineScript.DocumentCreation
        // Aparte de la página: no puede quitarlo ni lo frena su CSP
        script.worldId = WebEngineScript.ApplicationWorld
        script.runsOnSubFrames = false
        script.sourceCode = "(function (css) {"
            + "  const sheet = new CSSStyleSheet();"
            + "  sheet.replaceSync(css);"
            + "  document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet];"
            + "})(" + JSON.stringify(css) + ")"
        scripts.insert(script)
    }

    // ── Ocultar la barra de desplazamiento (Settings.hideScrollbars) ──
    // Una hoja de estilo adoptada, desde un mundo aparte (no la quita la página
    // ni la frena su CSP). scrollbar-width: none oculta la barra sin quitar el
    // desplazamiento, también en los elementos con overflow propio; la regla
    // ::-webkit-scrollbar cubre las páginas que la estilan con display propio.
    // __mitisScrollbars(oculta) permite cambiarlo en vivo sin recargar.
    readonly property string _scrollbarScript: "(function () {"
        + "  if (!window.__mitisScrollbars) {"
        + "    const sheet = new CSSStyleSheet();"
        + "    sheet.replaceSync('*{scrollbar-width:none!important}*::-webkit-scrollbar{display:none!important}');"
        + "    window.__mitisScrollbars = function (hidden) {"
        + "      const others = document.adoptedStyleSheets.filter(s => s !== sheet);"
        + "      document.adoptedStyleSheets = hidden ? [...others, sheet] : others;"
        + "    };"
        + "  }"
        + "  window.__mitisScrollbars(true);"
        + "})()"

    // El script queda en la vista (vale para las próximas cargas) solo con la
    // opción activa; live = aplicarlo también a la página ya abierta
    function _applyScrollbars(live) {
        const hidden = Settings.hideScrollbars
        const scripts = view.userScripts
        for (const old of scripts.find("mitis-scrollbars"))
            scripts.remove(old)
        if (hidden) {
            const script = WebEngine.script()
            script.name = "mitis-scrollbars"
            script.injectionPoint = WebEngineScript.DocumentCreation
            script.worldId = WebEngineScript.ApplicationWorld
            script.runsOnSubFrames = true
            script.sourceCode = root._scrollbarScript
            scripts.insert(script)
        }
        if (live)
            view.runJavaScript(hidden ? root._scrollbarScript
                                      : "window.__mitisScrollbars && window.__mitisScrollbars(false)",
                               WebEngineScript.ApplicationWorld)
    }
    Connections {
        target: Settings
        function onHideScrollbarsChanged() { root._applyScrollbars(true) }
    }

    // ── Suspensión ───────────────────────────────────────────────────
    QtObject {
        id: suspendState
        property real hiddenSince: 0
    }
    // Se mira un momento después: al reordenar pestañas, una puede verse
    // un instante sin que nadie la haya abierto (y no debe despertarse)
    onVisibleChanged: Qt.callLater(root._visibilitySettled)
    function _visibilitySettled() {
        if (visible) {
            suspendState.hiddenSince = 0
            root._wake()
        } else if (suspendState.hiddenSince === 0) {
            suspendState.hiddenSince = Date.now()
        }
    }
    // Una suspendida vuelve a estar activa (la descargada se recarga)
    function _wake() {
        discardDelay.stop()
        root._discardPending = false
        if (view.lifecycleState !== WebEngineView.LifecycleState.Active)
            view.lifecycleState = WebEngineView.LifecycleState.Active
    }
    // Congelar es inmediato; descargar, tras retirar el icono (iconRetired,
    // para siempre: ver `icon`)
    function _applyState(target) {
        if (target !== WebEngineView.LifecycleState.Discarded) {
            view.lifecycleState = target
            return
        }
        root._discardPending = true
        discardDelay.restart()
    }
    Timer {
        id: discardDelay
        interval: 2000
        onTriggered: {
            if (root._discardPending && !root.visible)
                view.lifecycleState = WebEngineView.LifecycleState.Discarded
            root._discardPending = false
        }
    }
    // Restaurada sin cargar: aun sin dirección, el motor le da un proceso
    // con una página en blanco poco después de crear la vista. Se descarga en
    // cuanto existe; no hay aviso (renderProcessPidChanged no llega a QML),
    // así que se mira cada poco durante unos segundos.
    Timer {
        property int tries: 0
        interval: 500
        repeat: true
        running: root.deferred && !root.visible && tries < 20
                 && view.lifecycleState === WebEngineView.LifecycleState.Active
        onTriggered: {
            tries++
            if (view.renderProcessPid > 0)
                view.lifecycleState = WebEngineView.LifecycleState.Discarded
        }
    }
    // El sitio tiene permiso para mandar notificaciones (también en una
    // restaurada sin cargar: mira la dirección guardada). Main carga al
    // arrancar las esenciales y fijadas que pueden avisar (WhatsApp…)
    function canNotify() {
        return root._canNotify()
    }
    function _canNotify() {
        const origin = /^https?:\/\/[^\/?#]+/i.exec((root.deferred ? root.initialUrl : view.url).toString())
        return origin !== null && view.profile.queryPermission(origin[0], WebEnginePermission.PermissionType.Notifications)
                                      .state === WebEnginePermission.State.Granted
    }
    // true si algún campo de la página tiene algo distinto de lo que traía
    // (texto escrito, casilla marcada, otra opción elegida) o se está
    // escribiendo en un editor (contenteditable, como el de un correo)
    readonly property string _editedFormScript: `(function () {
        for (const field of document.querySelectorAll('input, textarea, select')) {
            if (field.disabled)
                continue
            if (field.tagName === 'SELECT') {
                const initial = Array.from(field.options).findIndex(option => option.defaultSelected)
                if (field.selectedIndex !== (initial >= 0 ? initial : (field.multiple ? -1 : 0)))
                    return true
                continue
            }
            const type = (field.type || '').toLowerCase()
            if (type === 'checkbox' || type === 'radio') {
                if (field.checked !== field.defaultChecked)
                    return true
            } else if (!['hidden', 'submit', 'button', 'reset', 'image', 'file'].includes(type)
                       && field.value !== field.defaultValue) {
                return true
            }
        }
        const active = document.activeElement
        return !!(active && active.isContentEditable && active.textContent.trim() !== '')
    })()`

    QtObject {
        id: zoomState
        // Host de la página que se ve (el zoom cambia al pasar a otro sitio)
        readonly property string host: root._hostOf(view.url.toString())
        // Los de esta pestaña que no se guardan (ventana privada, páginas sin
        // host como archivos): host → nivel
        property var own: ({})
        readonly property real level: {
            if (host in own)
                return own[host]
            const saved = root.privateMode || host === "" ? undefined : BrowserProfile.siteZooms[host]
            return saved !== undefined ? saved : Settings.defaultZoom
        }
        onLevelChanged: {
            if (Math.abs(view.zoomFactor - level) > 0.001)
                view.zoomFactor = level
        }
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

    // Última dirección contada como visita (ver pageLoaded)
    QtObject {
        id: visitState
        property string url: ""
    }
    function _checkSameDocument() {
        const current = view.url.toString()
        if (view.loading || view.loadProgress < 100 || current === "" || current === visitState.url)
            return
        visitState.url = current
        root.pageLoaded()
    }

    QtObject {
        id: findState
        property int matches: 0
        property int active: 0
    }

    WebEngineView {
        id: view
        anchors.fill: parent
        onLifecycleStateChanged: if (lifecycleState === WebEngineView.LifecycleState.Discarded) root._everDiscarded = true
        // Lo que difumina el vidrio (Glass) de los diálogos de la pestaña
        readonly property bool glassBackdrop: true
        profile: root.privateMode ? BrowserProfile.privateProfile : BrowserProfile.profile
        // Visor de PDF integrado (también lo esperan algunos sitios: un
        // navegador sin él parece un motor embebido)
        settings.pluginsEnabled: true
        // Compartir pantalla (getDisplayMedia): el motor lo trae apagado y
        // rechaza toda petición (AbortError en la página)
        settings.screenCaptureEnabled: true
        settings.pdfViewerEnabled: true
        settings.backForwardCacheEnabled: root.instantBack
        // Sin esto el motor rechaza la pantalla completa de vídeos y páginas
        settings.fullScreenSupportEnabled: true
        // Preferencias de Configuración; el motor las aplica sin recargar
        settings.javascriptEnabled: Settings.javascript
        settings.autoLoadImages: Settings.images
        // Sin esto, una ventana emergente solo se abre tras un clic del usuario
        settings.javascriptCanOpenWindows: !Settings.blockPopups
        settings.playbackRequiresUserGesture: !Settings.autoplay
        settings.forceDarkMode: Settings.darkPages
        // Ventanas privadas: privacidad siempre activa
        settings.webRTCPublicInterfacesOnly: Settings.hideLocalIp || root.privateMode
        // Precarga de páginas: también los nombres de dominio de los enlaces
        // (el resto, preload.js); nunca en ventanas privadas
        settings.dnsPrefetchEnabled: Settings.preloadPages && !root.privateMode
        // Enlaces de aplicaciones externas: de serie, el motor solo deja los
        // que vienen de un clic y los abre sin preguntar; así llegan todos a
        // onNavigationRequested (también los que la página lanza sola, como
        // el «Abrir en la aplicación» de Teams o Zoom) y Mitis pregunta
        settings.unknownUrlSchemePolicy: WebEngineSettings.AllowAllUnknownUrlSchemes

        onNavigationRequested: request => {
            const address = request.url.toString()
            const scheme = address.slice(0, Math.max(0, address.indexOf(":"))).toLowerCase()
            if (scheme === "" || root._webSchemes[scheme] === true)
                return
            // Rechazada, el motor no la abre; la abre Mitis si se acepta
            request.reject()
            root.externalAppRequested({
                url: address,
                scheme: scheme,
                site: root._hostOf(view.url.toString()).replace(/^www\./, ""),
                open: () => Qt.openUrlExternally(address)
            })
        }

        onWebAuthUxRequested: request => root._nativePasskey(request)

        // Qt no elige nada si no se atiende: ScreenShareDialog pregunta
        onDesktopMediaRequested: request => {
            const screens = request.screensModel
            const windows = request.windowsModel
            // Wayland: la lista la lleva el escritorio (portal; en Hyprland,
            // hyprland-share-picker): cada una trae una sola fila que no es
            // una pantalla de verdad y el selector del escritorio sale al
            // empezar a capturar, tras el permiso. Se responde al momento
            if (Qt.platform.pluginName === "wayland") {
                request.selectScreen(screens.index(0, 0))
                return
            }
            root.screenShareRequested({
                site: root._hostOf(view.url.toString()).replace(/^www\./, ""),
                screens: screens,
                windows: windows,
                selectScreen: row => {
                    root._screenShareChosen = Date.now()
                    request.selectScreen(screens.index(row, 0))
                },
                selectWindow: row => {
                    root._screenShareChosen = Date.now()
                    request.selectWindow(windows.index(row, 0))
                },
                cancel: () => request.cancel()
            })
        }

        onFindTextFinished: result => {
            findState.matches = result.numberOfMatches
            findState.active = result.activeMatch
        }
        // El motor puede volver al 100 % al cambiar de página: el zoom es el
        // del sitio (zoomState), así que se vuelve a aplicar. Con la página ya
        // cargada, un cambio es del usuario (p. ej. Ctrl+rueda) y se guarda.
        onZoomFactorChanged: {
            if (Math.abs(view.zoomFactor - zoomState.level) <= 0.001)
                return
            if (view.loading)
                view.zoomFactor = zoomState.level
            else
                root.setZoom(view.zoomFactor)
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
            // Conexiones seguras: una página subida de http a https que no
            // carga por https (sin conexión segura, certificado no válido,
            // respuesta vacía…) se vuelve a pedir por http (ver RequestInterceptor)
            // qmllint disable unqualified
            if (loadingInfo.status === WebEngineView.LoadSucceededStatus)
                MitisEngine.confirmHttps(loadingInfo.url, root.privateMode)
            if (loadingInfo.status === WebEngineView.LoadFailedStatus
                    && MitisEngine.takeHttpsFallback(loadingInfo.url, root.privateMode)) {
                view.url = loadingInfo.url.toString().replace(/^https:/, "http:")
                return
            }
            // qmllint enable unqualified
            if (loadingInfo.status !== WebEngineView.LoadStartedStatus)
                captureState.sync()
            // La página en blanco inicial de una pestaña abierta por otra
            // (about:blank) no cuenta como página
            if (loadingInfo.status === WebEngineView.LoadSucceededStatus
                    && !/^(about:|$)/.test(loadingInfo.url.toString()))
                pageState.hasPage = true
            if (loadingInfo.status === WebEngineView.LoadSucceededStatus
                    && view.url.toString() !== visitState.url) {
                visitState.url = view.url.toString()
                root.pageLoaded()
            }
            if (loadingInfo.status === WebEngineView.LoadStartedStatus) {
                root._applyCosmetics(loadingInfo.url)
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
            // Al empezar una carga la dirección cambia antes de que `loading`
            // se active: se mira después, y sin carga es la misma página
            Qt.callLater(root._checkSameDocument)
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
            // Página subida a https por Mitis (no la pidió así el usuario):
            // sin aviso, se rechaza y la carga fallida vuelve a http
            // qmllint disable unqualified
            if (MitisEngine.isHttpsUpgrade(error.url, root.privateMode)) {
                error.rejectCertificate()
                return
            }
            // qmllint enable unqualified
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
        // Si el proceso de la página muere, con él se cierran micrófono y
        // cámara. Queda en el registro de la sesión (informes de cierres)
        onRenderProcessTerminated: (terminationStatus, exitCode) => {
            captureState.set(0, 0)
            if (terminationStatus !== WebEngineView.NormalTerminationStatus)
                console.warn("[Mitis] Terminó el proceso de una página:",
                             ["normal", "anormal", "caída", "cerrado por el sistema"][terminationStatus] ?? terminationStatus,
                             "código", exitCode, "en", Urls.host(view.url.toString()))
        }
        // Avisos de assets/scripts/drm.js, media.js y passwords.js. Los de
        // contraseñas llevan la clave de BrowserProfile: sin ella son de la
        // página y no se atienden. Con este manejador, el motor no los
        // escribe en el registro (ahí irían contraseñas)
        onJavaScriptConsoleMessage: (level, message) => {
            const passwords = BrowserProfile.passwordPrefix
            if (message.startsWith(passwords)) {
                root._passwordMessage(message.slice(passwords.length))
            } else if (message === "mitis:widevine-unavailable") {
                root.protectedContentUnavailable()
            } else if (message.startsWith("mitis:webauthn:")) {
                root._passkeyMessage(message.slice(15))
            } else if (message.startsWith("mitis:screenshare:")) {
                root._screenShareMessage(message.slice(18))
            } else if (message.startsWith("mitis:capture ")) {
                const parts = message.slice(14).split(" ")
                captureState.set(Number(parts[0]), Number(parts[1]))
            }
        }
        // window.print(): la ventana de imprimir propia, no la del motor
        onPrintRequested: root.printRequested()
        onPdfPrintingFinished: (filePath, success) => {
            const job = root._pdfJob
            root._pdfJob = null
            if (job && job.done)
                job.done(success ? filePath : "")
            if (root._pdfNext) {
                const next = root._pdfNext
                root._pdfNext = null
                root._startPdf(next)
            }
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
            // Bloqueados en Configuración: se deniegan sin preguntar ni guardar
            // nada (así, al desbloquearlos, el sitio vuelve a preguntar)
            const blocked = Settings.blockedPermissions
            const parts = { cameraMicrophone: ["camera", "microphone"], screenAudio: ["screen"] }
            if ((parts[kind] ?? [kind]).some(part => blocked.includes(part))) {
                permission.deny()
                permission.reset()
                return
            }
            // Compartir pantalla: el motor pide el permiso después de elegir
            // qué en ScreenShareDialog, que ya es la respuesta del usuario
            if ((kind === "screen" || kind === "screenAudio")
                    && Date.now() - root._screenShareChosen < 15000) {
                root._screenShareChosen = 0
                permission.grant()
                return
            }
            // Cámara y micrófono los recuerda BrowserProfile (el motor no);
            // en las ventanas privadas, nunca: ni se usan ni se guardan
            const origin = permission.origin.toString()
            const media = !root.privateMode
                && (kind === "camera" || kind === "microphone" || kind === "cameraMicrophone")
            const saved = media ? BrowserProfile.mediaPermission(origin, kind) : undefined
            if (saved !== undefined) {
                saved ? permission.grant() : permission.deny()
                return
            }
            root.permissionRequested({
                kind: kind,
                origin: origin,
                remembered: !root.privateMode && (media || permission.isPersistent(type)),
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
                canSelectAll: (flags & ContextMenuRequest.CanSelectAll) !== 0,
                // Corrector: la palabra mal escrita bajo el ratón y sus sugerencias
                misspelledWord: request.misspelledWord,
                suggestions: request.spellCheckerSuggestions
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
        if (!visible)
            suspendState.hiddenSince = Date.now()
        view.zoomFactor = zoomState.level
        _applyScrollbars(false)
        if (initialUrl !== "" && !deferred)
            view.url = initialUrl
    }
}

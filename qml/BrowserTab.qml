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

    // ── Estado de la página ──────────────────────────────────────────
    // Hasta que el motor empieza a cargar (o mientras espera, si es una
    // restaurada), la dirección es la que se le pidió
    readonly property url url: view.url.toString() !== "" ? view.url : initialUrl
    readonly property alias title: view.title
    // Icono de la página (image://favicon/…, del motor). Qt WebEngine se cae
    // al servir un icono que también tiene una pestaña descargada (pide el
    // dibujo a una página que ya no existe), así que la interfaz no pide los
    // de las pestañas con iconRetired (ver displayIcon() en Main.qml)
    readonly property alias icon: view.icon
    // Descargada o a punto de descargarse (suspend() espera un momento tras
    // avisar, para que acabe lo que ya se pidió): su icono ya no se pide al motor
    readonly property bool iconRetired: _discardPending
                                        || view.lifecycleState === WebEngineView.LifecycleState.Discarded
    property bool _discardPending: false
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

    // Zoom de esta pestaña (1 = 100 %). Se mantiene al navegar dentro de ella.
    // Para cambiarlo, setZoom(); hasta entonces (y tras resetZoom()) sigue al
    // zoom predeterminado de Configuración.
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
    readonly property bool certificateErrorPending: certState.pending !== null
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
                || devTools.item)
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
    }
    // Vuelve al zoom predeterminado (y lo sigue si cambia)
    function resetZoom() {
        zoomState.level = Qt.binding(() => Settings.defaultZoom)
    }
    // Saca la página de pantalla completa sin esperar a que ella responda
    function exitFullScreen() {
        if (view.isFullScreen)
            view.fullScreenCancelled()
    }
    // Carga en esta pestaña lo que otra pidió abrir (ver newTabRequested)
    function adopt(request) {
        pageState.adopted = true
        request.openIn(view)
    }

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
        root._cancelCertificateError()
        CaptureIndicator.report(root, 0, 0)
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
        const css = MitisEngine.cosmeticCss(address)
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
    // Congelar es inmediato; descargar, tras retirar el icono (iconRetired)
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
    // El sitio tiene permiso para mandar notificaciones
    function _canNotify() {
        const origin = /^https?:\/\/[^\/?#]+/i.exec(view.url.toString())
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
        property real level: Settings.defaultZoom
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
        profile: root.privateMode ? BrowserProfile.privateProfile : BrowserProfile.profile
        // Visor de PDF integrado (también lo esperan algunos sitios: un
        // navegador sin él parece un motor embebido)
        settings.pluginsEnabled: true
        settings.pdfViewerEnabled: true
        // Sin esto el motor rechaza la pantalla completa de vídeos y páginas
        settings.fullScreenSupportEnabled: true
        // Preferencias de Configuración; el motor las aplica sin recargar
        settings.javascriptEnabled: Settings.javascript
        settings.autoLoadImages: Settings.images
        // Sin esto, una ventana emergente solo se abre tras un clic del usuario
        settings.javascriptCanOpenWindows: !Settings.blockPopups
        settings.playbackRequiresUserGesture: !Settings.autoplay
        settings.forceDarkMode: Settings.darkPages
        settings.webRTCPublicInterfacesOnly: Settings.hideLocalIp

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
            // Conexiones seguras: una página subida de http a https que no
            // carga por https (sin conexión segura, certificado no válido,
            // respuesta vacía…) se vuelve a pedir por http (ver RequestInterceptor)
            // qmllint disable unqualified
            if (loadingInfo.status === WebEngineView.LoadSucceededStatus)
                MitisEngine.confirmHttps(loadingInfo.url)
            if (loadingInfo.status === WebEngineView.LoadFailedStatus
                    && MitisEngine.takeHttpsFallback(loadingInfo.url)) {
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
            if (MitisEngine.isHttpsUpgrade(error.url)) {
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
        // Avisos de assets/scripts/drm.js y media.js
        onJavaScriptConsoleMessage: (level, message) => {
            if (message === "mitis:widevine-unavailable") {
                root.protectedContentUnavailable()
            } else if (message.startsWith("mitis:capture ")) {
                const parts = message.slice(14).split(" ")
                captureState.set(Number(parts[0]), Number(parts[1]))
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
        if (!visible)
            suspendState.hiddenSince = Date.now()
        view.zoomFactor = zoomState.level
        _applyScrollbars(false)
        if (initialUrl !== "" && !deferred)
            view.url = initialUrl
    }
}

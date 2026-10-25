pragma Singleton
import QtCore as Core
import QtQml
import QtWebEngine
import Mitis.Core

import "urls.js" as Urls

// Perfil de navegación de Mitis: el único sitio, junto con BrowserTab.qml,
// que conoce el motor (Qt WebEngine). El perfil lo crea C++ (EngineBridge:
// en disco, con el interceptor de peticiones); aquí se completa (scripts,
// carpeta de descargas, idiomas) y se atiende lo que pide (descargas,
// permisos). Cookies, sesiones y caché persisten entre sesiones. Las ventanas
// privadas usan otro perfil, solo en memoria (privateProfile), que se
// descarta al cerrar la última.
QtObject {
    id: root

    // Perfil de las ventanas normales. Vive toda la app: en --dev no se
    // vuelve a crear en cada recarga (_setup se puede repetir sin duplicar).
    // Permisos concedidos o bloqueados (ubicación, notificaciones…): los guarda
    // el propio motor en el disco del perfil, por sitio. Cámara y micrófono
    // son la excepción: ver mediaPermission().
    // qmllint disable unqualified
    readonly property WebEngineProfile profile: MitisEngine.profile
    // qmllint enable unqualified
    // Carpeta donde van las descargas (Configuración → Descargas)
    readonly property string downloadPath: profile.downloadPath

    // Descargas en curso: id de Downloads → objeto del motor. Guardarlas aquí
    // evita que el recolector de JS las destruya antes de terminar
    property var _downloads: ({})

    // Hosts cuyo certificado inválido aceptó el usuario en esta sesión (host
    // → true). El motor ya los recuerda y no vuelve a preguntar; esto solo
    // permite que la interfaz sepa que la página no es segura. Se reasigna
    // entero para que las enlazadas se actualicen.
    property var certificateExceptions: ({})

    // Carpeta de descargas del sistema, la de serie si en Configuración no se
    // elige otra (ver Settings.downloadFolder)
    property string systemDownloadPath: ""

    // Versión principal de Chromium del motor, para «Acerca de Mitis» (el
    // User-Agent solo trae la principal: "Chrome/140.0.0.0")
    readonly property string chromiumVersion: (/Chrome\/(\d+)/.exec(profile.httpUserAgent) ?? [])[1] ?? ""

    // Carpeta de licencias del paquete ("" en una compilación sin instalar)
    // qmllint disable unqualified
    readonly property string licensesPath: MitisEngine.licensesPath
    // qmllint enable unqualified

    // El motor tiene Widevine (contenido protegido). Lo decide C++ al arrancar.
    property bool widevineAvailable: false

    // ── Bloqueador de anuncios y rastreadores (C++: ContentBlocker) ──
    // Estado para Configuración; las preferencias se enlazan al arrancar
    // qmllint disable unqualified
    readonly property int adBlockRules: MitisEngine.adBlockRules
    // Fecha de las listas (inválida si nunca se descargaron)
    readonly property date adBlockUpdated: MitisEngine.adBlockUpdated
    readonly property bool adBlockUpdating: MitisEngine.adBlockUpdating
    // Peticiones bloqueadas desde que se abrió Mitis
    readonly property real adBlockBlocked: MitisEngine.adBlockBlocked
    function updateFilterLists() {
        MitisEngine.updateFilterLists()
    }
    // Sitio de una dirección para permitir anuncios ("https://www.a.com/x" → "a.com")
    function siteOf(address) {
        return MitisEngine.siteOf(address)
    }

    // ── Certificado de un sitio (panel del sitio) ────────────────────
    // Lo consulta C++ con su propia conexión; la respuesta llega con
    // certificateReady(host, datos) (ver EngineBridge::certificateReady)
    signal certificateReady(string host, var certificate)
    function requestCertificate(host) {
        if (typeof MitisEngine.requestCertificate === "function")
            MitisEngine.requestCertificate(host)
        else
            root.certificateReady(host, { error: "Para ver el certificado hay que recompilar Mitis." })
    }
    readonly property Connections _certificates: Connections {
        target: MitisEngine
        ignoreUnknownSignals: true
        function onCertificateReady(host, certificate) {
            root.certificateReady(host, certificate)
        }
    }
    // qmllint enable unqualified

    // Cámara y micrófono: el motor no guarda la respuesta (para él valen solo
    // mientras dura la página) y preguntaría en cada visita. Mitis la guarda
    // aquí, como Chrome: "origen tipo" → true (permitido) o false (bloqueado).
    // Compartir pantalla no se guarda: se pregunta siempre, también en Chrome.
    property var _mediaPermissions: JSON.parse(Settings.value("Permissions/media", "{}"))

    // Respuesta guardada para `kind` en `origin`: true, false o undefined
    function mediaPermission(origin, kind) {
        return _mediaPermissions[origin + " " + kind]
    }
    function setMediaPermission(origin, kind, allowed) {
        _mediaPermissions[origin + " " + kind] = allowed
        Settings.setValue("Permissions/media", JSON.stringify(_mediaPermissions))
    }

    readonly property Connections _profileConnection: Connections {
        target: root.profile
        function onDownloadRequested(download) {
            root._requestDownload(download, false)
        }
    }

    // Con «Preguntar dónde guardar» (Configuración → Descargas), antes de
    // empezar cada descarga. `request`: { fileName, folder (ruta local),
    // accept(folder), reject() }. Lo atiende una ventana (Main).
    signal downloadFolderRequested(var request)
    // Una página pidió una descarga (`view`: su WebEngineView, o null). La
    // pestaña que se abrió solo para ella se cierra (ver BrowserTab)
    signal downloadStarted(var view)
    // Descargas esperando carpeta (que el recolector no las destruya)
    property var _awaitingFolder: []

    // ── Ventanas privadas ────────────────────────────────────────────
    // Iconos del motor (image://favicon/…) que la interfaz ya no debe pedir:
    // los de pestañas que se descargaron alguna vez, en cualquier ventana (ver
    // BrowserTab.icon). Solo crece: un icono retirado lo sigue estando aunque
    // se cierre su pestaña (se muestra el del servicio de iconos)
    property var retiredIcons: ({})
    function retireIcon(icon) {
        if (!icon.startsWith("image://") || retiredIcons[icon] === true)
            return
        const copy = Object.assign({}, retiredIcons)
        copy[icon] = true
        retiredIcons = copy
    }

    // Sin disco: cookies, caché y permisos viven solo mientras haya alguna
    // ventana privada abierta. Se crea con la primera y se descarta al
    // cerrar la última: cada ventana privada llama a retainPrivate() al
    // abrirse (antes de crear pestañas) y a releasePrivate() al cerrarse.
    property WebEngineProfile privateProfile: null
    property int _privateWindows: 0

    function retainPrivate() {
        _privateWindows++
        if (!privateProfile) {
            // qmllint disable unqualified
            const created = MitisEngine.createPrivateProfile()
            // qmllint enable unqualified
            _setup(created)
            created.downloadRequested.connect(download => root._requestDownload(download, true))
            privateProfile = created
        }
    }
    function releasePrivate() {
        _privateWindows--
        // Después de que se destruyan las páginas de la ventana
        Qt.callLater(() => {
            if (_privateWindows > 0 || !privateProfile)
                return
            // qmllint disable unqualified
            MitisEngine.destroyPrivateProfile(privateProfile)
            // qmllint enable unqualified
            privateProfile = null
        })
    }

    // ── Borrar datos de navegación (Configuración) ───────────────────
    function clearCookies() {
        // qmllint disable unqualified
        MitisEngine.clearCookies(root.profile)
        // qmllint enable unqualified
    }
    function clearCache() {
        root.profile.clearHttpCache()
    }
    // Lo decidido para cada sitio: lo que guarda el motor y cámara y micrófono
    function clearPermissions() {
        for (const permission of root.profile.listAllPermissions())
            permission.reset()
        _mediaPermissions = {}
        Settings.setValue("Permissions/media", "{}")
    }

    // ── Permisos guardados por sitio (Configuración) ─────────────────
    // [{ origin, kind, allowed }], ordenados por sitio. Los que guarda el
    // motor (ubicación, notificaciones…) y los de cámara y micrófono.
    readonly property var _permissionKinds: ({
        [WebEnginePermission.PermissionType.Geolocation]: "location",
        [WebEnginePermission.PermissionType.Notifications]: "notifications",
        [WebEnginePermission.PermissionType.ClipboardReadWrite]: "clipboard",
        [WebEnginePermission.PermissionType.LocalFontsAccess]: "fonts"
    })
    function sitePermissions() {
        const list = []
        for (const permission of root.profile.listAllPermissions()) {
            const kind = _permissionKinds[permission.permissionType]
            if (kind === undefined || permission.state === WebEnginePermission.State.Ask)
                continue
            list.push({ origin: permission.origin.toString(), kind: kind,
                        allowed: permission.state === WebEnginePermission.State.Granted })
        }
        for (const key in _mediaPermissions) {
            const space = key.lastIndexOf(" ")
            list.push({ origin: key.slice(0, space), kind: key.slice(space + 1), allowed: _mediaPermissions[key] })
        }
        return list.sort((a, b) => a.origin.localeCompare(b.origin) || a.kind.localeCompare(b.kind))
    }
    // Olvida lo decidido para `kind` en `origin`: el sitio volverá a preguntar
    function forgetSitePermission(origin, kind) {
        const key = origin + " " + kind
        if (key in _mediaPermissions) {
            delete _mediaPermissions[key]
            Settings.setValue("Permissions/media", JSON.stringify(_mediaPermissions))
            return
        }
        for (const permission of root.profile.listAllPermissions()) {
            if (permission.origin.toString() === origin && _permissionKinds[permission.permissionType] === kind)
                permission.reset()
        }
    }

    // Idiomas de Settings → cabecera Accept-Language ("es,en;q=0.9")
    function _acceptLanguage(languages) {
        return languages.map((language, index) =>
            index === 0 ? language : language + ";q=" + Math.max(0.1, 1 - index / 10).toFixed(1)).join(",")
    }

    Component.onCompleted: {
        // Las descargas van a la carpeta elegida en Configuración o, si no hay,
        // a la de descargas del sistema (no la del perfil: en --dev ya puede
        // tener la de Configuración de antes de recargar)
        root.systemDownloadPath = Urls.localPath(Core.StandardPaths.writableLocation(Core.StandardPaths.DownloadLocation))

        // Preferencias que aplica C++ petición a petición (interceptor y
        // filtro de cookies), para los dos perfiles
        // qmllint disable unqualified
        const engine = MitisEngine
        // qmllint enable unqualified
        engine.blockThirdPartyCookies = Qt.binding(() => Settings.blockThirdPartyCookies)
        engine.doNotTrack = Qt.binding(() => Settings.doNotTrack)
        engine.httpsUpgrade = Qt.binding(() => Settings.httpsUpgrade)
        engine.adBlockAllowedSites = Qt.binding(() => Settings.adBlockAllowedSites)
        engine.stripTrackingParams = Qt.binding(() => Settings.stripTrackingParams)
        // El último: al activarse carga las listas (y las descarga si faltan)
        engine.adBlock = Qt.binding(() => Settings.blockAds)
        // «Borrar cookies y caché al cerrar»: se borran al cerrar la ventana
        // (Main) y, por si el cierre no llegó a terminar, también al abrir
        if (Settings.clearOnExit) {
            clearCookies()
            clearCache()
        }
        _setup(root.profile)
        _updatePreload()
    }

    // Precarga de páginas (Settings.preloadPages, assets/scripts/preload.js):
    // solo en el perfil normal (en las ventanas privadas, nunca: avisaría a
    // los sitios de por dónde pasa el ratón). Al cambiar la opción vale para
    // las páginas que se abran desde entonces
    readonly property Connections _preloadSetting: Connections {
        target: Settings
        function onPreloadPagesChanged() {
            root._updatePreload()
        }
    }
    function _updatePreload() {
        const scripts = root.profile.userScripts
        for (const old of scripts.find("mitis-preload"))
            scripts.remove(old)
        if (!Settings.preloadPages)
            return
        const preload = WebEngine.script()
        preload.name = "mitis-preload"
        preload.sourceUrl = "qrc:/scripts/preload.js"
        preload.injectionPoint = WebEngineScript.DocumentReady
        preload.worldId = WebEngineScript.ApplicationWorld
        root._insertScript(root.profile, preload)
    }

    // Pone un script en todas las páginas del perfil; si ya estaba (otra
    // recarga de --dev), lo sustituye
    function _insertScript(profile, script) {
        for (const old of profile.userScripts.find(script.name))
            profile.userScripts.remove(old)
        profile.userScripts.insert(script)
    }

    // Lo común a los dos perfiles: User-Agent, carpeta de descargas, idiomas y
    // scripts inyectados (el interceptor lo pone C++ al crearlos)
    function _setup(profile) {
        // Mitis se presenta como un Chrome normal: el User-Agent de serie incluye
        // "QtWebEngine/x.y.z", que algunos sitios (WhatsApp Web) no reconocen y
        // rechazan. Se conserva la versión real de Chromium: no inventar otra.
        profile.httpUserAgent = profile.httpUserAgent.replace(/ QtWebEngine\/\S+/, "")
        profile.downloadPath = Qt.binding(() => Settings.downloadFolder || root.systemDownloadPath)
        profile.httpAcceptLanguage = Qt.binding(() => root._acceptLanguage(Settings.languages))
        // Corrector: solo español, con el diccionario que viaja con Mitis
        // (assets/dictionaries/es.bdic; main.cpp le dice al motor dónde está).
        // No se pueden añadir otros idiomas ni palabras
        profile.spellCheckLanguages = ["es"]
        profile.spellCheckEnabled = Qt.binding(() => Settings.spellCheck)

        // Puente con el contenido multimedia (mini reproductor), en todas las páginas
        const script = WebEngine.script()
        script.name = "mitis-media"
        script.sourceUrl = "qrc:/scripts/media.js"
        script.injectionPoint = WebEngineScript.DocumentCreation
        script.worldId = WebEngineScript.MainWorld
        root._insertScript(profile, script)

        // qmllint disable unqualified
        const engine = MitisEngine
        // qmllint enable unqualified

        // Contenido protegido: sin Widevine, detectar las páginas que lo piden
        // para explicar cómo instalarlo (assets/scripts/drm.js). Con él, nada.
        root.widevineAvailable = engine.widevinePath !== ""
        if (!root.widevineAvailable) {
            const drm = WebEngine.script()
            drm.name = "mitis-drm"
            drm.sourceUrl = "qrc:/scripts/drm.js"
            drm.injectionPoint = WebEngineScript.DocumentCreation
            drm.worldId = WebEngineScript.MainWorld
            drm.runsOnSubFrames = true
            root._insertScript(profile, drm)
        }
        // Inicio de sesión de Google: completa window.chrome como en Chrome
        // (assets/scripts/google.js); solo en accounts.google.com
        const google = WebEngine.script()
        google.name = "mitis-google-signin"
        google.sourceUrl = "qrc:/scripts/google.js"
        google.injectionPoint = WebEngineScript.DocumentCreation
        google.worldId = WebEngineScript.MainWorld
        google.runsOnSubFrames = true
        root._insertScript(profile, google)

        // Deslizar entre páginas (macOS, NavigationGestures): si el gesto
        // horizontal es de la página (assets/scripts/swipe.js). Solo el marco
        // principal: lo de dentro de otro marco no se sabe y no navega
        if (Qt.platform.os === "osx" || Qt.platform.os === "macos") {
            const swipe = WebEngine.script()
            swipe.name = "mitis-swipe"
            swipe.sourceUrl = "qrc:/scripts/swipe.js"
            swipe.injectionPoint = WebEngineScript.DocumentCreation
            swipe.worldId = WebEngineScript.ApplicationWorld
            root._insertScript(profile, swipe)
        }
    }

    // Antes de empezar: si hay que preguntar la carpeta, espera la respuesta
    function _requestDownload(download, privateMode) {
        root.downloadStarted(download.view)
        if (!Settings.askDownloadFolder) {
            _startDownload(download, privateMode)
            return
        }
        _awaitingFolder.push(download)
        let answered = false
        const settle = () => {
            answered = true
            _awaitingFolder = _awaitingFolder.filter(item => item !== download)
        }
        root.downloadFolderRequested({
            fileName: download.downloadFileName,
            folder: download.downloadDirectory,
            accept: folder => {
                if (answered)
                    return
                settle()
                download.downloadDirectory = folder
                root._startDownload(download, privateMode)
            },
            reject: () => {
                if (answered)
                    return
                settle()
                download.cancel()
            }
        })
    }

    // Acepta la descarga y la refleja en Downloads hasta que termina. El nombre
    // no se toca: el motor ya evita sobrescribir añadiendo " (1)", " (2)"…
    function _startDownload(download, privateMode) {
        download.accept()
        const folder = download.downloadDirectory
        const id = Downloads.add({
            privateMode: privateMode,
            fileName: download.downloadFileName,
            path: folder + "/" + download.downloadFileName,
            folder: folder,
            url: download.url.toString(),
            total: download.totalBytes
        }, {
            cancel: () => download.cancel(),
            pause: () => download.pause(),
            resume: () => download.resume()
        })
        root._downloads[id] = download

        // Estado completo; también envía los bytes recibidos, así la última
        // cifra llega siempre aunque se haya saltado por el límite de abajo
        const sync = () => {
            const state = root._downloadState(download)
            const changes = {
                state: state,
                received: download.receivedBytes,
                total: state === "done" ? download.receivedBytes : download.totalBytes
            }
            if (state === "failed")
                changes.error = root._downloadError(download)
            Downloads.update(id, changes)
            if (!Downloads.isActive(state))
                delete root._downloads[id]
        }

        // Como mucho ~10 actualizaciones de progreso por segundo
        let lastProgress = 0
        download.receivedBytesChanged.connect(() => {
            const now = Date.now()
            if (now - lastProgress < 100)
                return
            lastProgress = now
            Downloads.update(id, { received: download.receivedBytes })
        })
        download.totalBytesChanged.connect(() => Downloads.update(id, { total: download.totalBytes }))
        download.stateChanged.connect(sync)
        download.isPausedChanged.connect(sync)
        download.downloadFileNameChanged.connect(() => Downloads.update(id, {
            fileName: download.downloadFileName,
            path: download.downloadDirectory + "/" + download.downloadFileName
        }))
        sync()
    }

    // Estado del motor → estado de Downloads
    function _downloadState(download) {
        switch (download.state) {
        case WebEngineDownloadRequest.DownloadCompleted:
            return "done"
        case WebEngineDownloadRequest.DownloadCancelled:
            return "canceled"
        case WebEngineDownloadRequest.DownloadInterrupted:
            return download.interruptReason === WebEngineDownloadRequest.UserCanceled ? "canceled" : "failed"
        default:
            return download.isPaused ? "paused" : "progress"
        }
    }

    // Motivo legible de una descarga fallida
    function _downloadError(download) {
        const reasons = {
            [WebEngineDownloadRequest.FileFailed]: "No se pudo guardar el archivo",
            [WebEngineDownloadRequest.FileAccessDenied]: "Sin permiso para guardar en la carpeta",
            [WebEngineDownloadRequest.FileNoSpace]: "No queda espacio en el disco",
            [WebEngineDownloadRequest.FileNameTooLong]: "El nombre del archivo es demasiado largo",
            [WebEngineDownloadRequest.FileTooLarge]: "El archivo es demasiado grande",
            [WebEngineDownloadRequest.FileVirusInfected]: "El archivo contiene un virus",
            [WebEngineDownloadRequest.FileTransientError]: "Error temporal al guardar el archivo",
            [WebEngineDownloadRequest.FileBlocked]: "El sistema bloqueó el archivo",
            [WebEngineDownloadRequest.FileSecurityCheckFailed]: "Falló la comprobación de seguridad",
            [WebEngineDownloadRequest.FileTooShort]: "El archivo llegó incompleto",
            [WebEngineDownloadRequest.FileHashMismatch]: "El archivo no coincide con el original",
            [WebEngineDownloadRequest.NetworkFailed]: "Error de red",
            [WebEngineDownloadRequest.NetworkTimeout]: "La conexión tardó demasiado",
            [WebEngineDownloadRequest.NetworkDisconnected]: "Sin conexión a internet",
            [WebEngineDownloadRequest.NetworkServerDown]: "El servidor no responde",
            [WebEngineDownloadRequest.NetworkInvalidRequest]: "Petición no válida",
            [WebEngineDownloadRequest.ServerFailed]: "Error del servidor",
            [WebEngineDownloadRequest.ServerBadContent]: "El archivo no está en el servidor",
            [WebEngineDownloadRequest.ServerUnauthorized]: "El servidor pide iniciar sesión",
            [WebEngineDownloadRequest.ServerCertProblem]: "Certificado del servidor no válido",
            [WebEngineDownloadRequest.ServerForbidden]: "El servidor denegó el acceso",
            [WebEngineDownloadRequest.ServerUnreachable]: "No se puede contactar con el servidor",
            // Códigos de Chromium que Qt no incluye en su enumeración. Para
            // ellos interruptReasonString dice, por error, "Download canceled
            // by the user": no se usa.
            15: "El archivo de destino es el mismo que el de origen",
            31: "El servidor no permite reanudar la descarga",
            38: "La descarga llegó incompleta: el servidor cortó la conexión",
            39: "El servidor redirigió la descarga a otro sitio",
            41: "Se cerró el navegador durante la descarga",
            50: "El motor del navegador se cerró inesperadamente"
        }
        return reasons[download.interruptReason]
            ?? "Error de descarga (código " + download.interruptReason + ")"
    }
}

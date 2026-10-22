pragma Singleton
import QtCore as Core
import QtQml
import QtWebEngine
import Mitis.Core

import "urls.js" as Urls

// Perfil de navegación de Mitis: el único sitio, junto con BrowserTab.qml,
// que conoce el motor (Qt WebEngine). Cookies, sesiones y caché persisten
// entre sesiones. Las ventanas privadas usan otro perfil, solo en memoria
// (privateProfile), que se descarta al cerrar la última.
WebEngineProfile {
    id: root

    storageName: "Mitis"
    offTheRecord: false
    httpCacheType: WebEngineProfile.DiskHttpCache
    persistentCookiesPolicy: WebEngineProfile.AllowPersistentCookies
    // Permisos concedidos o bloqueados (ubicación, notificaciones…): los guarda
    // el propio motor en el disco del perfil, por sitio, y no vuelve a
    // preguntar. Sin código ni archivo propio de Mitis. Cámara y micrófono
    // son la excepción: ver mediaPermission().
    persistentPermissionsPolicy: WebEngineProfile.PersistentPermissionsPolicy.StoreOnDisk

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
    readonly property string chromiumVersion: (/Chrome\/(\d+)/.exec(httpUserAgent) ?? [])[1] ?? ""

    // El motor tiene Widevine (contenido protegido). Lo decide C++ al arrancar.
    property bool widevineAvailable: false

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

    onDownloadRequested: download => root._requestDownload(download, false)

    // Con «Preguntar dónde guardar» (Configuración → Descargas), antes de
    // empezar cada descarga. `request`: { fileName, folder (ruta local),
    // accept(folder), reject() }. Lo atiende una ventana (Main).
    signal downloadFolderRequested(var request)
    // Descargas esperando carpeta (que el recolector no las destruya)
    property var _awaitingFolder: []

    // ── Ventanas privadas ────────────────────────────────────────────
    // Sin disco: cookies, caché y permisos viven solo mientras haya alguna
    // ventana privada abierta. Se crea con la primera y se descarta al
    // cerrar la última: cada ventana privada llama a retainPrivate() al
    // abrirse (antes de crear pestañas) y a releasePrivate() al cerrarse.
    property WebEngineProfile privateProfile: null
    property int _privateWindows: 0

    function retainPrivate() {
        _privateWindows++
        if (!privateProfile) {
            const created = privateComponent.createObject(root) as WebEngineProfile
            _setup(created)
            privateProfile = created
        }
    }
    function releasePrivate() {
        _privateWindows--
        // Después de que se destruyan las páginas de la ventana
        Qt.callLater(() => {
            if (_privateWindows > 0 || !privateProfile)
                return
            privateProfile.destroy()
            privateProfile = null
        })
    }

    readonly property Component privateComponent: Component {
        WebEngineProfile {
            offTheRecord: true
            httpCacheType: WebEngineProfile.MemoryHttpCache
            persistentCookiesPolicy: WebEngineProfile.NoPersistentCookies
            persistentPermissionsPolicy: WebEngineProfile.PersistentPermissionsPolicy.StoreInMemory
            onDownloadRequested: download => root._requestDownload(download, true)
        }
    }

    // ── Borrar datos de navegación (Configuración) ───────────────────
    function clearCookies() {
        // qmllint disable unqualified
        MitisEngine.clearCookies(root)
        // qmllint enable unqualified
    }
    function clearCache() {
        root.clearHttpCache()
    }
    // Lo decidido para cada sitio: lo que guarda el motor y cámara y micrófono
    function clearPermissions() {
        for (const permission of root.listAllPermissions())
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
        for (const permission of root.listAllPermissions()) {
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
        for (const permission of root.listAllPermissions()) {
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
        // a la de descargas del sistema (el perfil ya la trae de serie; esto
        // solo cubre el caso raro de que venga vacía)
        root.systemDownloadPath = root.downloadPath
            || Urls.localPath(Core.StandardPaths.writableLocation(Core.StandardPaths.DownloadLocation))

        // Preferencias que aplica C++ petición a petición (interceptor y
        // filtro de cookies), para los dos perfiles
        // qmllint disable unqualified
        const engine = MitisEngine
        // qmllint enable unqualified
        engine.blockThirdPartyCookies = Qt.binding(() => Settings.blockThirdPartyCookies)
        engine.doNotTrack = Qt.binding(() => Settings.doNotTrack)
        engine.httpsUpgrade = Qt.binding(() => Settings.httpsUpgrade)
        // «Borrar cookies y caché al cerrar»: se borran al cerrar la ventana
        // (Main) y, por si el cierre no llegó a terminar, también al abrir
        if (Settings.clearOnExit) {
            clearCookies()
            clearCache()
        }
        _setup(root)
    }

    // Lo común a los dos perfiles: User-Agent, carpeta de descargas, scripts
    // inyectados e interceptor de peticiones
    function _setup(profile) {
        // Mitis se presenta como un Chrome normal: el User-Agent de serie incluye
        // "QtWebEngine/x.y.z", que algunos sitios (WhatsApp Web) no reconocen y
        // rechazan. Se conserva la versión real de Chromium: no inventar otra.
        profile.httpUserAgent = profile.httpUserAgent.replace(/ QtWebEngine\/\S+/, "")
        profile.downloadPath = Qt.binding(() => Settings.downloadFolder || root.systemDownloadPath)
        profile.httpAcceptLanguage = Qt.binding(() => root._acceptLanguage(Settings.languages))

        // Puente con el contenido multimedia (mini reproductor), en todas las páginas
        const script = WebEngine.script()
        script.name = "mitis-media"
        script.sourceUrl = "qrc:/scripts/media.js"
        script.injectionPoint = WebEngineScript.DocumentCreation
        script.worldId = WebEngineScript.MainWorld
        profile.userScripts.insert(script)

        // Inicio de sesión de Google: Google no admite navegadores con motor
        // embebido ni versiones de Chrome antiguas. En accounts.google.com Mitis
        // se presenta como el Google Chrome vigente: el interceptor (C++) ajusta
        // User-Agent y Client Hints, y este script lo que ve el JavaScript
        // (navigator.userAgent y navigator.userAgentData). Solo ese dominio.
        // qmllint disable unqualified
        const engine = MitisEngine
        // qmllint enable unqualified
        engine.installInterceptor(profile)

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
            profile.userScripts.insert(drm)
        }
        const version = engine.googleChromeVersion
        const major = version.split(".")[0]
        const google = WebEngine.script()
        google.name = "mitis-google-signin"
        google.sourceCode = "// ==UserScript==\n"
            + "// @match https://accounts.google.com/*\n"
            + "// ==/UserScript==\n"
            + "(function () {\n"
            + "  const full = " + JSON.stringify(version) + ", major = " + JSON.stringify(major) + ";\n"
            + "  const nav = Navigator.prototype;\n"
            + "  const ua = navigator.userAgent.replace(/Chrome\\/[\\d.]+/, 'Chrome/' + major + '.0.0.0');\n"
            + "  Object.defineProperty(nav, 'userAgent', { get: () => ua, configurable: true });\n"
            + "  Object.defineProperty(nav, 'appVersion', { get: () => ua.slice(8), configurable: true });\n"
            + "  const real = navigator.userAgentData;\n"
            + "  if (!real) return;\n"
            + "  const grease = real.brands.filter(b => b.brand !== 'Chromium');\n"
            + "  const brands = grease.concat([{ brand: 'Chromium', version: major }, { brand: 'Google Chrome', version: major }]);\n"
            + "  const data = {\n"
            + "    brands: brands, mobile: real.mobile, platform: real.platform,\n"
            + "    getHighEntropyValues: hints => real.getHighEntropyValues(hints).then(values => {\n"
            + "      values.brands = brands;\n"
            + "      if (values.fullVersionList) {\n"
            + "        values.fullVersionList = values.fullVersionList.filter(b => b.brand !== 'Chromium')\n"
            + "          .concat([{ brand: 'Chromium', version: full }, { brand: 'Google Chrome', version: full }]);\n"
            + "      }\n"
            + "      if (values.uaFullVersion) values.uaFullVersion = full;\n"
            + "      return values;\n"
            + "    }),\n"
            + "    toJSON: () => ({ brands: brands, mobile: real.mobile, platform: real.platform })\n"
            + "  };\n"
            + "  Object.setPrototypeOf(data, Object.getPrototypeOf(real));\n"
            + "  Object.defineProperty(nav, 'userAgentData', { get: () => data, configurable: true });\n"
            + "})();\n"
        google.injectionPoint = WebEngineScript.DocumentCreation
        google.worldId = WebEngineScript.MainWorld
        google.runsOnSubFrames = true
        profile.userScripts.insert(google)
    }

    // Antes de empezar: si hay que preguntar la carpeta, espera la respuesta
    function _requestDownload(download, privateMode) {
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

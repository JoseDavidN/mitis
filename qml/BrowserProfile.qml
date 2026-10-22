pragma Singleton
import QtCore
import QtQml
import QtWebEngine

// Perfil de navegación de Mitis: el único sitio, junto con BrowserTab.qml,
// que conoce el motor (Qt WebEngine). Cookies, sesiones y caché persisten
// entre sesiones.
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

    // El motor tiene Widevine (contenido protegido). Lo decide C++ al arrancar.
    property bool widevineAvailable: false

    // Cámara y micrófono: el motor no guarda la respuesta (para él valen solo
    // mientras dura la página) y preguntaría en cada visita. Mitis la guarda
    // aquí, como Chrome: "origen tipo" → true (permitido) o false (bloqueado).
    // Compartir pantalla no se guarda: se pregunta siempre, también en Chrome.
    readonly property Settings _permissionSettings: Settings {
        category: "Permissions"
    }
    property var _mediaPermissions: JSON.parse(_permissionSettings.value("media", "{}"))

    // Respuesta guardada para `kind` en `origin`: true, false o undefined
    function mediaPermission(origin, kind) {
        return _mediaPermissions[origin + " " + kind]
    }
    function setMediaPermission(origin, kind, allowed) {
        _mediaPermissions[origin + " " + kind] = allowed
        _permissionSettings.setValue("media", JSON.stringify(_mediaPermissions))
    }

    onDownloadRequested: download => root._startDownload(download)

    Component.onCompleted: {
        // Mitis se presenta como un Chrome normal: el User-Agent de serie incluye
        // "QtWebEngine/x.y.z", que algunos sitios (WhatsApp Web) no reconocen y
        // rechazan. Se conserva la versión real de Chromium: no inventar otra.
        root.httpUserAgent = root.httpUserAgent.replace(/ QtWebEngine\/\S+/, "")

        // Las descargas van a la carpeta de descargas del sistema; el perfil ya
        // la trae de serie, esto solo cubre el caso raro de que venga vacía
        if (!root.downloadPath)
            root.downloadPath = root._localPath(StandardPaths.writableLocation(StandardPaths.DownloadLocation))

        // Puente con el contenido multimedia (mini reproductor), en todas las páginas
        const script = WebEngine.script()
        script.name = "mitis-media"
        script.sourceUrl = "qrc:/scripts/media.js"
        script.injectionPoint = WebEngineScript.DocumentCreation
        script.worldId = WebEngineScript.MainWorld
        root.userScripts.insert(script)

        // Inicio de sesión de Google: Google no admite navegadores con motor
        // embebido ni versiones de Chrome antiguas. En accounts.google.com Mitis
        // se presenta como el Google Chrome vigente: el interceptor (C++) ajusta
        // User-Agent y Client Hints, y este script lo que ve el JavaScript
        // (navigator.userAgent y navigator.userAgentData). Solo ese dominio.
        // qmllint disable unqualified
        const engine = MitisEngine
        // qmllint enable unqualified
        engine.installInterceptor(root)

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
            root.userScripts.insert(drm)
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
        root.userScripts.insert(google)
    }

    // file:///home/x → /home/x; file:///C:/x → C:/x
    function _localPath(fileUrl) {
        const path = decodeURIComponent(fileUrl.toString().replace(/^file:\/\//, ""))
        return /^\/[A-Za-z]:/.test(path) ? path.slice(1) : path
    }

    // Acepta la descarga y la refleja en Downloads hasta que termina. El nombre
    // no se toca: el motor ya evita sobrescribir añadiendo " (1)", " (2)"…
    function _startDownload(download) {
        download.accept()
        const folder = download.downloadDirectory
        const id = Downloads.add({
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

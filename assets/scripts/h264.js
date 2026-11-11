// ==UserScript==
// @match https://www.youtube.com/*
// @match https://m.youtube.com/*
// @match https://music.youtube.com/*
// @match https://www.youtube-nocookie.com/*
// ==/UserScript==
//
// Vídeos de YouTube en H.264 (Settings.youtubeH264, Configuración →
// Rendimiento), como la extensión h264ify de Chrome. YouTube manda de serie
// AV1 o VP9, que las gráficas sin soporte (casi todas las anteriores a 2020
// para AV1) dejan al procesador; H.264 lo decodifica casi cualquier gráfica.
// YouTube elige el formato preguntando qué admite el navegador: a AV1 y VP9
// se le responde que no. También en sus vídeos dentro de otras páginas
// (runsOnSubFrames). Hasta 1080p: YouTube no da más en H.264.
(() => {
    const heavy = /vp0?9|av01/i
    if (window.MediaSource && MediaSource.isTypeSupported) {
        const isTypeSupported = MediaSource.isTypeSupported.bind(MediaSource)
        MediaSource.isTypeSupported = type => heavy.test(type) ? false : isTypeSupported(type)
    }
    const canPlayType = HTMLMediaElement.prototype.canPlayType
    HTMLMediaElement.prototype.canPlayType = function (type) {
        return heavy.test(type) ? "" : canPlayType.call(this, type)
    }
    const capabilities = navigator.mediaCapabilities
    if (capabilities && capabilities.decodingInfo) {
        const decodingInfo = capabilities.decodingInfo.bind(capabilities)
        capabilities.decodingInfo = config => heavy.test(config?.video?.contentType ?? "")
            ? Promise.resolve({ supported: false, smooth: false, powerEfficient: false })
            : decodingInfo(config)
    }
})()

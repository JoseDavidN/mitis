// Contenido protegido (Netflix, Spotify, Disney+…): avisa a Mitis cuando una
// página pide Widevine y el motor no lo tiene, para que explique cómo
// instalarlo. Solo se inyecta si Mitis no encontró Widevine al arrancar.
// El aviso es un mensaje de consola que BrowserTab reconoce.
(() => {
    const nav = navigator
    if (!nav.requestMediaKeySystemAccess || window.__mitisDrm)
        return
    window.__mitisDrm = true

    const original = nav.requestMediaKeySystemAccess.bind(nav)
    let reported = false

    // Una página puede probar varias configuraciones y que solo alguna falle:
    // se confirma con la más básica antes de avisar
    const confirmMissing = () => original("com.widevine.alpha", [{
        initDataTypes: ["cenc"],
        videoCapabilities: [{ contentType: 'video/mp4; codecs="avc1.42E01E"' }]
    }]).then(() => {}, () => {
        if (reported)
            return
        reported = true
        console.info("mitis:widevine-unavailable")
    })

    nav.requestMediaKeySystemAccess = function (keySystem, configurations) {
        const result = original(keySystem, configurations)
        if (!reported && String(keySystem).startsWith("com.widevine"))
            result.catch(confirmMissing)
        return result
    }
})()

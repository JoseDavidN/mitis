// Compartir pantalla propio (Wayland sin el portal del escritorio; ver
// src/screencapture.*). Solo se inyecta si Mitis puede capturar por su
// cuenta. getDisplayMedia() pide a Mitis que pregunte qué compartir
// (ScreenShareDialog) por un aviso de consola; Mitis responde con
// __mitisScreenShare.answer(). Los fotogramas (JPEG) llegan por
// mitis-captura://<clave>/<último> y se convierten en una pista de vídeo
// normal (MediaStreamTrackGenerator), que la página envía por WebRTC como
// cualquier pantalla compartida. Al parar la pista, la página avisa a Mitis;
// si Mitis la termina (se cerró la ventana), las peticiones fallan y la
// pista acaba con su evento «ended», como en Chrome.
(() => {
    const devices = window.MediaDevices && MediaDevices.prototype
    if (!devices || !devices.getDisplayMedia || !window.MediaStreamTrackGenerator)
        return
    const native = devices.getDisplayMedia
    const pending = new Map()
    let lastId = 0

    function startTrack(answer) {
        const track = new MediaStreamTrackGenerator({ kind: "video" })
        track.contentHint = "detail"
        const writer = track.writable.getWriter()
        let running = true
        const nativeSettings = track.getSettings.bind(track)
        const nativeStop = track.stop.bind(track)
        // Como una pantalla compartida del motor (Meet y otros lo miran)
        Object.defineProperties(track, {
            label: { value: answer.label },
            getSettings: {
                value: () => Object.assign(nativeSettings(), {
                    displaySurface: answer.surface, logicalSurface: true, cursor: "always"
                })
            },
            stop: {
                value: () => {
                    if (running) {
                        running = false
                        console.log("mitis:screenshare:stop " + answer.token)
                    }
                    nativeStop()
                }
            }
        })
        ;(async () => {
            let last = 0
            while (running) {
                let body
                try {
                    const response = await fetch(answer.url + last, { cache: "no-store" })
                    if (!response.ok)
                        break
                    body = await response.arrayBuffer()
                } catch (error) {
                    break
                }
                last = Number(new DataView(body).getBigUint64(0, true))
                let bitmap
                try {
                    bitmap = await createImageBitmap(new Blob([new Uint8Array(body, 8)], { type: "image/jpeg" }))
                } catch (error) {
                    continue
                }
                if (!running) {
                    bitmap.close()
                    break
                }
                const frame = new VideoFrame(bitmap, { timestamp: Math.round(performance.now() * 1000) })
                bitmap.close()
                try {
                    await writer.write(frame)
                } catch (error) {
                    frame.close()
                    break
                }
            }
            running = false
            // Cerrar lo que escribe termina la pista: la página recibe «ended»
            try {
                await writer.close()
            } catch (error) {}
        })()
        return new MediaStream([track])
    }

    // Mitis responde aquí (BrowserTab, runJavaScript): no se puede sustituir
    Object.defineProperty(window, "__mitisScreenShare", {
        value: Object.freeze({
            answer(id, answer) {
                const request = pending.get(id)
                if (!request)
                    return
                pending.delete(id)
                if (answer.native)
                    native.call(request.devices, request.options).then(request.resolve, request.reject)
                else if (answer.error)
                    request.reject(new DOMException(answer.message || "Permission denied", answer.error))
                else
                    request.resolve(startTrack(answer))
            }
        })
    })

    devices.getDisplayMedia = function getDisplayMedia(options) {
        // Como el motor: solo tras un clic o una tecla del usuario
        if (navigator.userActivation && !navigator.userActivation.isActive)
            return Promise.reject(new DOMException("getDisplayMedia requires transient activation from a user gesture.", "InvalidStateError"))
        return new Promise((resolve, reject) => {
            const id = ++lastId
            pending.set(id, { resolve, reject, options, devices: this })
            console.log("mitis:screenshare:request " + id)
        })
    }
})()

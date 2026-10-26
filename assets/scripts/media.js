// Mitis: puente con el contenido multimedia de la página, para el mini
// reproductor. Se inyecta al crear el documento, antes que los scripts de la
// página, para poder registrar los botones anterior/siguiente que la página
// declara en la Media Session (YouTube, Spotify, SoundCloud...).
//
// Mitis lo usa con runJavaScript:
//   window.__mitisMedia.state()           → estado o null si no hay nada
//   window.__mitisMedia.control(acción)   → "toggle", "next" o "previous"
//   window.__mitisMedia.capture()         → [micrófono, cámara] (ver abajo)
//
// Micrófono y cámara, para el aviso del icono de Mitis: 0 sin uso, 1 abierto
// pero silenciado, 2 en uso. Cuando cambia, lo avisa al momento con el
// mensaje de consola "mitis:capture <micrófono> <cámara>" (BrowserTab).
//
// Solo cuenta el contenido para escuchar o ver (música, vídeos, streaming).
// Las llamadas y reuniones (Meet, Zoom, Teams…) no: mientras la página usa
// la cámara o el micrófono, o tiene una conexión WebRTC abierta, no informa
// de nada, y los vídeos/audios que muestran una transmisión en directo de
// otra persona (srcObject) nunca cuentan.
(function () {
    "use strict";
    if (window.__mitisMedia)
        return;

    var handlers = {};
    var lastPlayed = null;
    var session = navigator.mediaSession;

    // Guarda una copia de las acciones que registra la página
    if (session && typeof session.setActionHandler === "function") {
        var original = session.setActionHandler.bind(session);
        session.setActionHandler = function (action, handler) {
            handlers[action] = handler || null;
            return original(action, handler);
        };
    }

    // Y la posición que publica (setPositionState): la duración y el punto
    // reales de la canción o el vídeo. Reproductores como Apple Music suenan
    // por elementos de audio que no son la pista entera (trozos, relleno de
    // pocos segundos): su duración y su posición engañan. Con la hora en que
    // llegó, para calcular por dónde va
    var positionState = null;
    if (session && typeof session.setPositionState === "function") {
        var originalPosition = session.setPositionState.bind(session);
        session.setPositionState = function (value) {
            positionState = value && isFinite(value.duration)
                ? { duration: value.duration, position: value.position || 0,
                    rate: value.playbackRate || 1, at: performance.now() }
                : null;
            return originalPosition.apply(null, arguments);
        };
    }

    // Capturas de cámara/micrófono/pantalla y conexiones WebRTC de la página.
    // `devices`: solo las de micrófono y cámara (getUserMedia), para el aviso
    var captures = [];
    var devices = [];
    var connections = [];

    function watchCapture(owner, name, isDevice) {
        if (!owner || typeof owner[name] !== "function")
            return;
        var original = owner[name];
        owner[name] = function () {
            return original.apply(this, arguments).then(function (stream) {
                captures.push(stream);
                if (isDevice) {
                    devices.push(stream);
                    watchDevices();
                }
                return stream;
            });
        };
    }
    if (navigator.mediaDevices) {
        watchCapture(navigator.mediaDevices, "getUserMedia", true);
        watchCapture(navigator.mediaDevices, "getDisplayMedia", false);
    }

    // La consola de la página puede cambiarla la propia página: se guarda la original
    var debug = console.debug.bind(console);
    var reported = "0 0";
    var watcher = null;

    // [micrófono, cámara]: 2 si alguna pista suena/graba, 1 si las abiertas
    // están silenciadas (enabled = false o sin señal), 0 si no hay ninguna
    function capture() {
        var result = [0, 0];
        devices = devices.filter(function (stream) {
            return stream.getTracks().some(live);
        });
        devices.forEach(function (stream) {
            stream.getTracks().forEach(function (track) {
                if (!live(track))
                    return;
                var index = track.kind === "audio" ? 0 : 1;
                result[index] = Math.max(result[index], track.enabled && !track.muted ? 2 : 1);
            });
        });
        return result;
    }

    // Mientras haya micrófono o cámara abiertos, mira cada medio segundo si
    // cambió algo (silenciar o colgar no avisan de forma fiable). Sin nada
    // abierto no hace nada.
    function checkDevices() {
        var now = capture().join(" ");
        if (now !== reported) {
            reported = now;
            debug("mitis:capture " + now);
        }
        if (now === "0 0" && watcher !== null) {
            clearInterval(watcher);
            watcher = null;
        }
    }
    function watchDevices() {
        checkDevices();
        if (watcher === null)
            watcher = setInterval(checkDevices, 500);
    }
    if (typeof window.RTCPeerConnection === "function") {
        var Native = window.RTCPeerConnection;
        var Wrapped = function () {
            var connection = Reflect.construct(Native, arguments, new.target || Native);
            connections.push(connection);
            return connection;
        };
        Wrapped.prototype = Native.prototype;
        Object.setPrototypeOf(Wrapped, Native);
        window.RTCPeerConnection = Wrapped;
        if (window.webkitRTCPeerConnection === Native)
            window.webkitRTCPeerConnection = Wrapped;
    }

    function live(track) {
        return !!track && track.readyState === "live";
    }

    // ¿Hay una llamada en curso? Micrófono, cámara o pantalla capturándose, o
    // una conexión WebRTC conectada que recibe audio o vídeo. Las conexiones
    // sin medios (huella del navegador, redes P2P de vídeo con canales de
    // datos) no cuentan.
    function inCall() {
        captures = captures.filter(function (stream) {
            return stream.getTracks().some(live);
        });
        connections = connections.filter(function (connection) {
            return connection.connectionState !== "closed";
        });
        return captures.length > 0 || connections.some(function (connection) {
            return connection.connectionState === "connected"
                && connection.getReceivers().some(function (receiver) {
                    return live(receiver.track);
                });
        });
    }

    // Vídeo o audio de una transmisión en directo (una llamada), no de un archivo
    function isStream(media) {
        return !!media.srcObject && typeof MediaStream !== "undefined"
            && media.srcObject instanceof MediaStream;
    }

    // "play" no burbujea: se escucha en la fase de captura
    document.addEventListener("play", function (event) {
        lastPlayed = event.target;
    }, true);

    // El que suena ahora; si no, el último que sonó y sigue en la página
    function current() {
        if (inCall())
            return null;
        var all = document.querySelectorAll("video, audio");
        for (var i = 0; i < all.length; i++) {
            if (!all[i].paused && !all[i].ended && !isStream(all[i]))
                return all[i];
        }
        return lastPlayed && lastPlayed.isConnected && !isStream(lastPlayed) ? lastPlayed : null;
    }

    // Carátula: la más grande que declare la página en la Media Session (la
    // de YouTube es la miniatura del vídeo, la de Spotify la del disco); si no
    // hay, la imagen de portada del vídeo. Dirección completa o ""
    function artwork(meta, media) {
        var best = "", bestSize = -1;
        var list = (meta && meta.artwork) || [];
        for (var i = 0; i < list.length; i++) {
            var size = parseInt(String(list[i].sizes || "0").split("x")[0], 10) || 0;
            if (list[i].src && size > bestSize) {
                best = list[i].src;
                bestSize = size;
            }
        }
        if (!best && media.poster)
            best = media.poster;
        try {
            return best ? new URL(best, location.href).href : "";
        } catch (e) {
            return "";
        }
    }

    // ¿Suena? Lo que dice la página (playbackState) si lo dice; si no, el elemento
    function isPlaying(media) {
        var declared = session && session.playbackState;
        if (declared === "playing" || declared === "paused")
            return declared === "playing";
        return !media.paused && !media.ended;
    }

    // [posición, duración] en segundos: la publicada por la página si la hay
    // (avanzada desde que llegó, si suena); si no, la del elemento. Duración 0
    // en un directo (Infinity): no se muestra el tiempo total
    function progress(media, playing) {
        if (positionState) {
            var elapsed = playing ? (performance.now() - positionState.at) / 1000 * positionState.rate : 0;
            return [Math.max(0, Math.min(positionState.duration, positionState.position + elapsed)),
                    positionState.duration];
        }
        return [media.currentTime || 0, isFinite(media.duration) ? media.duration : 0];
    }

    function state() {
        var media = current();
        if (!media)
            return null;
        var meta = session && session.metadata;
        var playing = isPlaying(media);
        var point = progress(media, playing);
        return {
            title: (meta && meta.title) || document.title || "",
            artist: (meta && meta.artist) || "",
            artwork: artwork(meta, media),
            playing: playing,
            position: point[0],
            duration: point[1],
            hasNext: !!handlers.nexttrack,
            hasPrevious: true
        };
    }

    // Las acciones van primero a lo que registró la página para los controles
    // del sistema (como hacen Chrome y los controles de macOS y Windows): su
    // reproductor lleva su propio estado y puede deshacer un play() o pause()
    // hecho directamente sobre el elemento. Sin ellas, el elemento.
    function control(action) {
        var media = current();
        if (!media)
            return null;
        var playing = isPlaying(media);
        if (action === "toggle") {
            var wanted = playing ? "pause" : "play";
            if (handlers[wanted])
                handlers[wanted]({ action: wanted });
            else if (playing)
                media.pause();
            else
                media.play();
        } else if (action === "next" && handlers.nexttrack) {
            handlers.nexttrack({ action: "nexttrack" });
        } else if (action === "previous") {
            // Como en cualquier reproductor: si ya avanzó, vuelve al inicio
            if (handlers.previoustrack && progress(media, playing)[0] < 3)
                handlers.previoustrack({ action: "previoustrack" });
            else if (handlers.seekto)
                handlers.seekto({ action: "seekto", seekTime: 0 });
            else
                media.currentTime = 0;
        }
        return state();
    }

    Object.defineProperty(window, "__mitisMedia", {
        value: Object.freeze({ state: state, control: control, capture: capture })
    });
})();

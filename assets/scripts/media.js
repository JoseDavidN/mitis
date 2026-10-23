// Mitis: puente con el contenido multimedia de la página, para el mini
// reproductor. Se inyecta al crear el documento, antes que los scripts de la
// página, para poder registrar los botones anterior/siguiente que la página
// declara en la Media Session (YouTube, Spotify, SoundCloud...).
//
// Mitis lo usa con runJavaScript:
//   window.__mitisMedia.state()           → estado o null si no hay nada
//   window.__mitisMedia.control(acción)   → "toggle", "next", "previous"
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

    function state() {
        var media = current();
        if (!media)
            return null;
        var meta = session && session.metadata;
        return {
            title: (meta && meta.title) || document.title || "",
            artist: (meta && meta.artist) || "",
            playing: !media.paused && !media.ended,
            hasNext: !!handlers.nexttrack,
            hasPrevious: true
        };
    }

    function control(action) {
        var media = current();
        if (!media)
            return null;
        if (action === "toggle") {
            if (media.paused)
                media.play();
            else
                media.pause();
        } else if (action === "next" && handlers.nexttrack) {
            handlers.nexttrack({ action: "nexttrack" });
        } else if (action === "previous") {
            // Como en cualquier reproductor: si ya avanzó, vuelve al inicio
            if (handlers.previoustrack && media.currentTime < 3)
                handlers.previoustrack({ action: "previoustrack" });
            else
                media.currentTime = 0;
        }
        return state();
    }

    Object.defineProperty(window, "__mitisMedia", {
        value: Object.freeze({ state: state, control: control, capture: capture })
    });
})();

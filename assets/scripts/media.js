// Mitis: puente con el contenido multimedia de la página, para el mini
// reproductor. Se inyecta al crear el documento, antes que los scripts de la
// página, para poder registrar los botones anterior/siguiente que la página
// declara en la Media Session (YouTube, Spotify, SoundCloud...).
//
// Mitis lo usa con runJavaScript:
//   window.__mitisMedia.state()           → estado o null si no hay nada
//   window.__mitisMedia.control(acción)   → "toggle", "next", "previous"
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

    // "play" no burbujea: se escucha en la fase de captura
    document.addEventListener("play", function (event) {
        lastPlayed = event.target;
    }, true);

    // El que suena ahora; si no, el último que sonó y sigue en la página
    function current() {
        var all = document.querySelectorAll("video, audio");
        for (var i = 0; i < all.length; i++) {
            if (!all[i].paused && !all[i].ended)
                return all[i];
        }
        return lastPlayed && lastPlayed.isConnected ? lastPlayed : null;
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
        value: Object.freeze({ state: state, control: control })
    });
})();

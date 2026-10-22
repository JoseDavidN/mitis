// ==UserScript==
// @match https://accounts.google.com/*
// ==/UserScript==
//
// Inicio de sesión de Google: Google rechaza los navegadores con motor
// embebido («Es posible que el navegador o la aplicación no sean seguros»).
// Qt WebEngine deja `window.chrome` vacío y Chrome trae `app`, `csi` y
// `loadTimes`: con ellos, y presentándose como lo que es (Chromium, sin
// disfrazarse de otra versión: la incoherencia también delata), Google lo
// admite. Comprobado en 2026-10 frente a Chrome for Testing 140 y 156.
// Solo en accounts.google.com.
(() => {
    if (!window.chrome)
        window.chrome = {}
    if (window.chrome.app)
        return
    const timing = performance.timing
    window.chrome.app = {
        isInstalled: false,
        InstallState: { DISABLED: "disabled", INSTALLED: "installed", NOT_INSTALLED: "not_installed" },
        RunningState: { CANNOT_RUN: "cannot_run", READY_TO_RUN: "ready_to_run", RUNNING: "running" },
        getDetails: function getDetails() { return null },
        getIsInstalled: function getIsInstalled() { return false },
        runningState: function runningState() { return "cannot_run" }
    }
    window.chrome.csi = function csi() {
        return { startE: timing.navigationStart, onloadT: timing.domContentLoadedEventEnd,
                 pageT: performance.now(), tran: 15 }
    }
    window.chrome.loadTimes = function loadTimes() {
        const segundos = ms => ms / 1000
        return {
            requestTime: segundos(timing.navigationStart),
            startLoadTime: segundos(timing.navigationStart),
            commitLoadTime: segundos(timing.responseStart),
            finishDocumentLoadTime: segundos(timing.domContentLoadedEventEnd),
            finishLoadTime: segundos(timing.loadEventEnd),
            firstPaintTime: segundos(timing.domContentLoadedEventEnd),
            firstPaintAfterLoadTime: 0,
            navigationType: "Other",
            wasFetchedViaSpdy: true,
            wasNpnNegotiated: true,
            npnNegotiatedProtocol: "h2",
            wasAlternateProtocolAvailable: false,
            connectionInfo: "h2"
        }
    }
})()

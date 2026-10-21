import QtQuick
import QtQuick.Window
import QtWebEngine

// Ventana mínima de arranque: solo comprueba que Qt y el motor funcionan.
// La interfaz propia de Mitis se construirá sobre esta base.
Window {
    id: win
    width: 1280
    height: 800
    visible: true
    title: web.title ? web.title + " — Mitis" : "Mitis"

    WebEngineView {
        id: web
        anchors.fill: parent
        url: "https://duckduckgo.com"
    }
}

pragma Singleton
import QtQuick
import Mitis.Core

import "urls.js" as Urls

// Motor de búsqueda de Mitis: la lista de buscadores, el elegido y uno
// personalizado. Lo usan la barra de dirección, la página de nueva pestaña,
// el menú contextual y el editor de accesos rápidos. Se elige en la página
// de Configuración y se guarda entre sesiones (Settings, categoría "Search").
QtObject {
    id: root

    // Buscadores incluidos. `url` lleva %s donde va el texto buscado.
    readonly property var engines: [
        { key: "duckduckgo", name: "DuckDuckGo", url: "https://duckduckgo.com/?q=%s" },
        { key: "google", name: "Google", url: "https://www.google.com/search?q=%s" },
        { key: "bing", name: "Bing", url: "https://www.bing.com/search?q=%s" },
        { key: "brave", name: "Brave Search", url: "https://search.brave.com/search?q=%s" },
        { key: "ecosia", name: "Ecosia", url: "https://www.ecosia.org/search?q=%s" },
        { key: "startpage", name: "Startpage", url: "https://www.startpage.com/do/search?q=%s" }
    ]

    // Buscador personalizado ("" si no hay). Se cambia con setCustom().
    readonly property string customName: Settings.searchCustomName
    readonly property string customUrl: Settings.searchCustomUrl
    readonly property bool hasCustom: customUrl !== ""

    // El elegido: { key, name, url }. Si lo guardado ya no existe, el primero.
    readonly property var current: {
        const key = Settings.searchEngine
        if (key === "custom" && hasCustom)
            return { key: "custom", name: customName, url: customUrl }
        for (let i = 0; i < engines.length; i++) {
            if (engines[i].key === key)
                return engines[i]
        }
        return engines[0]
    }
    readonly property string key: current.key
    readonly property string name: current.name

    function select(key) {
        Settings.searchEngine = key
    }

    // Plantilla válida: http(s), con dominio y con %s. Devuelve la plantilla
    // normalizada (con https:// si no trae esquema) o "" si no vale.
    function normalizeTemplate(text) {
        let url = text.trim()
        if (url.indexOf("%s") < 0 || /\s/.test(url))
            return ""
        if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(url))
            url = "https://" + url
        return /^https?:\/\/[^\/?#:]+\.[^\/?#:]+(:\d+)?([\/?#]|$)/i.test(url) ? url : ""
    }

    // Guarda el personalizado y lo elige. Devuelve false si la URL no vale.
    function setCustom(name, url) {
        const template = normalizeTemplate(url)
        if (template === "")
            return false
        Settings.searchCustomName = name.trim() || Urls.host(template) || template
        Settings.searchCustomUrl = template
        Settings.searchEngine = "custom"
        return true
    }

    // Dirección de búsqueda de `text` en el elegido
    function searchUrl(text) {
        return Urls.searchUrl(text, current.url)
    }

    // Lo buscado en una página de resultados de cualquiera de los buscadores
    // (también el personalizado): "https://duckduckgo.com/?q=gatos+negros"
    // → "gatos negros". "" si no es una búsqueda. Solo plantillas con el
    // texto en un parámetro (…?q=%s)
    function queryOf(address) {
        const templates = engines.map(engine => engine.url)
        if (hasCustom)
            templates.push(customUrl)
        const page = address.split(/[?#]/)[0].replace(/^(https?:\/\/)www\./i, "$1").replace(/\/$/, "").toLowerCase()
        for (const template of templates) {
            const head = template.slice(0, template.indexOf("%s"))
            const param = /[?&]([^?&=]+)=$/.exec(head)
            if (!param)
                continue
            const base = head.slice(0, param.index).replace(/^(https?:\/\/)www\./i, "$1").replace(/\/$/, "").toLowerCase()
            if (page !== base)
                continue
            const value = new RegExp("[?&]" + param[1] + "=([^&#]*)").exec(address)
            if (!value)
                continue
            try {
                return decodeURIComponent(value[1].replace(/\+/g, " ")).trim()
            } catch (e) {
                return ""
            }
        }
        return ""
    }

    // Lo escrito por el usuario → URL (o búsqueda en el elegido)
    function resolve(input) {
        return Urls.resolve(input, current.url)
    }
}

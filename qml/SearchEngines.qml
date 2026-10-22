pragma Singleton
import QtCore
import QtQuick

import "urls.js" as Urls

// Motor de búsqueda de Mitis: la lista de buscadores, el elegido y uno
// personalizado. Lo usan la barra de dirección, la página de nueva pestaña,
// el menú contextual y el editor de accesos rápidos. La elección se guarda
// entre sesiones (Settings, categoría "Search").
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
    property string customName: ""
    property string customUrl: ""
    readonly property bool hasCustom: customUrl !== ""

    // El elegido: { key, name, url }. Si lo guardado ya no existe, el primero.
    readonly property var current: {
        const key = _engine
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

    // Clave del elegido tal como se guarda
    property string _engine: "duckduckgo"

    readonly property Settings _settings: Settings {
        category: "Search"
        property alias engine: root._engine
        property alias customName: root.customName
        property alias customUrl: root.customUrl
    }

    function select(key) {
        _engine = key
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
        customName = name.trim() || Urls.host(template) || template
        customUrl = template
        _engine = "custom"
        return true
    }

    // Dirección de búsqueda de `text` en el elegido
    function searchUrl(text) {
        return Urls.searchUrl(text, current.url)
    }

    // Lo escrito por el usuario → URL (o búsqueda en el elegido)
    function resolve(input) {
        return Urls.resolve(input, current.url)
    }
}

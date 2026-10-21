pragma Singleton
import QtQuick

// Noticias de tecnología (RSS de Google Noticias) para la página de nueva
// pestaña. Una sola copia para todas las pestañas; se pide de nuevo solo si
// la anterior tiene más de `maxAge` ms.
QtObject {
    id: root

    readonly property string feedUrl:
        "https://news.google.com/rss/headlines/section/topic/TECHNOLOGY?hl=es-419&gl=CO&ceid=CO:es-419"
    readonly property int maxAge: 30 * 60 * 1000
    readonly property int maxItems: 8

    // Roles: title, source, link, published (ms desde 1970)
    readonly property ListModel items: ListModel {}
    property bool loading: false
    property bool failed: false
    property real fetchedAt: 0

    function refreshIfStale() {
        if (!loading && (items.count === 0 || Date.now() - fetchedAt > maxAge))
            refresh()
    }

    function refresh() {
        loading = true
        failed = false
        const request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            loading = false
            const parsed = request.status === 200 ? parse(request.responseText) : []
            if (parsed.length === 0) {
                failed = items.count === 0
                return
            }
            items.clear()
            parsed.slice(0, maxItems).forEach(item => items.append(item))
            fetchedAt = Date.now()
        }
        request.open("GET", feedUrl)
        request.send()
    }

    // "hace 5 min", "hace 3 h", "hace 2 d"
    function age(published) {
        const minutes = Math.max(1, Math.round((Date.now() - published) / 60000))
        if (minutes < 60)
            return "hace " + minutes + " min"
        if (minutes < 60 * 24)
            return "hace " + Math.round(minutes / 60) + " h"
        return "hace " + Math.round(minutes / (60 * 24)) + " d"
    }

    function decode(text) {
        return text.replace(/<!\[CDATA\[|\]\]>/g, "")
                   .replace(/&lt;/g, "<").replace(/&gt;/g, ">")
                   .replace(/&quot;/g, "\"").replace(/&#39;/g, "'")
                   .replace(/&amp;/g, "&").trim()
    }

    function tag(item, name) {
        const match = new RegExp("<" + name + "[^>]*>([\\s\\S]*?)</" + name + ">").exec(item)
        return match ? decode(match[1]) : ""
    }

    // El RSS es simple y fijo: basta con expresiones regulares
    function parse(xml) {
        const result = []
        const blocks = xml.match(/<item>[\s\S]*?<\/item>/g) || []
        for (const block of blocks) {
            const link = tag(block, "link")
            let title = tag(block, "title")
            const source = tag(block, "source")
            // Google añade " - Fuente" al final del título, y a veces el
            // medio repite " | Fuente" antes
            for (const separator of [" - ", " | "]) {
                if (source !== "" && title.endsWith(separator + source))
                    title = title.slice(0, -(source.length + separator.length))
            }
            if (title === "" || !/^https?:\/\//.test(link))
                continue
            result.push({
                title: title,
                source: source,
                link: link,
                published: Date.parse(tag(block, "pubDate")) || Date.now()
            })
        }
        return result
    }
}

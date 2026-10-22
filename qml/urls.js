.pragma library

// Dirección de búsqueda: `template` es la del buscador, con %s donde va el
// texto (la elige SearchEngines.qml; aquí no se guarda estado)
function searchUrl(text, template) {
    return template.split("%s").join(encodeURIComponent(text))
}

// Convierte lo que escribe el usuario en una URL navegable: si no parece
// una dirección, la busca con `template`. Devuelve "" si no hay nada que abrir.
function resolve(input, template) {
    var value = input.trim()
    if (value === "")
        return ""
    if (/\s/.test(value))
        return searchUrl(value, template)
    // Ya trae esquema: https://, file://, about:, etc.
    if (/^[a-z][a-z0-9+.-]*:(\/\/)?\S/i.test(value) && !/^[^:]+:\d+(\/|$)/.test(value))
        return value
    // localhost, IPs y dominios con punto (opcionalmente con puerto y ruta)
    if (/^(localhost|\d{1,3}(\.\d{1,3}){3}|[^\s\/.]+(\.[^\s\/.]+)+)(:\d+)?(\/.*)?$/i.test(value))
        return "https://" + value
    return searchUrl(value, template)
}

// Dominio de una URL, sin "www.": "https://www.github.com/x" → "github.com"
function host(address) {
    var match = /^[a-z][a-z0-9+.-]*:\/\/([^\/:?#]+)/i.exec(address)
    return match ? match[1].replace(/^www\./i, "") : ""
}

// Favicon de un sitio desde el servicio de iconos de DuckDuckGo (sin
// rastreo; la caché en disco evita pedirlo en cada arranque). "" si no hay dominio.
function favicon(address) {
    var domain = host(address)
    return domain !== "" ? "https://icons.duckduckgo.com/ip3/" + domain + ".ico" : ""
}

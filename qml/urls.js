.pragma library

// Buscador por defecto
var searchUrl = "https://duckduckgo.com/?q="

// Convierte lo que escribe el usuario en una URL navegable: si no parece
// una dirección, la busca. Devuelve "" si no hay nada que abrir.
function resolve(input) {
    var value = input.trim()
    if (value === "")
        return ""
    if (/\s/.test(value))
        return searchUrl + encodeURIComponent(value)
    // Ya trae esquema: https://, file://, about:, etc.
    if (/^[a-z][a-z0-9+.-]*:(\/\/)?\S/i.test(value) && !/^[^:]+:\d+(\/|$)/.test(value))
        return value
    // localhost, IPs y dominios con punto (opcionalmente con puerto y ruta)
    if (/^(localhost|\d{1,3}(\.\d{1,3}){3}|[^\s\/.]+(\.[^\s\/.]+)+)(:\d+)?(\/.*)?$/i.test(value))
        return "https://" + value
    return searchUrl + encodeURIComponent(value)
}

// Dominio de una URL, sin "www.": "https://www.github.com/x" → "github.com"
function host(address) {
    var match = /^[a-z][a-z0-9+.-]*:\/\/([^\/:?#]+)/i.exec(address)
    return match ? match[1].replace(/^www\./i, "") : ""
}

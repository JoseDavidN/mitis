// Precarga de páginas (Configuración → Rendimiento, «Precargar páginas»;
// BrowserProfile solo lo inyecta con la opción y nunca en ventanas privadas).
// Como instant.page: si el ratón se queda un momento sobre un enlace, se
// adelanta lo que hará falta al pulsarlo. Del mismo sitio, la página entera,
// con una regla de precarga (<script type=speculationrules>): el motor la
// guarda aparte y se la da a la navegación aunque la página pida comprobarse
// siempre (no-cache, como GitHub o Wikipedia). <link rel=prefetch> no sirve:
// va a la caché normal y con no-cache se vuelve a descargar entera (medido,
// docs/rendimiento.md). De otro sitio, solo la conexión (<link
// rel=preconnect>), para no avisarle de por dónde pasa el ratón. Al pulsar
// (o tocar) se adelanta sin esperar. Corre en el mundo de Mitis
// (ApplicationWorld): la página no lo ve.
(function () {
    "use strict";
    if (window.__mitisPreload)
        return;
    window.__mitisPreload = true;

    // Tiempo con el ratón encima antes de precargar: menos y se precarga
    // todo lo que se cruza; más y no da tiempo a ganar nada
    const HoverDelay = 65;
    // Precargas por página como mucho
    const MaxPerPage = 20;

    const done = new Set();
    let count = 0;
    let timer = 0;
    let hovered = null;

    function linkOf(node) {
        const element = node && node.nodeType === Node.ELEMENT_NODE ? node : node && node.parentElement;
        return element && element.closest ? element.closest("a[href]") : null;
    }

    function urlOf(link) {
        if (navigator.connection && navigator.connection.saveData)
            return null;
        if (link.hasAttribute("download") || link.hasAttribute("data-no-instant"))
            return null;
        let url;
        try {
            url = new URL(link.href, location.href);
        } catch (e) {
            return null;
        }
        if (url.protocol !== "https:" && url.protocol !== "http:")
            return null;
        // Un ancla de la misma página no carga nada
        if (url.origin === location.origin && url.pathname === location.pathname && url.search === location.search)
            return null;
        // De una página segura no se baja a una que no lo es
        if (location.protocol === "https:" && url.protocol === "http:")
            return null;
        return url;
    }

    function preload(url) {
        const sameSite = url.origin === location.origin;
        const key = sameSite ? url.href.split("#")[0] : url.origin;
        if (done.has(key) || count >= MaxPerPage)
            return;
        done.add(key);
        count++;
        let hint;
        if (sameSite) {
            hint = document.createElement("script");
            hint.type = "speculationrules";
            hint.textContent = JSON.stringify({ prefetch: [{ source: "list", urls: [key] }] });
        } else {
            hint = document.createElement("link");
            hint.rel = "preconnect";
            hint.href = key;
        }
        (document.head || document.documentElement).appendChild(hint);
    }

    document.addEventListener("mouseover", event => {
        const link = linkOf(event.target);
        if (!link || link === hovered)
            return;
        hovered = link;
        clearTimeout(timer);
        const url = urlOf(link);
        if (url)
            timer = setTimeout(() => preload(url), HoverDelay);
    }, { capture: true, passive: true });

    document.addEventListener("mouseout", event => {
        if (hovered && !hovered.contains(event.relatedTarget)) {
            hovered = null;
            clearTimeout(timer);
        }
    }, { capture: true, passive: true });

    // Al pulsar o tocar: ya, sin esperar (la navegación empieza al soltar)
    function now(event) {
        const link = linkOf(event.target);
        const url = link && urlOf(link);
        if (url)
            preload(url);
    }
    document.addEventListener("mousedown", event => { if (event.button === 0) now(event) }, { capture: true, passive: true });
    document.addEventListener("touchstart", now, { capture: true, passive: true });
})();

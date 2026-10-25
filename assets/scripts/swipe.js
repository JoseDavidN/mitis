// Deslizar entre páginas (macOS): dice si el gesto horizontal en curso es de
// la página. Lo pregunta BrowserTab.swipeAllowed() antes de mostrar la
// flecha de atrás/adelante. Es de la página si algo bajo el puntero podía
// desplazarse hacia ese lado al empezar (carrusel, tabla, la propia página)
// o si la página se quedó con el evento (mapas, editores: preventDefault).
// Corre en el mundo de Mitis (ApplicationWorld): la página no lo ve ni lo
// cambia. El oyente es pasivo: no retrasa el desplazamiento.
(function () {
    "use strict";
    if (window.__mitisSwipe)
        return;

    // Sin eventos durante este tiempo, el siguiente es otro gesto
    const GestureGap = 250;
    let last = -Infinity;
    let claimed = false;

    function hidden(element) {
        const overflow = getComputedStyle(element).overflowX;
        return overflow === "hidden" || overflow === "clip";
    }

    function scrollsTowards(element, direction) {
        for (let node = element; node; node = node.parentNode || node.host) {
            if (node.nodeType !== Node.ELEMENT_NODE)
                continue;
            if (node === document.scrollingElement) {
                // La página entera se desplaza salvo que lo impida
                if (hidden(document.documentElement) || (document.body && hidden(document.body)))
                    continue;
            } else {
                const overflow = getComputedStyle(node).overflowX;
                if (overflow !== "auto" && overflow !== "scroll")
                    continue;
            }
            if (node.scrollWidth <= node.clientWidth)
                continue;
            if (direction < 0 && node.scrollLeft > 0)
                return true;
            if (direction > 0 && node.scrollLeft + node.clientWidth < node.scrollWidth - 1)
                return true;
        }
        return false;
    }

    window.addEventListener("wheel", event => {
        const now = performance.now();
        if (now - last > GestureGap)
            claimed = false;
        last = now;
        if (claimed)
            return;
        // Los manejadores de la página ya se ejecutaron (fase de burbuja en
        // window), y el desplazamiento aún no
        if (event.defaultPrevented)
            claimed = true;
        else if (Math.abs(event.deltaX) > Math.abs(event.deltaY))
            // composedPath: lo de dentro de los componentes (shadow DOM)
            claimed = scrollsTowards(event.composedPath()[0], Math.sign(event.deltaX));
    }, { passive: true });

    // recent: la página está recibiendo el gesto (si no, va a un marco de
    // otra página y no se sabe qué hace con él)
    window.__mitisSwipe = () => ({ recent: performance.now() - last < GestureGap * 2, claimed });
})();

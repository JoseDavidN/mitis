// Se inyecta solo en el panel de herramientas de desarrollo (F12), no en las
// páginas. Lo pone en oscuro y define window.__mitisDevToolsTheme(colores),
// que BrowserTab llama con los tokens Theme.devtools* para teñirlo de negro,
// con el acento de Mitis y letra gruesa.
(() => {
    const bundled = "devtools://devtools/bundled/";

    // El panel de Chromium solo aplica su tema tras cargar
    // devtools://theme/colors.css, que Qt WebEngine no trae: sin esto se queda
    // claro aunque se elija «dark». Sin los colores de Chrome lo aplica al momento.
    Promise.all([
        import(bundled + "core/common/common.js"),
        import(bundled + "ui/legacy/theme_support/theme_support.js")
    ]).then(([common, theme]) => {
        const settings = common.Settings.Settings.instance()
        settings.moduleSetting("chrome-theme-colors").set(false)
        settings.moduleSetting("ui-theme").set("dark")
        // El tema se crea al arrancar el panel, algo después de este script
        let tries = 0
        const timer = setInterval(() => {
            if (theme.ThemeSupport.hasInstance())
                theme.ThemeSupport.instance().fetchColorsAndApplyHostTheme()
            else if (++tries < 50)
                return
            clearInterval(timer)
        }, 100)
    }).catch(error => console.warn("Mitis: no se pudo poner el panel en oscuro: " + error))

    window.__mitisDevToolsTheme = c => {
        let style = document.getElementById("mitis-devtools")
        if (!style) {
            style = document.createElement("style")
            style.id = "mitis-devtools"
            document.head.appendChild(style)
        }
        const tonal = `color-mix(in srgb, ${c.accent} 28%, ${c.bg})`
        // Variables del sistema de colores del panel: las heredan también los
        // componentes con shadow DOM. !important porque el panel las define con
        // selectores más específicos (p. ej. .baseline-grayscale)
        style.textContent = `
            :root.theme-with-dark-background {
                --sys-color-cdt-base-container: ${c.bg} !important;
                --sys-color-base-container: ${c.bg} !important;
                --sys-color-surface: ${c.bg} !important;
                --sys-color-cdt-base: ${c.surface} !important;
                --sys-color-base: ${c.surface} !important;
                --sys-color-base-container-elevated: ${c.surface} !important;
                --sys-color-header-container: ${c.surface} !important;
                --sys-color-surface1: ${c.surface} !important;
                --sys-color-surface2: ${c.surface} !important;
                --sys-color-surface3: ${c.surface} !important;
                --sys-color-surface4: ${c.surfaceHover} !important;
                --sys-color-surface5: ${c.surfaceHover} !important;
                --sys-color-surface-variant: ${c.surfaceHover} !important;
                --sys-color-divider: ${c.line} !important;
                --sys-color-divider-prominent: ${c.line} !important;
                --sys-color-divider-on-tonal-container: ${c.line} !important;
                --sys-color-neutral-outline: ${c.line} !important;
                --sys-color-on-surface: ${c.ink} !important;
                --sys-color-on-surface-subtle: ${c.inkSoft} !important;
                --sys-color-on-surface-secondary: ${c.inkSoft} !important;
                --sys-color-token-subtle: ${c.inkSoft} !important;
                --sys-color-primary: ${c.accent} !important;
                --sys-color-primary-bright: ${c.accent} !important;
                --sys-color-blue-bright: ${c.accent} !important;
                --sys-color-on-surface-primary: ${c.accent} !important;
                --sys-color-tonal-outline: ${c.accent} !important;
                --sys-color-tonal-container: ${tonal} !important;
                --sys-color-state-header-hover: ${tonal} !important;
                --sys-color-state-focus-ring: ${c.accent} !important;
                --sys-color-state-focus-select: ${tonal} !important;
                --sys-color-state-text-highlight: ${c.accent} !important;
                --sys-color-state-on-text-highlight: ${c.onAccent} !important;
            }
            :root, body {
                font-weight: 600;
            }
        `
    }
})()

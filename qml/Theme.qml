pragma Singleton
import QtQuick
import Mitis.Core

// Tema de Mitis: colores, medidas y duraciones. Ningún componente escribe
// colores, medidas ni duraciones a mano: todo sale de aquí.
// Reglas y uso de cada token: DESIGN.md.
//
// Tres temas, que se eligen en Configuración → Apariencia y cambian al
// momento (cada color es un enlace a la paleta elegida):
//  · Nocturno (el de serie): violeta/rosa sobre negro profundo, tomado del
//    tema oscuro de StartCode Panel.
//  · Oscuro: grises neutros y acento azul, como el modo oscuro de Chrome.
//  · Claro: fondos claros con el violeta y el rosa de la marca.
// Medidas, tipografía, movimiento y la paleta de DevTools son iguales en todos.
QtObject {
    id: theme

    // Temas que se pueden elegir, en el orden de Configuración
    readonly property var themes: [
        { key: "nocturno", name: "Nocturno" },
        { key: "oscuro", name: "Oscuro" },
        { key: "claro", name: "Claro" }
    ]
    readonly property var palettes: ({
        nocturno: {
            dark: true,
            bgBase: "#07050d", bgMid: "#150a2e", bgGlow: "#2a1352",
            // Barra de título, controles, botones sueltos y listas: los tonos del
            // fondo de Configuración (bgGlow → bgMid), para que todo coincida
            titleBarStart: "#2a1352", titleBarEnd: "#150a2e",
            controlsStart: Qt.rgba(0x2a / 255, 0x13 / 255, 0x52 / 255, 0.94),
            controlsEnd: Qt.rgba(0x15 / 255, 0x0a / 255, 0x2e / 255, 0.94),
            surfaceFloat: Qt.rgba(8 / 255, 3 / 255, 20 / 255, 0.88),
            selectBg: "#2a1352",
            backgroundScrim: Qt.rgba(7 / 255, 5 / 255, 13 / 255, 0.55),
            faviconBackdrop: Qt.rgba(1, 1, 1, 0.92),
            surfacePopup: "#150a2e",
            hairline: Qt.rgba(1, 1, 1, 0.13), hairlineSoft: Qt.rgba(1, 1, 1, 0.12),
            hairlineStrong: Qt.rgba(1, 1, 1, 0.20), hairlineHover: Qt.rgba(1, 1, 1, 0.18),
            line: Qt.rgba(1, 1, 1, 0.07),
            tintHover: Qt.rgba(1, 1, 1, 0.06), tintActive: Qt.rgba(1, 1, 1, 0.10), tintSunken: Qt.rgba(1, 1, 1, 0.04),
            ink: "#f4f1ff", inkStrong: Qt.rgba(1, 1, 1, 0.85), inkSoft: Qt.rgba(1, 1, 1, 0.75),
            inkSecondary: Qt.rgba(1, 1, 1, 0.65), inkMuted: Qt.rgba(1, 1, 1, 0.45),
            inkFaint: Qt.rgba(1, 1, 1, 0.35), inkDisabled: Qt.rgba(1, 1, 1, 0.30),
            brand1: "#a855f7", brand2: "#ec4899", brandLight1: "#c084fc", brandLight2: "#f472b6",
            onBrand: "#ffffff", focusRing: "#c084fc",
            selection: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.35),
            ok: "#34d399", warn: "#fbbf24", danger: "#fb7185", dangerStrong: "#f43f5e"
        },
        // Los grises y el azul del modo oscuro de Chrome
        oscuro: {
            dark: true,
            bgBase: "#202124", bgMid: "#202124", bgGlow: "#2d2e31",
            titleBarStart: "#2d2e31", titleBarEnd: "#202124",
            controlsStart: Qt.rgba(0x2d / 255, 0x2e / 255, 0x31 / 255, 0.94),
            controlsEnd: Qt.rgba(0x20 / 255, 0x21 / 255, 0x24 / 255, 0.94),
            surfaceFloat: Qt.rgba(0x29 / 255, 0x2a / 255, 0x2d / 255, 0.94),
            selectBg: "#35363a",
            backgroundScrim: Qt.rgba(0x20 / 255, 0x21 / 255, 0x24 / 255, 0.55),
            faviconBackdrop: Qt.rgba(1, 1, 1, 0.92),
            surfacePopup: "#292a2d",
            hairline: Qt.rgba(1, 1, 1, 0.12), hairlineSoft: Qt.rgba(1, 1, 1, 0.08),
            hairlineStrong: Qt.rgba(1, 1, 1, 0.18), hairlineHover: Qt.rgba(1, 1, 1, 0.20),
            line: Qt.rgba(1, 1, 1, 0.08),
            tintHover: Qt.rgba(1, 1, 1, 0.06), tintActive: Qt.rgba(1, 1, 1, 0.10), tintSunken: Qt.rgba(1, 1, 1, 0.04),
            ink: "#e8eaed", inkStrong: Qt.rgba(0xe8 / 255, 0xea / 255, 0xed / 255, 0.92),
            inkSoft: Qt.rgba(0xe8 / 255, 0xea / 255, 0xed / 255, 0.80),
            inkSecondary: "#bdc1c6", inkMuted: "#9aa0a6",
            inkFaint: Qt.rgba(1, 1, 1, 0.38), inkDisabled: Qt.rgba(1, 1, 1, 0.30),
            brand1: "#1a73e8", brand2: "#1a73e8", brandLight1: "#8ab4f8", brandLight2: "#8ab4f8",
            onBrand: "#ffffff", focusRing: "#8ab4f8",
            selection: Qt.rgba(0x8a / 255, 0xb4 / 255, 0xf8 / 255, 0.35),
            ok: "#81c995", warn: "#fdd663", danger: "#f28b82", dangerStrong: "#d93025"
        },
        claro: {
            dark: false,
            bgBase: "#f7f5fb", bgMid: "#f1ebfd", bgGlow: "#e4d7fc",
            titleBarStart: "#e4d7fc", titleBarEnd: "#f1ebfd",
            controlsStart: Qt.rgba(0xe4 / 255, 0xd7 / 255, 0xfc / 255, 0.94),
            controlsEnd: Qt.rgba(0xf1 / 255, 0xeb / 255, 0xfd / 255, 0.94),
            surfaceFloat: Qt.rgba(1, 1, 1, 0.94),
            selectBg: "#e4d7fc",
            backgroundScrim: Qt.rgba(0xf7 / 255, 0xf5 / 255, 0xfb / 255, 0.6),
            // Gris muy claro: los favicons blancos no desaparecen
            faviconBackdrop: "#ece9f2",
            surfacePopup: "#f1ebfd",
            hairline: Qt.rgba(0, 0, 0, 0.12), hairlineSoft: Qt.rgba(0, 0, 0, 0.08),
            hairlineStrong: Qt.rgba(0, 0, 0, 0.16), hairlineHover: Qt.rgba(0, 0, 0, 0.22),
            line: Qt.rgba(0, 0, 0, 0.07),
            tintHover: Qt.rgba(0, 0, 0, 0.05), tintActive: Qt.rgba(0, 0, 0, 0.08), tintSunken: Qt.rgba(0, 0, 0, 0.04),
            ink: "#1d1631", inkStrong: Qt.rgba(0x1d / 255, 0x16 / 255, 0x31 / 255, 0.88),
            inkSoft: Qt.rgba(0x1d / 255, 0x16 / 255, 0x31 / 255, 0.75),
            inkSecondary: Qt.rgba(0x1d / 255, 0x16 / 255, 0x31 / 255, 0.68),
            inkMuted: Qt.rgba(0x1d / 255, 0x16 / 255, 0x31 / 255, 0.54),
            inkFaint: Qt.rgba(0x1d / 255, 0x16 / 255, 0x31 / 255, 0.42),
            inkDisabled: Qt.rgba(0x1d / 255, 0x16 / 255, 0x31 / 255, 0.30),
            brand1: "#9333ea", brand2: "#db2777", brandLight1: "#7c3aed", brandLight2: "#be185d",
            onBrand: "#ffffff", focusRing: "#7c3aed",
            selection: Qt.rgba(147 / 255, 51 / 255, 234 / 255, 0.22),
            ok: "#059669", warn: "#b45309", danger: "#e11d48", dangerStrong: "#e11d48"
        },
        // Ventanas privadas (no se elige: es la suya siempre, Colors): negro
        // mate, sin el morado de la marca ni brillos; los acentos, en gris
        // claro y los botones principales, gris oscuro
        privado: {
            dark: true,
            bgBase: "#0a0a0a", bgMid: "#0c0c0c", bgGlow: "#121212",
            titleBarStart: "#121212", titleBarEnd: "#0c0c0c",
            controlsStart: Qt.rgba(0x16 / 255, 0x16 / 255, 0x16 / 255, 0.96),
            controlsEnd: Qt.rgba(0x10 / 255, 0x10 / 255, 0x10 / 255, 0.96),
            surfaceFloat: Qt.rgba(0x0e / 255, 0x0e / 255, 0x0e / 255, 0.94),
            selectBg: "#1c1c1c",
            backgroundScrim: Qt.rgba(0x0a / 255, 0x0a / 255, 0x0a / 255, 0.6),
            faviconBackdrop: Qt.rgba(1, 1, 1, 0.92),
            surfacePopup: "#121212",
            hairline: Qt.rgba(1, 1, 1, 0.10), hairlineSoft: Qt.rgba(1, 1, 1, 0.07),
            hairlineStrong: Qt.rgba(1, 1, 1, 0.16), hairlineHover: Qt.rgba(1, 1, 1, 0.18),
            line: Qt.rgba(1, 1, 1, 0.06),
            tintHover: Qt.rgba(1, 1, 1, 0.05), tintActive: Qt.rgba(1, 1, 1, 0.09), tintSunken: Qt.rgba(1, 1, 1, 0.03),
            ink: "#ececec", inkStrong: Qt.rgba(1, 1, 1, 0.86), inkSoft: Qt.rgba(1, 1, 1, 0.74),
            inkSecondary: Qt.rgba(1, 1, 1, 0.62), inkMuted: Qt.rgba(1, 1, 1, 0.44),
            inkFaint: Qt.rgba(1, 1, 1, 0.32), inkDisabled: Qt.rgba(1, 1, 1, 0.26),
            brand1: "#3a3a3a", brand2: "#2b2b2b", brandLight1: "#d4d4d4", brandLight2: "#a3a3a3",
            onBrand: "#ffffff", focusRing: "#8a8a8a",
            selection: Qt.rgba(1, 1, 1, 0.20),
            ok: "#4ade80", warn: "#fbbf24", danger: "#f87171", dangerStrong: "#ef4444"
        }
    })

    // Tema en uso (uno de `themes`; si el guardado no existe, Nocturno)
    readonly property string current: themes.some(item => item.key === Settings.theme) ? Settings.theme : "nocturno"
    readonly property string name: themes.find(item => item.key === current).name
    readonly property var palette: palettes[current]
    // Tema oscuro (Nocturno, Oscuro) o claro. Lo siguen los diálogos del
    // sistema y, desde el próximo arranque, las páginas que tienen versión
    // oscura (prefers-color-scheme: lo fija main.cpp al iniciar el motor)
    readonly property bool dark: palette.dark
    onDarkChanged: Application.styleHints.colorScheme = dark ? Qt.ColorScheme.Dark : Qt.ColorScheme.Light
    Component.onCompleted: {
        Application.styleHints.colorScheme = dark ? Qt.ColorScheme.Dark : Qt.ColorScheme.Light
        Colors.setPalettes(palette, palettes.privado)
    }
    // Los colores los leen los componentes con `Colors` (src/themecolors.*),
    // que da los de la ventana: los de este tema o, en las privadas, los de
    // «privado». Las propiedades de color de aquí abajo son las del tema
    // elegido, para lo que no depende de la ventana
    onPaletteChanged: Colors.setPalettes(palette, palettes.privado)

    // ── Fondo ────────────────────────────────────────────────────────
    readonly property color bgBase: palette.bgBase
    readonly property color bgMid: palette.bgMid
    readonly property color bgGlow: palette.bgGlow
    // Barra de título: versión oscura (o clara) del degradado de marca
    readonly property color titleBarStart: palette.titleBarStart
    readonly property color titleBarEnd: palette.titleBarEnd
    // Controles inferiores: el mismo degradado, con un poco de transparencia,
    // repartido entre todos los controles de lado a lado
    readonly property color controlsStart: palette.controlsStart
    readonly property color controlsEnd: palette.controlsEnd

    // ── Superficies ──────────────────────────────────────────────────
    // Flotan sobre la página: casi opacas para separarse de cualquier web
    // (equivale a glass-float, sin blur para no gastar GPU ni RAM)
    readonly property color surfaceFloat: palette.surfaceFloat
    readonly property color selectBg: palette.selectBg
    // Velo sobre una imagen de fondo propia: mantiene legible el texto
    readonly property color backgroundScrim: palette.backgroundScrim
    // Círculo tras los favicons: muchos son negros (o blancos) y no se verían
    readonly property color faviconBackdrop: palette.faviconBackdrop
    // Listas desplegables: opacas, porque sin blur el texto de la página de
    // detrás se mezclaría con el de la lista
    readonly property color surfacePopup: palette.surfacePopup

    // ── Bordes y separadores ─────────────────────────────────────────
    readonly property color hairline: palette.hairline
    readonly property color hairlineSoft: palette.hairlineSoft
    readonly property color hairlineStrong: palette.hairlineStrong
    readonly property color hairlineHover: palette.hairlineHover
    readonly property color line: palette.line

    // ── Tintes de realce ─────────────────────────────────────────────
    readonly property color tintHover: palette.tintHover
    readonly property color tintActive: palette.tintActive
    readonly property color tintSunken: palette.tintSunken

    // ── Tinta (texto e iconos) ───────────────────────────────────────
    readonly property color ink: palette.ink
    readonly property color inkStrong: palette.inkStrong
    readonly property color inkSoft: palette.inkSoft
    readonly property color inkSecondary: palette.inkSecondary
    readonly property color inkMuted: palette.inkMuted
    readonly property color inkFaint: palette.inkFaint
    readonly property color inkDisabled: palette.inkDisabled

    // ── Marca ────────────────────────────────────────────────────────
    readonly property color brand1: palette.brand1
    readonly property color brand2: palette.brand2
    readonly property color brandLight1: palette.brandLight1
    readonly property color brandLight2: palette.brandLight2
    readonly property color onBrand: palette.onBrand
    readonly property color focusRing: palette.focusRing
    readonly property color selection: palette.selection

    // ── Semánticos ───────────────────────────────────────────────────
    readonly property color ok: palette.ok
    readonly property color warn: palette.warn
    readonly property color danger: palette.danger
    readonly property color dangerStrong: palette.dangerStrong

    // ── Medidas ──────────────────────────────────────────────────────
    readonly property int titleBarHeight: 30
    // Ventana la primera vez (sin tamaño guardado): esta parte de la pantalla
    readonly property real windowDefaultRatio: 0.75
    readonly property int bottomBarMaxWidth: 1100
    readonly property int floatingMargin: 10
    readonly property int buttonSize: 32
    readonly property int titleButtonSize: 24
    // Botones de ventana de macOS (los «semáforos» del sistema): círculos de
    // colores fijos de Apple, a la izquierda. Con la ventana inactiva, grises
    readonly property int macDotSize: 12
    readonly property int macDotSpacing: 8
    readonly property color macClose: "#ff5f57"
    readonly property color macMinimize: "#febc2e"
    readonly property color macZoom: "#28c840"
    readonly property color macDotBorder: Qt.rgba(0, 0, 0, 0.12)
    readonly property color macDotSymbol: Qt.rgba(0, 0, 0, 0.55)
    // Sin foco: claro u oscuro según la ventana (Colors.dark; la privada es oscura)
    readonly property color macDotInactiveDark: Qt.rgba(1, 1, 1, 0.18)
    readonly property color macDotInactiveLight: Qt.rgba(0, 0, 0, 0.14)
    readonly property int buttonSizeSmall: 24
    readonly property int controlHeight: 34
    readonly property int logoSize: 18
    // Nombre de Mitis (logo sin icono) en la barra de título: alto
    readonly property int titleBarLogoHeight: 17
    readonly property int iconSize: 16
    readonly property int iconSizeSmall: 14
    readonly property int faviconSize: 16
    readonly property int spacing: 8
    readonly property int margin: 12
    readonly property int radius: 12
    readonly property int radiusSmall: 8
    readonly property int progressHeight: 2
    readonly property int markerWidth: 3
    readonly property int resizeGrip: 6
    readonly property int popupWidth: 360
    readonly property int popupMaxHeight: 480
    readonly property int popupRowHeight: 36
    // Vidrio esmerilado (Glass), experimental: lo enciende la opción de
    // Configuración → Apariencia, apagada por defecto. En el servidor de
    // desarrollo (Chromium sin GPU) Qt no puede copiar el contenido de la
    // página y la copia sale vacía; falta confirmarlo con una GPU real
    readonly property bool glassEnabled: Settings.glassEffect
    // Desenfoque máximo de MultiEffect (px) y algo más de color en lo
    // difuminado (como Apple)
    readonly property int glassBlur: 48
    readonly property real glassSaturation: 0.3
    // Manchas de color de la marca en el fondo de las páginas propias
    // (GlassAurora), para que el vidrio tenga algo que difuminar
    readonly property real glassAuroraOpacity: dark ? 0.32 : 0.22
    // Velo encima de lo difuminado: un morado de la marca, en tres tonos a
    // elegir en Configuración (Settings.glassTone: lavanda, violeta,
    // profundo). En los temas oscuros, sobre oscuro; en el Claro, tonos
    // claros. Un control de texto blanco puede usar siempre los oscuros
    readonly property var glassTintsDark: [
        Qt.rgba(0xc0 / 255, 0x84 / 255, 0xfc / 255, 0.18),   // lavanda (brandLight1)
        Qt.rgba(0x7c / 255, 0x3a / 255, 0xed / 255, 0.30),   // violeta
        Qt.rgba(0x2a / 255, 0x13 / 255, 0x52 / 255, 0.55)    // profundo (bgGlow de Nocturno)
    ]
    readonly property var glassTintsLight: [
        Qt.rgba(0xf3 / 255, 0xe8 / 255, 0xff / 255, 0.55),
        Qt.rgba(0xe4 / 255, 0xd7 / 255, 0xfc / 255, 0.50),
        Qt.rgba(0xc4 / 255, 0xb5 / 255, 0xfd / 255, 0.45)
    ]
    readonly property var glassTones: [
        { value: 0, label: "Lavanda" }, { value: 1, label: "Violeta" }, { value: 2, label: "Profundo" }
    ]
    readonly property color glassTintDark: glassTintsDark[Settings.glassTone] ?? glassTintsDark[1]
    readonly property color glassTint: dark ? glassTintDark : (glassTintsLight[Settings.glassTone] ?? glassTintsLight[1])
    // Captura de pantalla (ScreenshotOverlay): velo sobre lo que no entra,
    // relleno de la sección bajo el ratón, tiradores de la selección, franja
    // del borde que desplaza la página al estirar, paso de ese desplazamiento
    // (px CSS cada `screenshotScrollInterval` ms), espera a que la página se
    // pinte tras desplazarla, alto máximo (px CSS: una imagen mayor sería
    // enorme) y cuánto se ve el aviso al terminar
    readonly property color screenshotDim: Qt.rgba(0, 0, 0, 0.45)
    readonly property color screenshotHoverFill: Qt.rgba(1, 1, 1, 0.06)
    readonly property int screenshotBorder: 2
    readonly property int screenshotHandle: 10
    readonly property int screenshotMinSize: 16
    readonly property int screenshotEdgeZone: 36
    readonly property int screenshotScrollStep: 40
    readonly property int screenshotScrollInterval: 30
    readonly property int screenshotSliceDelay: 220
    readonly property int screenshotMaxHeight: 16000
    readonly property int screenshotNoticeHold: 1400
    // Panel del sitio: cuánto dura «Enlace copiado» (ms)
    readonly property int siteInfoCopiedHold: 1500
    readonly property int optionsWidth: 270
    // Botón de actualización (barra inferior): anillo con el degradado de la
    // marca, su pulso (cada tanto, un anillo que crece y se desvanece) y la
    // ventana de confirmación
    readonly property int updateRingWidth: 2
    readonly property real updatePulseScale: 1.45
    readonly property int updatePulseDuration: 1400
    readonly property int updatePulsePause: 1200
    readonly property int updatePopupWidth: 300
    readonly property int textButtonHeight: 32
    readonly property int dialogWidth: 360
    // Aviso de certificado: más texto que un diálogo normal
    readonly property int certificateDialogWidth: 440
    // Página de nueva pestaña
    readonly property int ntpMaxWidth: 720
    readonly property int ntpSearchWidth: 600
    // Logo completo de Mitis sobre el buscador: ancho y espacio hasta él
    readonly property int ntpLogoWidth: 220
    readonly property int ntpLogoSpacing: 28
    readonly property int ntpSearchHeight: 48
    readonly property int ntpSectionSpacing: 40
    readonly property int ntpNewsTwoColumnsWidth: 560
    // Pestaña de novedades tras actualizar: columna, punto de cada cambio y
    // espacio entre grupos
    readonly property int releaseNotesMaxWidth: 640
    readonly property int releaseNotesDotSize: 6
    readonly property int releaseNotesGroupSpacing: 28
    readonly property int tileSize: 56
    readonly property int tileWidth: 84
    readonly property int tileIconSize: 22
    readonly property int tileIconBackdrop: 34
    readonly property int quickLinksMax: 10
    // Página de Configuración: índice a la izquierda y columna de secciones
    readonly property int settingsMaxWidth: 680
    readonly property int settingsNavWidth: 220
    // Por debajo de este ancho de ventana el índice se oculta
    readonly property int settingsNavBreakpoint: 900
    // El índice ocupa como mucho esta parte del alto disponible (se desplaza)
    readonly property real settingsNavHeightRatio: 0.4
    // Logo completo de Mitis al pie del índice y «by StartCode» al final de
    // los ajustes (cada uno en su versión para temas oscuros o para el Claro)
    readonly property int settingsMitisLogoWidth: 180
    readonly property int settingsLogoWidth: 80
    // Fundido de los bordes del índice y de la columna de ajustes: alto de la
    // franja y escalones en que se reparte (sin shaders: funciona sin GPU)
    readonly property int settingsFadeHeight: 40
    readonly property int settingsFadeSteps: 10
    // Fundido de la columna de ajustes: más alto, como si salieran del fondo
    readonly property int settingsContentFadeHeight: 96
    readonly property int settingsContentFadeSteps: 16
    readonly property int settingsHeaderHeight: 64
    readonly property int settingsSectionSpacing: 32
    readonly property int settingsRowHeight: 60
    readonly property int settingsIconBox: 36
    // Círculo con el icono de la cabecera de Configuración y su icono
    readonly property int settingsHeaderIconBox: 30
    readonly property int settingsHeaderIconSize: 15
    // Avatar del perfil: colores para la inicial (iguales en todos los temas,
    // con texto onBrand encima) y tamaño grande (Configuración → Perfil)
    readonly property var avatarColors: [
        { key: "violeta", label: "Violeta", color: "#a855f7" },
        { key: "rosa", label: "Rosa", color: "#ec4899" },
        { key: "azul", label: "Azul", color: "#3b82f6" },
        { key: "verde", label: "Verde", color: "#10b981" },
        { key: "naranja", label: "Naranja", color: "#f97316" },
        { key: "gris", label: "Gris", color: "#64748b" }
    ]
    readonly property int avatarSizeLarge: 64
    // Tarjeta de un tema en Configuración: ancho y alto de su vista previa
    readonly property int themeTileWidth: 150
    readonly property int themeTilePreviewHeight: 84
    // Interruptor (Toggle): pista y separación de la bola
    readonly property int toggleWidth: 38
    readonly property int toggleHeight: 22
    readonly property int toggleKnobInset: 3
    // Botón de opción (círculo de elección única)
    readonly property int radioSize: 18
    readonly property int radioDotSize: 8
    // Casilla de verificación (CheckMark): mismo tamaño que el botón de opción
    readonly property int checkRadius: 5
    readonly property int findBarWidth: 440
    readonly property int zoomLabelWidth: 52
    // Relieve de deslizar entre páginas (SwipeIndicator): cuánto sale del
    // borde como mucho, su largo (largo y poco hondo: se ve redondo), la
    // tensión de su curva (fracción del largo con la que sale del borde y
    // llega a la cima, ambas en vertical) y el tamaño de su flecha
    readonly property int swipeBumpDepth: 44
    readonly property int swipeBumpLength: 220
    readonly property real swipeBumpCurve: 0.24
    readonly property int swipeArrowSize: 22
    // Ventana de imprimir (PrintDialog): tamaño máximo, columna de opciones,
    // alto de sus filas y copias como mucho. La hoja de la vista previa es
    // blanca en todos los temas, como el papel
    readonly property int printDialogWidth: 820
    readonly property int printDialogHeight: 600
    readonly property int printOptionsWidth: 300
    readonly property int printRowHeight: 32
    readonly property int printMaxCopies: 99
    readonly property color printPaper: "#ffffff"
    // Reproductor: pestaña del borde derecho (MediaTab: cuánto sale, y al
    // pasar el ratón; su largo, alargada en vertical; la tensión de su
    // curva, como swipeBumpCurve; y el rebote al aparecer) y reproductor
    // desplegado (MediaPlayerPopup, compacto): ancho, miniatura de la
    // carátula y botones (el de reproducir, más grande)
    readonly property int mediaTabDepth: 26
    readonly property int mediaTabHoverDepth: 32
    readonly property int mediaTabLength: 128
    readonly property real mediaTabCurve: 0.26
    readonly property real mediaTabOvershoot: 1.6
    readonly property int mediaPlayerWidth: 272
    readonly property int mediaThumbSize: 44
    readonly property int mediaButtonSize: 30
    readonly property int mediaPlayButtonSize: 36
    readonly property int mediaIconSize: 16
    readonly property int mediaPlayIconSize: 18
    // Panel de descargas, barra de progreso y anillo del botón
    readonly property int downloadPanelWidth: 340
    // Con muchas descargas a la vez, el panel se desplaza a partir de esta altura
    readonly property int downloadPanelMaxHeight: 320
    // Panel de memoria (desarrollo): ancho y cada cuánto vuelve a medir (ms)
    readonly property int memoryPanelWidth: 360
    readonly property int memoryPanelRefresh: 2000
    // Gráficas del monitor: alto, muestras que guardan (60 × 2 s = 2 min),
    // trazo, opacidad del relleno bajo la línea y color de cada serie
    readonly property int performanceChartHeight: 36
    readonly property int performanceHistoryLength: 60
    readonly property real performanceChartLineWidth: 1.5
    readonly property real performanceChartFillOpacity: 0.16
    readonly property color performanceCpu: brandLight1
    readonly property color performanceMemory: ok
    readonly property int downloadBarHeight: 4
    readonly property int progressRingWidth: 2
    // Sin total conocido: tramo que recorre la barra y arco que gira (fracción)
    readonly property real progressIndeterminateSpan: 0.3
    readonly property int tooltipPaddingX: 10
    readonly property int tooltipPaddingY: 5
    // Reordenar pestañas arrastrando: línea de destino y paso del auto-scroll
    readonly property int dropIndicatorHeight: 2
    readonly property int dragScrollStep: 6
    // Listado de descargas: fila de dos líneas (nombre y estado)
    readonly property int downloadRowHeight: 52
    // Fila de una página (marcadores, historial): título y detalle
    readonly property int pageRowHeight: 48
    // Pantalla completa (F11): franja del borde inferior que muestra los controles
    readonly property int fullscreenRevealEdge: 4
    // Barra de título que se oculta sola: con la ventana sin maximizar, la
    // franja que la muestra va justo debajo del borde de redimensionar
    // (resizeGrip), con este alto de tolerancia
    readonly property int titleBarRevealTolerance: 10
    // Pestaña del borde inferior con los controles ocultos (ControlsTab)
    readonly property int controlsTabHeight: 22
    readonly property int controlsTabMaxWidth: 280
    // Ancho de cada lado curvo de la pestaña (relieve del borde) y cuánto se
    // tensa su curva (0,5: S simétrica; más, más redondeada arriba y abajo)
    readonly property int controlsTabSlope: 34
    readonly property real controlsTabCurve: 0.55

    // ── Tipografía ───────────────────────────────────────────────────
    readonly property int fontSizeHeading: 24
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeTitle: 14
    readonly property int fontSize: 13
    readonly property int fontSizeSmall: 12
    // Texto en lugar de icono en un botón (contador de pestañas): más pequeño
    // que el texto normal y muy grueso, que en Nunito se ve redondeado
    readonly property int fontSizeIcon: 12
    readonly property int fontWeightIcon: Font.ExtraBold
    // Texto que se escribe en los buscadores (dirección y nueva pestaña)
    readonly property int fontWeightInput: Font.Medium

    // ── Herramientas de desarrollo (F12) ─────────────────────────────
    // Paleta propia, igual en todos los temas: negro puro, blanco y un acento
    // fuerte. A propósito sin los violetas y rosas de la marca: es una
    // herramienta de trabajo y debe distinguirse de la página.
    readonly property color devtoolsBg: "#000000"
    readonly property color devtoolsSurface: "#161616"
    readonly property color devtoolsSurfaceHover: "#262626"
    readonly property color devtoolsLine: Qt.rgba(1, 1, 1, 0.16)
    readonly property color devtoolsInk: "#ffffff"
    readonly property color devtoolsInkSoft: Qt.rgba(1, 1, 1, 0.62)
    readonly property color devtoolsAccent: "#00e5ff"
    readonly property color devtoolsOnAccent: "#000000"
    readonly property color devtoolsDanger: "#ff3b30"
    readonly property int devtoolsTitleBarHeight: 44
    readonly property int devtoolsRadius: 16
    readonly property int devtoolsButtonSize: 28
    // Margen entre el borde redondeado de la ventana y el panel del motor
    readonly property int devtoolsInset: 6
    readonly property int devtoolsWidth: 1000
    readonly property int devtoolsHeight: 680

    // ── Movimiento (igual en todos los temas) ────────────────────────
    readonly property int durationFast: 140
    readonly property int durationBase: 200
    readonly property int durationSlow: 260
    // Espera antes de mostrar un tooltip: evita que salten al cruzar la barra
    readonly property int tooltipDelay: 1000
    // El indicador de zoom se queda visible este tiempo tras el último cambio
    readonly property int zoomIndicatorHold: 2000
    // Al terminar una descarga, su panel y el botón se quedan este tiempo
    readonly property int downloadPanelHold: 10000
    // Aviso «Datos borrados» de Configuración
    readonly property int clearedNoticeHold: 3000
    // La barra de título se queda este tiempo tras quitar el ratón
    readonly property int titleBarHold: 1500
    // Los controles inferiores se ocultan este tiempo después de dejar de usarlos
    readonly property int controlsHold: 1000
    // Aviso «Pulsa Esc/F11 para salir de la pantalla completa»
    readonly property int fullscreenHintHold: 3000
    // Una vuelta del anillo de progreso sin total conocido
    readonly property int durationSpin: 1000
    // Una vuelta de la barra de progreso sin total conocido
    readonly property int durationIndeterminate: 1200
    // Cada cuánto se actualiza «hace 5 min» con el listado de descargas abierto
    readonly property int relativeTimeRefresh: 30000
    readonly property var easeOut: [0.22, 1, 0.36, 1, 1, 1]
    readonly property var easeInOut: [0.4, 0, 0.2, 1, 1, 1]
    readonly property real hoverScale: 1.06
    readonly property real pressScale: 0.92
    // Fila arrastrada: algo transparente para ver qué hay debajo
    readonly property real dragOpacity: 0.85
    // Favicon de una pestaña suspendida en la lista de pestañas
    readonly property real suspendedOpacity: 0.45
    // Cada cuánto avanza el auto-scroll al arrastrar cerca de un borde (~60 fps)
    readonly property int dragScrollInterval: 16
}

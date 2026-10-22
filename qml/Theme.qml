pragma Singleton
import QtQuick

// Tema de Mitis. Tema por defecto: Nocturno, violeta/rosa sobre negro
// profundo, tomado del tema oscuro de StartCode Panel. Ningún componente
// escribe colores, medidas ni duraciones a mano: todo sale de aquí.
// Reglas y uso de cada token: DESIGN.md.
QtObject {
    readonly property string name: "Nocturno"

    // ── Fondo ────────────────────────────────────────────────────────
    readonly property color bgBase: "#07050d"
    readonly property color bgMid: "#150a2e"
    readonly property color bgGlow: "#2a1352"
    // Barra de título: versión oscura del degradado de marca (violeta → rosa)
    readonly property color titleBarStart: "#2a1352"
    readonly property color titleBarEnd: "#4a1438"
    // Controles inferiores: el mismo degradado, más oscuro y con un 8 % de
    // transparencia, repartido entre todos los controles de lado a lado
    readonly property color controlsStart: Qt.rgba(0x1d / 255, 0x0d / 255, 0x39 / 255, 0.92)
    readonly property color controlsEnd: Qt.rgba(0x34 / 255, 0x0e / 255, 0x27 / 255, 0.92)

    // ── Superficies ──────────────────────────────────────────────────
    // Flotan sobre la página: casi opacas para separarse de cualquier web
    // (equivale a glass-float, sin blur para no gastar GPU ni RAM)
    readonly property color surfaceFloat: Qt.rgba(8 / 255, 3 / 255, 20 / 255, 0.88)
    readonly property color selectBg: "#1a0f3d"
    // Velo sobre una imagen de fondo propia: mantiene legible el texto
    readonly property color backgroundScrim: Qt.rgba(7 / 255, 5 / 255, 13 / 255, 0.55)
    // Círculo claro tras los favicons: muchos son negros y no se verían
    readonly property color faviconBackdrop: Qt.rgba(1, 1, 1, 0.92)
    // Listas desplegables: opacas, porque sin blur el texto de la página de
    // detrás se mezclaría con el de la lista
    readonly property color surfacePopup: Qt.rgba(8 / 255, 3 / 255, 20 / 255, 1)

    // ── Bordes y separadores ─────────────────────────────────────────
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.13)
    readonly property color hairlineSoft: Qt.rgba(1, 1, 1, 0.12)
    readonly property color hairlineStrong: Qt.rgba(1, 1, 1, 0.20)
    readonly property color hairlineHover: Qt.rgba(1, 1, 1, 0.18)
    readonly property color line: Qt.rgba(1, 1, 1, 0.07)

    // ── Tintes de realce ─────────────────────────────────────────────
    readonly property color tintHover: Qt.rgba(1, 1, 1, 0.06)
    readonly property color tintActive: Qt.rgba(1, 1, 1, 0.10)
    readonly property color tintSunken: Qt.rgba(1, 1, 1, 0.04)

    // ── Tinta (texto e iconos) ───────────────────────────────────────
    readonly property color ink: "#f4f1ff"
    readonly property color inkStrong: Qt.rgba(1, 1, 1, 0.85)
    readonly property color inkSoft: Qt.rgba(1, 1, 1, 0.75)
    readonly property color inkSecondary: Qt.rgba(1, 1, 1, 0.65)
    readonly property color inkMuted: Qt.rgba(1, 1, 1, 0.45)
    readonly property color inkFaint: Qt.rgba(1, 1, 1, 0.35)
    readonly property color inkDisabled: Qt.rgba(1, 1, 1, 0.30)

    // ── Marca ────────────────────────────────────────────────────────
    readonly property color brand1: "#a855f7"
    readonly property color brand2: "#ec4899"
    readonly property color brandLight1: "#c084fc"
    readonly property color brandLight2: "#f472b6"
    readonly property color onBrand: "#ffffff"
    readonly property color focusRing: "#c084fc"
    readonly property color selection: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.35)

    // ── Semánticos ───────────────────────────────────────────────────
    readonly property color ok: "#34d399"
    readonly property color warn: "#fbbf24"
    readonly property color danger: "#fb7185"
    readonly property color dangerStrong: "#f43f5e"

    // ── Medidas ──────────────────────────────────────────────────────
    readonly property int titleBarHeight: 30
    readonly property int bottomBarMaxWidth: 1100
    readonly property int floatingMargin: 10
    readonly property int buttonSize: 32
    readonly property int titleButtonSize: 24
    readonly property int buttonSizeSmall: 24
    readonly property int controlHeight: 34
    readonly property int logoSize: 18
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
    readonly property int optionsWidth: 270
    readonly property int textButtonHeight: 32
    readonly property int dialogWidth: 360
    // Aviso de certificado: más texto que un diálogo normal
    readonly property int certificateDialogWidth: 440
    // Página de nueva pestaña
    readonly property int ntpMaxWidth: 720
    readonly property int ntpSearchWidth: 600
    readonly property int ntpSearchHeight: 48
    readonly property int ntpSectionSpacing: 40
    readonly property int ntpNewsTwoColumnsWidth: 560
    readonly property int tileSize: 56
    readonly property int tileWidth: 84
    readonly property int tileIconSize: 22
    readonly property int tileIconBackdrop: 34
    readonly property int quickLinksMax: 10
    readonly property int miniPlayerWidth: 270
    readonly property int findBarWidth: 440
    readonly property int zoomLabelWidth: 52
    readonly property int miniPlayerHeight: 34
    // Descarga actual: panel, barra de progreso y anillo del botón
    readonly property int downloadPanelWidth: 340
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
    // Pantalla completa (F11): franja del borde inferior que muestra los controles
    readonly property int fullscreenRevealEdge: 4

    // ── Tipografía ───────────────────────────────────────────────────
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeTitle: 14
    readonly property int fontSize: 13
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeIcon: 15

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
    // Cada cuánto avanza el auto-scroll al arrastrar cerca de un borde (~60 fps)
    readonly property int dragScrollInterval: 16
}

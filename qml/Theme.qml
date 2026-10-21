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
    readonly property int miniPlayerHeight: 34
    readonly property int tooltipPaddingX: 10
    readonly property int tooltipPaddingY: 5
    // Reordenar pestañas arrastrando: línea de destino y paso del auto-scroll
    readonly property int dropIndicatorHeight: 2
    readonly property int dragScrollStep: 6

    // ── Tipografía ───────────────────────────────────────────────────
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeTitle: 14
    readonly property int fontSize: 13
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeIcon: 15

    // ── Movimiento (igual en todos los temas) ────────────────────────
    readonly property int durationFast: 140
    readonly property int durationBase: 200
    readonly property int durationSlow: 260
    // Espera antes de mostrar un tooltip: evita que salten al cruzar la barra
    readonly property int tooltipDelay: 1000
    readonly property var easeOut: [0.22, 1, 0.36, 1, 1, 1]
    readonly property var easeInOut: [0.4, 0, 0.2, 1, 1, 1]
    readonly property real hoverScale: 1.06
    readonly property real pressScale: 0.92
    // Fila arrastrada: algo transparente para ver qué hay debajo
    readonly property real dragOpacity: 0.85
    // Cada cuánto avanza el auto-scroll al arrastrar cerca de un borde (~60 fps)
    readonly property int dragScrollInterval: 16
}

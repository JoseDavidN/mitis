import QtQuick
import QtQuick.Effects
import Mitis.Core

// Vidrio esmerilado (experimental, Configuración → Apariencia): lo que hay
// detrás del control, difuminado, con un velo morado encima, recortado con la
// forma del control. Como el reproductor de Apple Music en la web.
//
// No se usa directamente: lo ponen Surface, el fondo de todos los controles
// y tarjetas, y SurfaceShape (con forma propia). Todo lo del vidrio lleva
// «Glass» en el nombre (Glass, GlassBackdrop, GlassAurora y glass* en Theme
// y Settings); Surface, SurfaceShape y ThemeBackground son los únicos sitios
// que lo usan. Para quitarlo: DESIGN.md → Glass.
//
// Lo de detrás es el fondo más cercano marcado con `glassBackdrop: true`
// (GlassBackdrop): el primero que se encuentra entre los hermanos del control
// y de cada uno de sus contenedores, de dentro afuera. Así una tarjeta de la
// nueva pestaña difumina el fondo de esa página; un diálogo de una pestaña,
// la web; y los controles de la ventana, todas las páginas (la capa `pages`
// de Main). Lo que no tiene ninguno (las listas desplegables, que Qt pone
// aparte) usa el de la ventana (Main.glassBackdrop: la Configuración, si está
// abierta, o las páginas). Dentro del propio fondo se apaga (se copiaría a sí
// mismo), y también sin GPU (backend software, sin shaders). Copia y
// difumina solo el trozo que tapa el control, a media resolución.
Item {
    id: root

    property real radius: 0
    // Velo encima de lo difuminado (el mini reproductor, de texto blanco,
    // usa siempre el oscuro)
    property color tint: Theme.glassTint
    // Forma propia en lugar del rectángulo redondeado: un Item invisible que
    // se dibuja con esa forma en opaco y con `layer.enabled` (SurfaceShape).
    // Recorta lo difuminado y el velo
    property Item shape: null

    // La ventana dibuja con la GPU (Metal, Direct3D, Vulkan, OpenGL). Lo sabe
    // la ventana (Main.graphicsApi, preguntado a C++); si no lo dice,
    // GraphicsInfo
    readonly property string graphicsApi: Window.window && typeof Window.window.graphicsApi === "string"
                                          ? Window.window.graphicsApi : ""
    readonly property bool gpu: graphicsApi !== "" ? graphicsApi !== "software"
                              : GraphicsInfo.api !== GraphicsInfo.Software && GraphicsInfo.api !== GraphicsInfo.Unknown
    readonly property Item backdrop: Theme.glassEnabled && gpu && Window.window && root.parent ? findBackdrop() : null
    // Nunca en las ventanas privadas: su negro mate no lleva brillos
    readonly property bool active: Theme.glassEnabled && gpu && backdrop !== null && !Colors.privateWindow

    // El fondo que se ve detrás de este control, o null
    function findBackdrop() {
        for (let child = root, item = root.parent; item; child = item, item = item.parent) {
            if (item["glassBackdrop"] === true)
                return null
            for (const sibling of item.children) {
                if (sibling !== child && sibling.glassBackdrop === true && sibling.visible)
                    return sibling
            }
        }
        // (propiedades que no tiene cualquier Item o ventana: se leen por nombre)
        const window = Window.window
        return window && window["glassBackdrop"] ? window["glassBackdrop"] : null
    }

    visible: active

    ShaderEffectSource {
        id: capture
        anchors.fill: parent
        visible: false
        sourceItem: root.active ? root.backdrop : null
        live: true
        // Media resolución: difuminado no se nota y cuesta la cuarta parte
        textureSize: Qt.size(Math.max(1, Math.ceil(root.width / 2)), Math.max(1, Math.ceil(root.height / 2)))
        // Trozo de lo de detrás bajo el control. Se recalcula si se mueve o
        // cambia de tamaño el control o cualquiera de los que lo contienen
        sourceRect: {
            if (!root.active)
                return Qt.rect(0, 0, 0, 0)
            for (let item = root; item; item = item.parent) {
                item.x; item.y; item.width; item.height
            }
            const corner = root.mapToItem(root.backdrop, 0, 0)
            return Qt.rect(corner.x, corner.y, root.width, root.height)
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: capture
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: Theme.glassBlur
        saturation: Theme.glassSaturation
        maskEnabled: true
        maskSource: root.shape ?? mask
    }

    // Velo morado, igual en todos los controles
    Rectangle {
        id: veil
        anchors.fill: parent
        radius: root.radius
        color: root.tint
        visible: root.shape === null
    }
    // Con forma propia, el velo también se recorta con ella
    MultiEffect {
        anchors.fill: parent
        visible: root.shape !== null
        source: root.shape !== null ? veilSource : null
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: root.shape
    }
    Rectangle {
        id: veilSource
        anchors.fill: parent
        color: root.tint
        visible: false
        layer.enabled: root.shape !== null
    }

    // Forma del control (píldora, círculo, tarjeta): recorta el difuminado
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }
}

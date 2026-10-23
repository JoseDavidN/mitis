import QtQuick
import QtQuick.Effects

// Vidrio esmerilado (experimental, Configuración → Apariencia): lo que hay
// detrás del control, difuminado, con un velo gris neutro encima (sin el
// color del tema), recortado con la forma del control. Como el reproductor
// de Apple Music en la web.
//
// Uso: hijo del fondo del control, debajo de él, y el fondo sin relleno
// mientras esté activo:
//     Rectangle {
//         color: glass.active ? "transparent" : Theme.surfacePopup
//         Glass { id: glass; z: -1; anchors.fill: parent; radius: parent.radius }
//     }
//
// Lo de detrás es la capa de la ventana con objectName "mitisBackdrop" (las
// páginas, en Main). Se apaga solo: sin GPU (backend software, sin shaders),
// dentro de esa misma capa (se copiaría a sí mismo) o dentro de un elemento
// con `glassOpaque: true` (Configuración, que tapa las páginas). Copia y
// difumina solo el trozo que tapa el control, a media resolución.
Item {
    id: root

    property real radius: 0
    // Velo encima de lo difuminado (el mini reproductor, de texto blanco,
    // usa siempre el oscuro)
    property color tint: Theme.glassTint

    // La ventana dibuja con la GPU (Metal, Direct3D, Vulkan, OpenGL). Lo sabe
    // la ventana (Main.graphicsApi, preguntado a C++); si no lo dice,
    // GraphicsInfo
    readonly property string graphicsApi: Window.window && typeof Window.window.graphicsApi === "string"
                                          ? Window.window.graphicsApi : ""
    readonly property bool gpu: graphicsApi !== "" ? graphicsApi !== "software"
                              : GraphicsInfo.api !== GraphicsInfo.Software && GraphicsInfo.api !== GraphicsInfo.Unknown
    readonly property Item backdrop: Window.window ? findBackdrop(Window.window.contentItem) : null
    readonly property bool active: Theme.glassEnabled && gpu && backdrop !== null

    // La capa de fondo de la ventana, o null si este control está dentro de
    // ella o de algo opaco
    function findBackdrop(top) {
        for (let item = root.parent; item; item = item.parent) {
            if (item.objectName === "mitisBackdrop" || item.glassOpaque === true)
                return null
        }
        const search = (item, depth) => {
            if (!item || depth > 3)
                return null
            if (item.objectName === "mitisBackdrop")
                return item
            for (const child of item.children) {
                const found = search(child, depth + 1)
                if (found)
                    return found
            }
            return null
        }
        return search(top, 0)
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
        maskSource: mask
    }

    // Velo gris neutro, igual en todos los controles
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tint
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

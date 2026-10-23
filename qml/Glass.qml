import QtQuick
import QtQuick.Effects

// Vidrio esmerilado: lo que hay detrás del control (`backdrop`, la página),
// difuminado y recortado con la forma del control, como el reproductor de
// Apple Music en la web. Se pone debajo del relleno semitransparente.
// Solo copia y difumina el trozo que tapa el control (sourceRect), así que
// la memoria extra es mínima; se vuelve a difuminar cuando cambia lo de
// detrás. Sin GPU (backend software) no hay shaders: no se dibuja y el
// control queda como siempre (`available` en falso).
Item {
    id: root

    // Lo que se ve a través (la página); debe estar detrás del control y no
    // contenerlo, o la copia se incluiría a sí misma
    property Item backdrop: null
    property real radius: 0

    readonly property bool available: Theme.glassEnabled && backdrop !== null
                                      && GraphicsInfo.api !== GraphicsInfo.Software

    visible: available

    ShaderEffectSource {
        id: capture
        anchors.fill: parent
        visible: false
        sourceItem: root.available ? root.backdrop : null
        live: true
        // Trozo de la página bajo el control. Se recalcula si se mueve o
        // cambia de tamaño el control o cualquiera de los que lo contienen
        sourceRect: {
            if (!root.available)
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

    // Forma del control (píldora o círculo): recorta el difuminado
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }
}

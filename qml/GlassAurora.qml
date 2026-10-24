pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Manchas de color de la marca en el fondo de las páginas propias, solo con
// la transparencia experimental: sobre un fondo liso el vidrio esmerilado no
// tendría nada que difuminar. Degradados radiales (sin shaders ni imágenes):
// también sin GPU y sin gastar memoria.
Item {
    id: root

    visible: Theme.glassEnabled
    opacity: Theme.glassAuroraOpacity

    // Posición (en fracciones del fondo), tamaño (del lado mayor) y color
    readonly property var spots: [
        { x: 0.82, y: 0.12, size: 0.55, color: Theme.brand1 },
        { x: 0.12, y: 0.78, size: 0.6, color: Theme.brand2 },
        { x: 0.55, y: 0.6, size: 0.4, color: Theme.brandLight1 }
    ]

    Repeater {
        model: root.visible ? root.spots : []

        delegate: Shape {
            id: spot

            required property var modelData
            readonly property real radius: Math.max(root.width, root.height) * modelData.size / 2

            anchors.fill: parent

            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: root.width * spot.modelData.x
                    centerY: root.height * spot.modelData.y
                    centerRadius: spot.radius
                    focalX: centerX
                    focalY: centerY
                    GradientStop { position: 0.0; color: spot.modelData.color }
                    GradientStop { position: 1.0; color: Qt.rgba(spot.modelData.color.r, spot.modelData.color.g, spot.modelData.color.b, 0) }
                }
                startX: 0; startY: 0
                PathLine { x: root.width; y: 0 }
                PathLine { x: root.width; y: root.height }
                PathLine { x: 0; y: root.height }
                PathLine { x: 0; y: 0 }
            }
        }
    }
}

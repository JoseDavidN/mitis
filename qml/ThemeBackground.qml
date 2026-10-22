import QtQuick
import QtQuick.Shapes

// Fondo del tema para las páginas propias (nueva pestaña, Configuración):
// resplandor arriba a la izquierda (Theme.bgGlow) que se funde en el fondo.
Shape {
    id: root

    ShapePath {
        strokeWidth: -1
        fillGradient: RadialGradient {
            centerX: root.width * 0.2
            centerY: 0
            centerRadius: Math.max(root.width, root.height) * 1.1
            focalX: centerX
            focalY: centerY
            GradientStop { position: 0.0; color: Theme.bgGlow }
            GradientStop { position: 0.35; color: Theme.bgMid }
            GradientStop { position: 0.8; color: Theme.bgBase }
        }
        PathLine { x: root.width; y: 0 }
        PathLine { x: root.width; y: root.height }
        PathLine { x: 0; y: root.height }
        PathLine { x: 0; y: 0 }
    }
}

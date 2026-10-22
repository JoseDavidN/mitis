import QtQuick

// Círculo de elección única (como un botón de opción). Solo dibuja: la fila
// que lo contiene decide y atiende el clic. Elegido: relleno con el degradado
// de marca y punto onBrand; sin elegir, solo el aro.
Item {
    id: root

    property bool checked: false
    property bool hovered: false

    implicitWidth: Theme.radioSize
    implicitHeight: Theme.radioSize

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: root.hovered ? Theme.hairlineHover : Theme.hairlineStrong
        visible: !root.checked
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: root.checked
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.brand1 }
            GradientStop { position: 1.0; color: Theme.brand2 }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Theme.radioDotSize
            height: Theme.radioDotSize
            radius: width / 2
            color: Theme.onBrand
        }
    }
}

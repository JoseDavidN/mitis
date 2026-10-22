import QtQuick

// Casilla de verificación. Solo dibuja: la fila que la contiene decide y
// atiende el clic. Marcada: degradado de marca con la marca en onBrand;
// sin marcar, solo el borde.
Item {
    id: root

    property bool checked: false
    property bool hovered: false

    implicitWidth: Theme.radioSize
    implicitHeight: Theme.radioSize

    Rectangle {
        anchors.fill: parent
        radius: Theme.checkRadius
        color: "transparent"
        border.width: 1
        border.color: root.hovered ? Theme.hairlineHover : Theme.hairlineStrong
        visible: !root.checked
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.checkRadius
        visible: root.checked
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.brand1 }
            GradientStop { position: 1.0; color: Theme.brand2 }
        }

        Icon {
            anchors.centerIn: parent
            name: "check"
            size: Theme.iconSizeSmall
            color: Theme.onBrand
        }
    }
}

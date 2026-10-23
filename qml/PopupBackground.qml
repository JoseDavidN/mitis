import QtQuick

// Fondo común de las listas desplegables: redondeado, sin sombra.
Rectangle {
    radius: Theme.radius
    color: glass.active ? "transparent" : Theme.surfacePopup
    border.width: 1
    border.color: Theme.hairlineStrong

    // Vidrio esmerilado (experimental): la página difuminada debajo
    Glass {
        id: glass
        z: -1
        anchors.fill: parent
        radius: parent.radius
    }
}

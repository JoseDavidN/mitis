import QtQuick
import QtQuick.Window

// Barra de título de Mitis: marca a la izquierda y controles de ventana
// a la derecha. Se arrastra para mover la ventana y con doble clic se
// maximiza o restaura.
Rectangle {
    id: root

    required property Window window
    // Ventana privada: lo indica junto al nombre
    property bool privateMode: false

    readonly property bool maximized: window.visibility === Window.Maximized
    // En pantalla completa la ventana no se mueve ni se maximiza desde aquí
    readonly property bool fullScreen: window.visibility === Window.FullScreen

    function toggleMaximized() {
        if (maximized)
            window.showNormal()
        else
            window.showMaximized()
    }

    implicitHeight: Theme.titleBarHeight

    // Violeta oscuro a la izquierda, rosa oscuro a la derecha
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Theme.titleBarStart }
        GradientStop { position: 1.0; color: Theme.titleBarEnd }
    }

    // Separador inferior
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.hairlineSoft
    }

    // Zona de arrastre: los botones quedan por encima y no la activan
    DragHandler {
        target: null
        enabled: !root.fullScreen
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        onActiveChanged: if (active) root.window.startSystemMove()
    }
    TapHandler {
        gesturePolicy: TapHandler.DragThreshold
        enabled: !root.fullScreen
        onDoubleTapped: root.toggleMaximized()
    }

    // Marca. El cuadrado con degradado ocupa el lugar del icono hasta tenerlo
    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin + Theme.spacing / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing

        Rectangle {
            width: Theme.logoSize
            height: Theme.logoSize
            radius: Theme.radiusSmall
            anchors.verticalCenter: parent.verticalCenter
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.brand1 }
                GradientStop { position: 1.0; color: Theme.brand2 }
            }
        }

        Text {
            text: "Mitis"
            color: Theme.inkSoft
            font.pixelSize: Theme.fontSizeTitle
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
        // «Privada», en píldora con el color de la marca
        Rectangle {
            visible: root.privateMode
            anchors.verticalCenter: parent.verticalCenter
            width: privateRow.width + 2 * Theme.spacing
            height: Theme.logoSize
            radius: height / 2
            color: Theme.tintActive
            border.width: 1
            border.color: Theme.brandLight1

            Row {
                id: privateRow
                anchors.centerIn: parent
                spacing: Theme.spacing / 2

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "private"
                    size: Theme.iconSizeSmall
                    color: Theme.brandLight1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Privada"
                    color: Theme.brandLight1
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                }
            }
        }
    }

    // Controles de ventana: solo el icono; el círculo aparece al pasar por encima
    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing

        IconButton {
            flat: true
            implicitWidth: Theme.titleButtonSize
            implicitHeight: Theme.titleButtonSize
            icon: "minimize"
            tooltip: "Minimizar"
            tooltipBelow: true
            iconSize: Theme.iconSizeSmall
            onClicked: root.window.showMinimized()
        }
        IconButton {
            flat: true
            implicitWidth: Theme.titleButtonSize
            implicitHeight: Theme.titleButtonSize
            icon: root.maximized ? "restore" : "maximize"
            tooltip: root.maximized ? "Restaurar" : "Maximizar"
            tooltipBelow: true
            iconSize: Theme.iconSizeSmall
            onClicked: root.toggleMaximized()
        }
        IconButton {
            flat: true
            implicitWidth: Theme.titleButtonSize
            implicitHeight: Theme.titleButtonSize
            icon: "close"
            iconSize: Theme.iconSizeSmall
            tooltip: "Cerrar"
            tooltipBelow: true
            danger: true
            onClicked: root.window.close()
        }
    }
}

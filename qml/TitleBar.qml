import QtQuick
import Mitis.Core
import QtQuick.Window

// Barra de título de Mitis: marca a la izquierda y controles de ventana
// a la derecha. Se arrastra para mover la ventana y con doble clic se
// maximiza o restaura.
Rectangle {
    id: root

    required property Window window
    // Ventana privada: lo indica junto al nombre
    property bool privateMode: false

    // Versión de prueba («0.5.0-beta»): se marca junto al nombre
    readonly property bool beta: Qt.application.version.indexOf("beta") >= 0

    // Pulsó su avatar (abre Configuración → Perfil)
    signal profileRequested()

    // En macOS, los botones de ventana del sistema (a la izquierda, redondos)
    readonly property bool macStyle: Qt.platform.os === "osx" || Qt.platform.os === "macos"

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
        GradientStop { position: 0.0; color: glass.active ? "transparent" : Theme.titleBarStart }
        GradientStop { position: 1.0; color: glass.active ? "transparent" : Theme.titleBarEnd }
    }

    // Vidrio esmerilado (experimental): la página difuminada debajo
    Glass {
        id: glass
        z: -1
        anchors.fill: parent
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

    // macOS: cerrar, minimizar y zoom como en el sistema (círculos de color a
    // la izquierda; al pasar el ratón por el grupo, su símbolo)
    Row {
        id: macControls
        visible: root.macStyle
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.macDotSpacing

        HoverHandler { id: macHover }

        MacDot {
            groupHovered: macHover.hovered
            tone: Theme.macClose
            symbol: "close"
            tooltip: "Cerrar"
            onClicked: root.window.close()
        }
        MacDot {
            groupHovered: macHover.hovered
            tone: Theme.macMinimize
            symbol: "minimize"
            tooltip: "Minimizar"
            onClicked: root.window.showMinimized()
        }
        MacDot {
            groupHovered: macHover.hovered
            tone: Theme.macZoom
            symbol: root.maximized ? "restore" : "maximize"
            tooltip: root.maximized ? "Restaurar" : "Maximizar"
            onClicked: root.toggleMaximized()
        }
    }

    // Marca: el nombre de Mitis (el del logo, sin el icono), en su versión
    // para temas oscuros o para el Claro. En macOS, centrado, como el título
    // de las ventanas del sistema; en Windows y Linux, a la izquierda
    Row {
        anchors.left: root.macStyle ? undefined : parent.left
        anchors.leftMargin: Theme.margin + Theme.spacing / 2
        anchors.horizontalCenter: root.macStyle ? parent.horizontalCenter : undefined
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing

        Image {
            height: Theme.titleBarLogoHeight
            width: height * implicitWidth / Math.max(1, implicitHeight)
            anchors.verticalCenter: parent.verticalCenter
            source: Theme.dark ? "qrc:/branding/mitis-wordmark-dark.png" : "qrc:/branding/mitis-wordmark-light.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
        // «Beta» mientras la versión lo sea (CMakeLists.txt: MITIS_VERSION_SUFFIX)
        Rectangle {
            visible: root.beta
            anchors.verticalCenter: parent.verticalCenter
            width: betaText.width + 2 * Theme.spacing
            height: Theme.logoSize
            radius: height / 2
            color: Theme.tintActive
            border.width: 1
            border.color: Theme.hairlineStrong

            Text {
                id: betaText
                anchors.centerIn: parent
                text: "Beta"
                color: Theme.inkSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
            }
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

    // Avatar del perfil, delante de los controles de ventana (no en las
    // ventanas privadas: no son del perfil)
    Item {
        visible: !root.privateMode
        anchors.right: root.macStyle ? parent.right : windowControls.left
        anchors.rightMargin: root.macStyle ? Theme.margin : Theme.spacing
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.titleButtonSize
        height: Theme.titleButtonSize

        Avatar {
            anchors.centerIn: parent
            size: Theme.logoSize
            name: Settings.profileName
            photo: Settings.profilePhoto
            colorKey: Settings.profileColor
            scale: avatarHover.hovered ? Theme.hoverScale : 1
            Behavior on scale { NumberAnimation { duration: Theme.durationFast } }
        }
        HoverHandler {
            id: avatarHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: root.profileRequested()
        }
        Tooltip {
            text: Settings.profileName !== "" ? Settings.profileName + " · Perfil" : "Perfil"
            below: true
            visible: avatarHover.hovered
        }
    }

    // Controles de ventana: solo el icono; el círculo aparece al pasar por encima
    Row {
        id: windowControls
        visible: !root.macStyle
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

    // Botón redondo de macOS: color de Apple (gris con la ventana inactiva) y
    // su símbolo al pasar el ratón por el grupo
    component MacDot: Item {
        id: dot

        property color tone: "transparent"
        property string symbol: ""
        property string tooltip: ""
        // El ratón está sobre el grupo: los tres muestran su símbolo
        property bool groupHovered: false

        signal clicked()

        width: Theme.macDotSize
        height: Theme.macDotSize

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: dot.Window.active || dot.groupHovered ? dot.tone : Theme.macDotInactive
            border.width: 1
            border.color: Theme.macDotBorder
        }
        Icon {
            anchors.centerIn: parent
            name: dot.symbol
            size: Theme.macDotSize - 4
            color: Theme.macDotSymbol
            visible: dot.groupHovered
        }
        HoverHandler {
            id: dotHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: dot.clicked()
        }
        Tooltip {
            text: dot.tooltip
            below: true
            visible: dotHover.hovered
        }
    }
}

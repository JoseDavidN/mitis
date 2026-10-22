pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window

// Ventana de las herramientas de desarrollo (F12) de una pestaña. Sin marco
// del sistema, redondeada y con paleta propia (Theme.devtools*): negro,
// blanco y un acento fuerte. El panel lo pone la pestaña con openDevTools()
// dentro de `container`; esta ventana no conoce el motor.
Window {
    id: root

    // Título de la página inspeccionada
    property string pageTitle: ""

    // El panel va aquí (BrowserTab.openDevTools)
    readonly property alias container: panel

    // Se cerró la ventana (botón, Alt+F4…): quien la creó la destruye
    signal dismissed()

    readonly property bool maximized: visibility === Window.Maximized

    function toggleMaximized() {
        if (maximized)
            showNormal()
        else
            showMaximized()
    }

    width: Math.min(Theme.devtoolsWidth, Screen.desktopAvailableWidth)
    height: Math.min(Theme.devtoolsHeight, Screen.desktopAvailableHeight)
    minimumWidth: 480
    minimumHeight: 320
    flags: Qt.Window | Qt.FramelessWindowHint
    // Transparente para que se vean las esquinas redondeadas (sin compositor,
    // el sistema las pinta negras: el mismo color del marco)
    color: "transparent"
    title: (pageTitle !== "" ? pageTitle + " — " : "") + "Herramientas de desarrollo"

    onClosing: root.dismissed()

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: root.maximized ? 0 : Theme.devtoolsRadius
        color: Theme.devtoolsBg
        border.width: root.maximized ? 0 : 1
        border.color: Theme.devtoolsLine

        // ── Barra de título ──────────────────────────────────────────
        Item {
            id: titleBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Theme.devtoolsTitleBarHeight

            DragHandler {
                target: null
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                onActiveChanged: if (active) root.startSystemMove()
            }
            TapHandler {
                gesturePolicy: TapHandler.DragThreshold
                onDoubleTapped: root.toggleMaximized()
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.margin
                anchors.right: controls.left
                anchors.rightMargin: Theme.margin
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.margin

                // Etiqueta en píldora de acento
                Rectangle {
                    id: badge
                    anchors.verticalCenter: parent.verticalCenter
                    width: badgeRow.implicitWidth + 2 * Theme.margin
                    height: Theme.devtoolsButtonSize
                    radius: height / 2
                    color: Theme.devtoolsAccent

                    Row {
                        id: badgeRow
                        anchors.centerIn: parent
                        spacing: Theme.spacing / 2

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "devtools"
                            color: Theme.devtoolsOnAccent
                            size: Theme.iconSizeSmall
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "DevTools"
                            color: Theme.devtoolsOnAccent
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.Black
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - badge.width - parent.spacing
                    text: root.pageTitle !== "" ? root.pageTitle : "Página sin título"
                    color: Theme.devtoolsInk
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
            }

            Row {
                id: controls
                anchors.right: parent.right
                anchors.rightMargin: Theme.margin
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing

                WindowButton {
                    icon: "minimize"
                    label: "Minimizar"
                    onClicked: root.showMinimized()
                }
                WindowButton {
                    icon: root.maximized ? "restore" : "maximize"
                    label: root.maximized ? "Restaurar" : "Maximizar"
                    onClicked: root.toggleMaximized()
                }
                WindowButton {
                    icon: "close"
                    label: "Cerrar"
                    shortcut: "F12"
                    danger: true
                    onClicked: root.close()
                }
            }
        }

        // ── Panel del motor ──────────────────────────────────────────
        // Separado del borde para que no tape las esquinas redondeadas
        Rectangle {
            anchors.fill: panel
            anchors.margins: -1
            radius: Theme.radiusSmall
            color: "transparent"
            border.width: 1
            border.color: Theme.devtoolsLine
        }
        Item {
            id: panel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleBar.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.devtoolsInset
            anchors.rightMargin: Theme.devtoolsInset
            anchors.bottomMargin: Theme.devtoolsInset
        }
    }

    ResizeHandles {
        window: root
    }

    // Botón redondo de la barra: gris oscuro; al pasar, acento (o rojo
    // para cerrar) con el icono en negro
    component WindowButton: Item {
        id: button

        property string icon: ""
        property string label: ""
        property string shortcut: ""
        property bool danger: false

        signal clicked()

        readonly property bool hovered: hover.hovered
        readonly property color fill: !hovered ? Theme.devtoolsSurface
                                    : danger ? Theme.devtoolsDanger : Theme.devtoolsAccent

        width: Theme.devtoolsButtonSize
        height: Theme.devtoolsButtonSize

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: button.fill
            scale: tap.pressed ? Theme.pressScale : 1
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            Behavior on scale { NumberAnimation { duration: Theme.durationFast } }

            Icon {
                anchors.centerIn: parent
                name: button.icon
                size: Theme.iconSizeSmall
                color: button.hovered ? Theme.devtoolsOnAccent : Theme.devtoolsInk
            }
        }

        Tooltip {
            text: button.label
            shortcut: button.shortcut
            below: true
            visible: button.hovered && !tap.pressed
        }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: tap
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: button.clicked()
        }
    }
}

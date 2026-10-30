pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

import "urls.js" as Urls

// Panel de las esenciales, desplegado desde su pestaña del borde izquierdo
// (EssentialsTab): una columna de botones pequeños con el icono de cada
// página (como mucho Theme.essentialsMax) y, si cabe otra, uno para añadir
// la pestaña que se ve. Al pasar el ratón por una, una ✕ en su esquina la
// devuelve a la lista de pestañas. Solo existe abierto (LazyPopup).
Popup {
    id: root

    // Modelo de pestañas de Main: las esenciales son las primeras `essentialCount` filas
    required property var tabs
    property int essentialCount: 0
    property int currentIndex: -1
    // Se puede añadir la pestaña a la vista (no es esencial y queda sitio)
    property bool canAdd: false

    signal essentialSelected(int index)
    signal essentialRemoved(int index)
    signal addRequested()

    padding: Theme.spacing
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: PopupBackground {}

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationFast }
    }

    contentItem: Column {
        spacing: Theme.spacing

        Repeater {
            model: root.tabs

            delegate: Item {
                id: essential

                required property int index
                required property string title
                required property url icon
                required property url url

                readonly property bool current: index === root.currentIndex
                readonly property bool hovered: hover.hovered

                // Las demás filas del modelo no son esenciales: la columna se las salta
                visible: index < root.essentialCount
                width: Theme.essentialButtonWidth
                height: Theme.essentialButtonHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: essential.current ? Colors.tintActive
                                             : essential.hovered ? Colors.tintHover : Colors.tintSunken
                    border.width: essential.current ? 1 : 0
                    border.color: Colors.brandLight1
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Image {
                    id: favicon
                    anchors.centerIn: parent
                    width: Theme.iconSize
                    height: Theme.iconSize
                    sourceSize: Qt.size(2 * Theme.iconSize, 2 * Theme.iconSize)
                    source: essential.icon
                    smooth: true
                    mipmap: true
                    visible: status === Image.Ready
                }
                // Sin icono (aún sin cargar): la inicial del sitio
                Text {
                    anchors.centerIn: parent
                    visible: !favicon.visible
                    text: (Urls.host(essential.url.toString()).replace(/^www\./, "") || essential.title || "?")
                          .charAt(0).toUpperCase()
                    color: Colors.inkSecondary
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        root.essentialSelected(essential.index)
                        root.close()
                    }
                }
                Tooltip {
                    x: parent.width + Theme.spacing
                    y: (parent.height - height) / 2
                    text: essential.title || essential.url.toString() || "Nueva pestaña"
                    shortcut: "Ctrl+" + (essential.index + 1)
                    visible: essential.hovered && !removeButton.hovered
                }

                // Quitar de esenciales: vuelve a la lista de pestañas
                IconButton {
                    id: removeButton
                    x: parent.width - width / 2 - Theme.spacing / 2
                    y: -height / 2 + Theme.spacing / 2
                    width: Theme.essentialRemoveSize
                    height: Theme.essentialRemoveSize
                    icon: "close"
                    iconSize: Theme.essentialRemoveIconSize
                    danger: true
                    tooltip: "Quitar de esenciales"
                    opacity: essential.hovered || hovered ? 1 : 0
                    enabled: opacity > 0
                    onClicked: root.essentialRemoved(essential.index)
                }
            }
        }

        // Añadir la pestaña que se ve
        IconButton {
            visible: root.canAdd
            width: Theme.essentialButtonWidth
            height: Theme.essentialButtonHeight
            flat: true
            icon: "essential-add"
            iconSize: Theme.iconSizeSmall
            tooltip: "Añadir esta pestaña a esenciales"
            onClicked: root.addRequested()
        }
    }
}

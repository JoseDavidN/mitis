pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic

// Menú de opciones. Lo que aún no está disponible sale como «Próximamente».
Popup {
    id: root

    // Cada opción: { key, label, icon, available }
    property var options: [
        { key: "history", label: "Historial", icon: "history", available: false },
        { key: "downloads", label: "Descargas", icon: "downloads", available: true },
        { key: "profile", label: "Perfil", icon: "profile", available: false },
        { key: "search", label: "Motor de búsqueda", icon: "search", available: true },
        { key: "settings", label: "Configuración", icon: "settings", available: false }
    ]

    signal optionSelected(string key)

    width: Theme.optionsWidth
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
        Repeater {
            model: root.options

            delegate: Item {
                id: row

                required property var modelData

                width: parent.width
                height: Theme.popupRowHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: rowHover.hovered && row.modelData.available ? Theme.tintHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Icon {
                    id: optionIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    name: row.modelData.icon ?? ""
                    color: row.modelData.available ? Theme.inkSoft : Theme.inkMuted
                }

                Text {
                    anchors.left: optionIcon.right
                    anchors.leftMargin: Theme.spacing
                    anchors.right: soon.visible ? soon.left : parent.right
                    anchors.rightMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                    color: row.modelData.available ? Theme.ink : Theme.inkMuted
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }

                Text {
                    id: soon
                    visible: !row.modelData.available
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Próximamente"
                    color: Theme.inkFaint
                    font.pixelSize: Theme.fontSizeSmall
                }

                HoverHandler { id: rowHover }
                TapHandler {
                    enabled: row.modelData.available
                    // Agarre exclusivo al pulsar: si no, la página de debajo
                    // (p. ej. una noticia de la nueva pestaña) recibe también el clic
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        root.optionSelected(row.modelData.key)
                        root.close()
                    }
                }
            }
        }
    }
}

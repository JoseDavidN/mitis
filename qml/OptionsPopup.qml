pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

// Menú de opciones. Lo que aún no está disponible sale como «Próximamente».
Popup {
    id: root

    // Herramientas de desarrollo activadas: añade «Uso de memoria»
    property bool developer: false

    // Cada opción: { key, label, icon, available, shortcut (opcional) }
    readonly property var options: [
        // Con el nombre del perfil, si tiene; el icono es su avatar
        { key: "profile", label: Settings.profileName || "Perfil", icon: "profile", available: true },
        { key: "private", label: "Nueva ventana privada", icon: "private", available: true, shortcut: "Ctrl+Shift+N" },
        { key: "history", label: "Historial", icon: "history", available: true },
        { key: "downloads", label: "Descargas", icon: "downloads", available: true },
        { key: "memory", label: "Uso de memoria", icon: "memory", available: true, shortcut: "Shift+Esc" },
        { key: "settings", label: "Configuración", icon: "settings", available: true }
    ].filter(option => developer || option.key !== "memory")

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
                    opacity: row.modelData.key === "profile" ? 0 : 1
                }
                Avatar {
                    visible: row.modelData.key === "profile"
                    anchors.centerIn: optionIcon
                    size: Theme.logoSize
                    name: Settings.profileName
                    photo: Settings.profilePhoto
                    colorKey: Settings.profileColor
                }

                Text {
                    anchors.left: optionIcon.right
                    anchors.leftMargin: Theme.spacing
                    anchors.right: soon.left
                    anchors.rightMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                    color: row.modelData.available ? Theme.ink : Theme.inkMuted
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }

                // «Próximamente» o el atajo
                Text {
                    id: soon
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.available ? (row.modelData.shortcut ?? "") : "Próximamente"
                    color: row.modelData.available ? Theme.inkMuted : Theme.inkFaint
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

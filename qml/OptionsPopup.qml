pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

// Menú de opciones. Lo que aún no está disponible sale como «Próximamente».
// Contraseñas también en la ventana privada: es la cuenta del gestor, no la navegación.
Popup {
    id: root

    // Monitor de rendimiento activado (Configuración → Desarrollo): añade su opción
    property bool performanceMonitor: false
    // Ventana privada: sin perfil, historial ni Configuración (es privada del todo)
    property bool privateMode: false

    // Cada opción: { key, label, icon, available, shortcut (opcional) }
    readonly property var options: [
        // Con el nombre del perfil, si tiene; el icono es su avatar
        { key: "profile", label: Settings.profileName || "Perfil", icon: "profile", available: true,
          avatar: { name: Settings.profileName, photo: Settings.profilePhoto, color: Settings.profileColor } },
        // Los demás perfiles (otro Mitis cada uno: Profiles), para abrirlos.
        // La lista se lee al abrir el menú (solo existe abierto)
        ...(privateMode ? [] : Profiles.list().filter(profile => !profile.current).map(profile => ({
            key: "profile:" + profile.id,
            label: profile.name || (profile.id === "" ? "Perfil principal" : "Perfil"),
            icon: "profile", available: true, shortcut: profile.running ? "Abierto" : "",
            avatar: { name: profile.name, photo: profile.photo, color: profile.color }
        }))),
        { key: "newProfile", label: "Nueva ventana con otro perfil", icon: "add", available: true, shortcut: "Ctrl+N" },
        { key: "private", label: "Nueva ventana privada", icon: "private", available: true, shortcut: "Ctrl+Shift+N" },
        { key: "history", label: "Historial", icon: "history", available: true },
        { key: "downloads", label: "Descargas", icon: "downloads", available: true },
        { key: "passwords", label: "Contraseñas", icon: "passwords", available: true },
        { key: "performance", label: "Monitor de rendimiento", icon: "memory", available: true, shortcut: "Shift+Esc" },
        { key: "settings", label: "Configuración", icon: "settings", available: true }
    ].filter(option => (performanceMonitor || option.key !== "performance")
                       && !(privateMode && ["profile", "newProfile", "history", "settings"].includes(option.key)))

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
                    color: rowHover.hovered && row.modelData.available ? Colors.tintHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Icon {
                    id: optionIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    name: row.modelData.icon ?? ""
                    color: row.modelData.available ? Colors.inkSoft : Colors.inkMuted
                    opacity: row.modelData.avatar ? 0 : 1
                }
                Avatar {
                    visible: row.modelData.avatar !== undefined
                    anchors.centerIn: optionIcon
                    size: Theme.logoSize
                    name: row.modelData.avatar?.name ?? ""
                    photo: row.modelData.avatar?.photo ?? ""
                    colorKey: row.modelData.avatar?.color ?? ""
                }

                Text {
                    anchors.left: optionIcon.right
                    anchors.leftMargin: Theme.spacing
                    anchors.right: soon.left
                    anchors.rightMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                    color: row.modelData.available ? Colors.ink : Colors.inkMuted
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
                    color: row.modelData.available ? Colors.inkMuted : Colors.inkFaint
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

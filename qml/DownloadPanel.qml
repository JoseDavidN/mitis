pragma ComponentBehavior: Bound
import QtQuick
// Con prefijo: Controls también tiene un ProgressBar
import QtQuick.Controls.Basic as T

// Panel de la descarga actual, anclado al botón de descargas de la barra
// inferior. Se abre solo al empezar una descarga y al terminar; terminada,
// se queda `Theme.downloadPanelHold` (sin cerrarse con el ratón encima) y
// luego se cierra y `active` pasa a false: el botón de descargas desaparece.
// También lleva la cuenta de qué descarga sigue el botón (`item`).
T.Popup {
    id: root

    // Descarga que se muestra y una copia de sus datos (roles de Downloads)
    property int downloadId: -1
    property var item: null
    // Mientras es true, el botón de descargas está visible
    property bool active: false
    // Terminó la que se muestra: cuenta atrás para cerrar panel y botón
    property bool ending: false

    readonly property string downloadState: item ? item.state : ""
    readonly property bool downloading: downloadState === "progress" || downloadState === "paused"
    readonly property bool knownTotal: item !== null && item.total > 0
    readonly property real progress: knownTotal ? item.received / item.total : 0

    // Abre el panel (botón de descargas). Si está terminando, vuelve a contar.
    function show() {
        open()
        if (ending)
            hold.restart()
    }

    function refresh() {
        item = downloadId < 0 ? null : Downloads.get(downloadId)
        // La quitaron del listado: no queda nada que mostrar
        if (!item && active)
            expire()
    }

    // Fin de la cuenta atrás: se cierra el panel y, si no queda ninguna
    // descarga en curso, también el botón
    function expire() {
        hold.stop()
        ending = false
        close()
        for (let i = 0; i < Downloads.items.count; i++) {
            const other = Downloads.items.get(i)
            if (Downloads.isActive(other.state)) {
                downloadId = other.id
                return
            }
        }
        active = false
    }

    onDownloadIdChanged: refresh()

    Connections {
        target: Downloads
        function onStarted(id) {
            hold.stop()
            root.ending = false
            root.downloadId = id
            root.active = true
            root.open()
        }
        function onFinished(id) {
            if (id !== root.downloadId)
                return
            root.refresh()
            root.ending = true
            root.open()
            hold.restart()
        }
    }

    Connections {
        target: Downloads.items
        function onDataChanged() { root.refresh() }
        function onRowsRemoved() { root.refresh() }
    }

    Timer {
        id: hold
        interval: Theme.downloadPanelHold
        // Con el ratón encima espera; al salir vuelve a contar
        onTriggered: if (!(root.visible && hover.hovered)) root.expire()
    }

    width: Theme.downloadPanelWidth
    padding: 0
    // No quita el teclado a la página: se abre solo, mientras se navega
    focus: false
    closePolicy: T.Popup.CloseOnPressOutsideParent

    background: PopupBackground {}

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationFast }
    }

    contentItem: Item {
        implicitHeight: content.implicitHeight + 2 * Theme.margin

        HoverHandler {
            id: hover
            onHoveredChanged: if (!hovered && root.ending) hold.restart()
        }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.margin
            spacing: Theme.spacing

            // Icono, nombre y cerrar
            Item {
                width: parent.width
                height: Theme.buttonSizeSmall

                Icon {
                    id: stateIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.downloadState === "done" ? "download-done"
                        : root.downloadState === "failed" ? "download-failed"
                        : root.downloadState === "canceled" ? "download-cancel" : "downloads"
                    color: root.downloadState === "done" ? Theme.ok
                         : root.downloadState === "failed" ? Theme.danger
                         : root.downloadState === "progress" ? Theme.brandLight1 : Theme.inkMuted
                }

                Text {
                    anchors.left: stateIcon.right
                    anchors.leftMargin: Theme.spacing
                    anchors.right: closeButton.left
                    anchors.rightMargin: Theme.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.item ? root.item.fileName : ""
                    color: Theme.ink
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    // Por el medio: se conserva la extensión
                    elide: Text.ElideMiddle
                }

                IconButton {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.buttonSizeSmall
                    height: Theme.buttonSizeSmall
                    flat: true
                    icon: "close"
                    iconSize: Theme.iconSizeSmall
                    tooltip: "Cerrar"
                    onClicked: root.close()
                }
            }

            ProgressBar {
                visible: root.downloading || root.downloadState === "done"
                width: parent.width
                value: root.downloadState === "done" ? 1 : root.progress
                indeterminate: root.downloadState === "progress" && !root.knownTotal
            }

            // Estado y, mientras descarga, pausar/reanudar y cancelar
            Item {
                width: parent.width
                height: Theme.buttonSizeSmall

                Text {
                    anchors.left: parent.left
                    anchors.right: runningActions.visible ? runningActions.left : parent.right
                    anchors.rightMargin: Theme.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    color: root.downloadState === "failed" ? Theme.danger : Theme.inkSecondary
                    text: {
                        const item = root.item
                        if (!item)
                            return ""
                        const size = root.knownTotal
                                ? Downloads.formatBytes(item.received) + " de " + Downloads.formatBytes(item.total)
                                : Downloads.formatBytes(item.received)
                        switch (item.state) {
                        case "paused": return size + " · En pausa"
                        case "done": return "Completada · " + Downloads.formatBytes(item.received)
                        case "failed": return item.error ? "Error: " + item.error : "Error"
                        case "canceled": return "Cancelada"
                        default: return size
                        }
                    }
                }

                Row {
                    id: runningActions
                    visible: root.downloading
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing / 2

                    IconButton {
                        width: Theme.buttonSizeSmall
                        height: Theme.buttonSizeSmall
                        flat: true
                        icon: root.downloadState === "paused" ? "play" : "pause"
                        iconSize: Theme.iconSizeSmall
                        tooltip: root.downloadState === "paused" ? "Reanudar" : "Pausar"
                        onClicked: root.downloadState === "paused" ? Downloads.resume(root.downloadId)
                                                            : Downloads.pause(root.downloadId)
                    }
                    IconButton {
                        width: Theme.buttonSizeSmall
                        height: Theme.buttonSizeSmall
                        flat: true
                        danger: true
                        icon: "download-cancel"
                        iconSize: Theme.iconSizeSmall
                        tooltip: "Cancelar"
                        onClicked: Downloads.cancel(root.downloadId)
                    }
                }
            }

            // Terminada: abrir la carpeta o el archivo
            Row {
                visible: root.downloadState === "done"
                x: parent.width - width
                spacing: Theme.spacing

                TextButton {
                    text: "Abrir carpeta"
                    onClicked: Downloads.openFolder(root.downloadId)
                }
                TextButton {
                    text: "Abrir"
                    primary: true
                    onClicked: Downloads.openFile(root.downloadId)
                }
            }
        }
    }
}

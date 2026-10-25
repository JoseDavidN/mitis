pragma ComponentBehavior: Bound
import QtQuick
// Con prefijo: Controls también tiene un ProgressBar
import QtQuick.Controls.Basic as T
import Mitis.Core

// Panel de las descargas de ahora, anclado al botón de descargas de la barra
// inferior: una fila por descarga de esta tanda (las que siguen en curso y
// las que terminaron desde que se abrió), la más reciente arriba. Se abre
// solo al empezar una descarga y al terminar cada una. Cuando ya no queda
// ninguna en curso se queda `Theme.downloadPanelHold` (sin cerrarse con el
// ratón encima), luego se cierra, olvida las terminadas y `active` pasa a
// false: el botón de descargas desaparece.
T.Popup {
    id: root

    // Descargas de la tanda (ids de Downloads), la más reciente primero
    property var shownIds: []
    // Sus datos, en el mismo orden (se actualizan en su sitio: las filas no
    // se rehacen con cada avance). Roles: downloadId, fileName, downloadState,
    // received, total, error
    readonly property ListModel rows: ListModel {}
    property int runningCount: 0
    // Lo que sigue el botón de descargas (anillo de progreso): las que están
    // en curso, juntas ({ state, received, total }), o null
    property var item: null
    // Mientras es true, el botón de descargas está visible
    property bool active: false
    // Ya no queda ninguna en curso: cuenta atrás para cerrar panel y botón
    property bool ending: false

    // Abre el panel (botón de descargas). Si está terminando, vuelve a contar.
    function show() {
        open()
        if (ending)
            hold.restart()
    }

    function refresh() {
        const list = []
        for (const id of shownIds) {
            const row = Downloads.get(id)
            if (row)
                list.push(row)
        }
        // Las de la tanda que quitaron del listado ya no se siguen
        if (list.length !== shownIds.length)
            shownIds = list.map(row => row.id)
        const sameRows = rows.count === list.length
                         && list.every((row, i) => rows.get(i).downloadId === row.id)
        if (!sameRows)
            rows.clear()
        list.forEach((row, i) => {
            const data = { downloadId: row.id, fileName: row.fileName, downloadState: row.state,
                           received: row.received, total: row.total, error: row.error }
            if (sameRows)
                rows.set(i, data)
            else
                rows.append(data)
        })

        // Botón: progreso de las que siguen en curso, sumadas (el total solo
        // si se conoce el de todas); en pausa si lo están todas
        const running = list.filter(row => Downloads.isActive(row.state))
        runningCount = running.length
        if (running.length === 0) {
            item = null
        } else {
            const known = running.every(row => row.total > 0)
            item = {
                state: running.some(row => row.state === "progress") ? "progress" : "paused",
                received: running.reduce((sum, row) => sum + row.received, 0),
                total: known ? running.reduce((sum, row) => sum + row.total, 0) : -1
            }
        }
        if (list.length === 0 && active)
            expire()
    }

    // Fin de la cuenta atrás: se cierra el panel, se olvidan las terminadas
    // y, si no queda ninguna en curso, también el botón
    function expire() {
        hold.stop()
        ending = false
        close()
        shownIds = shownIds.filter(id => Downloads.isActive(Downloads.get(id)?.state ?? ""))
        refresh()
        active = shownIds.length > 0
    }

    Connections {
        target: Downloads
        function onStarted(id) {
            hold.stop()
            root.ending = false
            root.shownIds = [id].concat(root.shownIds.filter(other => other !== id))
            root.active = true
            root.refresh()
            root.open()
        }
        function onFinished(id) {
            if (!root.shownIds.includes(id))
                return
            root.refresh()
            // Se abre para que se vea cuál terminó; si era la última en
            // curso, empieza la cuenta atrás
            root.open()
            if (root.runningCount === 0) {
                root.ending = true
                hold.restart()
            }
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
        implicitHeight: header.height + Theme.spacing + list.height + 2 * Theme.margin

        HoverHandler {
            id: hover
            onHoveredChanged: if (!hovered && root.ending) hold.restart()
        }

        // Cuántas hay y cerrar
        Item {
            id: header
            x: Theme.margin
            y: Theme.margin
            width: parent.width - 2 * Theme.margin
            height: Theme.buttonSizeSmall

            Text {
                anchors.left: parent.left
                anchors.right: closeButton.left
                anchors.rightMargin: Theme.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: root.runningCount === 0
                      ? (root.rows.count === 1 ? "Descarga terminada" : "Descargas terminadas")
                      : root.runningCount === 1 ? "Descargando 1 archivo"
                      : "Descargando " + root.runningCount + " archivos"
                color: Colors.inkSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
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

        // Las descargas; con muchas, se desplaza
        ListView {
            id: list
            x: Theme.margin
            anchors.top: header.bottom
            anchors.topMargin: Theme.spacing
            width: parent.width - 2 * Theme.margin
            height: Math.min(contentHeight, Theme.downloadPanelMaxHeight)
            clip: contentHeight > height
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            spacing: Theme.margin
            model: root.rows

            delegate: DownloadRow {
                width: list.width
            }
        }
    }

    // Una descarga: nombre, progreso, estado y sus acciones
    component DownloadRow: Column {
        id: row

        required property int downloadId
        required property string fileName
        required property string downloadState
        required property real received
        required property real total
        required property string error
        readonly property bool downloading: Downloads.isActive(downloadState)
        readonly property bool knownTotal: total > 0

        spacing: Theme.spacing / 2

        // Icono de estado y nombre
        Row {
            width: parent.width
            spacing: Theme.spacing

            Icon {
                id: stateIcon
                anchors.verticalCenter: parent.verticalCenter
                name: row.downloadState === "done" ? "download-done"
                    : row.downloadState === "failed" ? "download-failed"
                    : row.downloadState === "canceled" ? "download-cancel" : "downloads"
                color: row.downloadState === "done" ? Colors.ok
                     : row.downloadState === "failed" ? Colors.danger
                     : row.downloadState === "progress" ? Colors.brandLight1 : Colors.inkMuted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - stateIcon.width - parent.spacing
                text: row.fileName
                color: Colors.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                // Por el medio: se conserva la extensión
                elide: Text.ElideMiddle
            }
        }

        ProgressBar {
            visible: row.downloading || row.downloadState === "done"
            width: parent.width
            value: row.downloadState === "done" ? 1
                 : row.knownTotal ? row.received / row.total : 0
            indeterminate: row.downloadState === "progress" && !row.knownTotal
        }

        // Estado y sus acciones: pausar/reanudar y cancelar en curso; abrir
        // la carpeta o el archivo al terminar
        Item {
            width: parent.width
            height: Theme.buttonSizeSmall

            Text {
                anchors.left: parent.left
                anchors.right: actions.left
                anchors.rightMargin: Theme.spacing
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                color: row.downloadState === "failed" ? Colors.danger
                     : row.downloadState === "done" ? Colors.ok : Colors.inkSecondary
                text: {
                    const size = row.knownTotal
                            ? Downloads.formatBytes(row.received) + " de " + Downloads.formatBytes(row.total)
                            : Downloads.formatBytes(row.received)
                    switch (row.downloadState) {
                    case "paused": return size + " · En pausa"
                    case "done": return "Completada · " + Downloads.formatBytes(row.received)
                    case "failed": return row.error ? "Error: " + row.error : "Error"
                    case "canceled": return "Cancelada"
                    default: return size
                    }
                }
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing / 2

                IconButton {
                    visible: row.downloading
                    width: Theme.buttonSizeSmall
                    height: Theme.buttonSizeSmall
                    flat: true
                    icon: row.downloadState === "paused" ? "play" : "pause"
                    iconSize: Theme.iconSizeSmall
                    tooltip: row.downloadState === "paused" ? "Reanudar" : "Pausar"
                    onClicked: row.downloadState === "paused" ? Downloads.resume(row.downloadId)
                                                              : Downloads.pause(row.downloadId)
                }
                IconButton {
                    visible: row.downloading
                    width: Theme.buttonSizeSmall
                    height: Theme.buttonSizeSmall
                    flat: true
                    danger: true
                    icon: "download-cancel"
                    iconSize: Theme.iconSizeSmall
                    tooltip: "Cancelar"
                    onClicked: Downloads.cancel(row.downloadId)
                }
                IconButton {
                    visible: row.downloadState === "done"
                    width: Theme.buttonSizeSmall
                    height: Theme.buttonSizeSmall
                    flat: true
                    icon: "folder"
                    iconSize: Theme.iconSizeSmall
                    tooltip: "Abrir carpeta"
                    onClicked: Downloads.openFolder(row.downloadId)
                }
                IconButton {
                    visible: row.downloadState === "done"
                    width: Theme.buttonSizeSmall
                    height: Theme.buttonSizeSmall
                    flat: true
                    icon: "open-file"
                    iconSize: Theme.iconSizeSmall
                    tooltip: "Abrir"
                    onClicked: Downloads.openFile(row.downloadId)
                }
            }
        }
    }
}

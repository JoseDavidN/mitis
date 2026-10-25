pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

// Listado de descargas (menú de opciones → Descargas): la más reciente
// arriba, con su progreso y acciones. Lee y actúa sobre el singleton Downloads.
Popup {
    id: root

    // Terminadas, fallidas o canceladas: las que quita «Limpiar»
    readonly property int finishedCount: Downloads.items.count - Downloads.activeCount
    // Hora de referencia de «hace 5 min»; se refresca con el listado abierto
    property real now: Date.now()

    // "3,2 MB de 10 MB", o solo lo recibido si no se sabe el total
    function sizes(received: real, total: real): string {
        return total > 0 ? Downloads.formatBytes(received) + " de " + Downloads.formatBytes(total)
                         : Downloads.formatBytes(received)
    }

    // "ahora mismo", "hace 5 min", "hace 2 h"; de otro día, la fecha y hora
    function when(ms: real): string {
        const minutes = Math.floor((now - ms) / 60000)
        if (minutes < 1)
            return "ahora mismo"
        if (minutes < 60)
            return "hace " + minutes + " min"
        const date = new Date(ms)
        const today = new Date(now)
        if (date.toDateString() === today.toDateString())
            return "hace " + Math.floor(minutes / 60) + " h"
        const time = date.toLocaleTimeString(Qt.locale("es_ES"), "HH:mm")
        today.setDate(today.getDate() - 1)
        if (date.toDateString() === today.toDateString())
            return "ayer, " + time
        return date.toLocaleDateString(Qt.locale("es_ES"), "d MMM") + ", " + time
    }

    // Línea secundaria de una fila según su estado
    function detail(state: string, received: real, total: real, error: string, finishedAt: real): string {
        switch (state) {
        case "progress": return sizes(received, total)
        case "paused": return "En pausa · " + sizes(received, total)
        case "done": return Downloads.formatBytes(total > 0 ? total : received) + " · " + when(finishedAt)
        case "failed": return "Error: " + (error !== "" ? error : "no se pudo descargar")
        default: return "Cancelada"
        }
    }

    width: Theme.popupWidth
    height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, Theme.popupMaxHeight)
    padding: Theme.spacing
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: PopupBackground {}

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast }
        NumberAnimation {
            property: "scale"; from: 0.96; to: 1; duration: Theme.durationBase
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationFast }
    }

    onAboutToShow: now = Date.now()

    Timer {
        interval: Theme.relativeTimeRefresh
        running: root.visible
        repeat: true
        onTriggered: root.now = Date.now()
    }

    contentItem: Column {
        id: column
        spacing: Theme.spacing / 2

        // Alto libre para la lista: el máximo menos cabecera, separador,
        // relleno y los dos huecos entre los tres bloques
        readonly property real listMaxHeight: Theme.popupMaxHeight - root.topPadding - root.bottomPadding
            - header.height - separator.height - 2 * spacing

        // Cabecera: título y «Limpiar»
        Item {
            id: header
            width: parent.width
            height: Theme.popupRowHeight

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.margin
                anchors.verticalCenter: parent.verticalCenter
                text: "Descargas"
                color: Colors.ink
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Font.DemiBold
            }

            Text {
                visible: root.finishedCount > 0
                anchors.right: parent.right
                anchors.rightMargin: Theme.margin
                anchors.verticalCenter: parent.verticalCenter
                text: "Limpiar"
                color: clearHover.hovered ? Colors.ink : Colors.inkSecondary
                font.pixelSize: Theme.fontSizeSmall
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                HoverHandler {
                    id: clearHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: Downloads.clearFinished()
                }
            }
        }

        Rectangle {
            id: separator
            width: parent.width
            height: 1
            color: Colors.hairline
        }

        Text {
            visible: Downloads.items.count === 0
            width: parent.width
            height: Theme.popupRowHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "Aún no hay descargas"
            color: Colors.inkMuted
            font.pixelSize: Theme.fontSize
        }

        ListView {
            id: list
            visible: count > 0
            width: parent.width
            height: Math.min(count * Theme.downloadRowHeight, column.listMaxHeight)
            clip: true
            model: Downloads.items
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row

                required property var model

                readonly property int downloadId: model.id
                readonly property string status: model.state
                readonly property bool active: Downloads.isActive(status)
                readonly property bool done: status === "done"
                readonly property bool hovered: rowHover.hovered

                width: ListView.view.width
                height: Theme.downloadRowHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: row.hovered ? Colors.tintHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Icon {
                    id: fileIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    name: "file"
                    color: row.done || row.active ? Colors.inkSoft : Colors.inkMuted
                }

                Column {
                    anchors.left: fileIcon.right
                    anchors.leftMargin: Theme.spacing
                    anchors.right: buttons.left
                    anchors.rightMargin: Theme.spacing / 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing / 2

                    Text {
                        width: parent.width
                        text: row.model.fileName
                        color: row.done || row.active ? Colors.ink : Colors.inkSecondary
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideMiddle
                    }

                    Text {
                        width: parent.width
                        text: root.detail(row.status, row.model.received, row.model.total,
                                          row.model.error, row.model.finishedAt)
                        color: row.status === "failed" ? Colors.danger : Colors.inkMuted
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    // Sin total conocido, un tramo recorre la pista (solo en curso)
                    ProgressBar {
                        visible: row.active
                        width: parent.width
                        indeterminate: row.model.total <= 0 && row.status === "progress"
                        value: row.model.total > 0 ? row.model.received / row.model.total : 0
                        opacity: row.status === "paused" ? 0.5 : 1
                    }
                }

                // Acciones: las de una descarga en curso se ven siempre; las
                // demás, al pasar por la fila
                Row {
                    id: buttons
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacing / 2
                    anchors.verticalCenter: parent.verticalCenter

                    IconButton {
                        visible: row.active
                        width: Theme.buttonSizeSmall
                        height: Theme.buttonSizeSmall
                        icon: row.status === "paused" ? "play" : "pause"
                        iconSize: Theme.iconSizeSmall
                        tooltip: row.status === "paused" ? "Reanudar" : "Pausar"
                        flat: true
                        onClicked: row.status === "paused" ? Downloads.resume(row.downloadId)
                                                           : Downloads.pause(row.downloadId)
                    }

                    IconButton {
                        visible: row.active
                        width: Theme.buttonSizeSmall
                        height: Theme.buttonSizeSmall
                        icon: "close"
                        iconSize: Theme.iconSizeSmall
                        tooltip: "Cancelar descarga"
                        flat: true
                        danger: true
                        onClicked: Downloads.cancel(row.downloadId)
                    }

                    IconButton {
                        visible: row.done
                        width: Theme.buttonSizeSmall
                        height: Theme.buttonSizeSmall
                        icon: "open-file"
                        iconSize: Theme.iconSizeSmall
                        tooltip: "Abrir"
                        flat: true
                        opacity: row.hovered ? 1 : 0
                        onClicked: {
                            Downloads.openFile(row.downloadId)
                            root.close()
                        }
                    }

                    IconButton {
                        visible: row.done
                        width: Theme.buttonSizeSmall
                        height: Theme.buttonSizeSmall
                        icon: "folder"
                        iconSize: Theme.iconSizeSmall
                        tooltip: "Mostrar en la carpeta"
                        flat: true
                        opacity: row.hovered ? 1 : 0
                        onClicked: {
                            Downloads.openFolder(row.downloadId)
                            root.close()
                        }
                    }

                    IconButton {
                        visible: !row.active
                        width: Theme.buttonSizeSmall
                        height: Theme.buttonSizeSmall
                        icon: "close"
                        iconSize: Theme.iconSizeSmall
                        tooltip: "Quitar del listado"
                        flat: true
                        opacity: row.hovered ? 1 : 0
                        onClicked: Downloads.remove(row.downloadId)
                    }
                }

                HoverHandler {
                    id: rowHover
                    cursorShape: row.done ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                // Clic en una terminada: abrir el archivo
                TapHandler {
                    enabled: row.done
                    // Agarre exclusivo: si no, lo que hay debajo recibe también el clic
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        Downloads.openFile(row.downloadId)
                        root.close()
                    }
                }
            }
        }
    }
}

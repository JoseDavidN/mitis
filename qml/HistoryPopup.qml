pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

// Historial (menú de opciones → Historial): reabrir la última pestaña
// cerrada, las páginas visitadas más recientes y el acceso a Configuración
// (buscar más atrás y borrar datos). Lee y actúa sobre el singleton History.
Popup {
    id: root

    // Pestañas cerradas que se pueden reabrir (de esta ventana)
    property int closedCount: 0
    // Visitadas más recientes; se leen al abrir y tras cada cambio
    property var entries: []
    readonly property int entriesMax: 30
    // Hora de referencia de «hace 5 min»
    property real now: Date.now()

    signal openRequested(string url)
    signal reopenRequested()
    signal settingsRequested()

    function refresh() {
        entries = History.recent(entriesMax)
    }

    // "hace 5 min", "hace 2 h"; de otro día, "ayer, 18:20" o "3 oct, 18:20"
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

    onAboutToShow: {
        now = Date.now()
        refresh()
    }

    Connections {
        target: History
        enabled: root.visible
        function onChanged() { root.refresh() }
    }

    Timer {
        interval: Theme.relativeTimeRefresh
        running: root.visible
        repeat: true
        onTriggered: root.now = Date.now()
    }

    contentItem: Column {
        id: column
        spacing: Theme.spacing / 2

        readonly property real listMaxHeight: Theme.popupMaxHeight - root.topPadding - root.bottomPadding
            - header.height - reopen.height - settings.height - 2 * separatorTop.height - 5 * spacing

        Item {
            id: header
            width: parent.width
            height: Theme.popupRowHeight

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.margin
                anchors.verticalCenter: parent.verticalCenter
                text: "Historial"
                color: Theme.ink
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Font.DemiBold
            }
        }

        PopupAction {
            id: reopen
            width: parent.width
            enabled: root.closedCount > 0
            icon: "reopen"
            text: "Reabrir la última pestaña cerrada"
            shortcut: "Ctrl+Shift+T"
            onTriggered: {
                root.reopenRequested()
                root.close()
            }
        }

        Rectangle {
            id: separatorTop
            width: parent.width
            height: 1
            color: Theme.hairline
        }

        Text {
            visible: root.entries.length === 0
            width: parent.width
            height: Theme.popupRowHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "Aún no hay historial"
            color: Theme.inkMuted
            font.pixelSize: Theme.fontSize
        }

        ListView {
            id: list
            visible: count > 0
            width: parent.width
            height: Math.min(count * Theme.pageRowHeight, column.listMaxHeight)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.entries

            delegate: PageRow {
                required property var modelData

                width: ListView.view.width
                url: modelData.url
                title: modelData.title
                detail: modelData.url.replace(/^https?:\/\/(www\.)?/, "").split("/")[0]
                        + " · " + root.when(modelData.lastVisit)
                removeTooltip: "Quitar del historial"
                onClicked: {
                    root.openRequested(modelData.url)
                    root.close()
                }
                onRemoveRequested: History.remove(modelData.url)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hairline
        }

        PopupAction {
            id: settings
            width: parent.width
            icon: "settings"
            text: "Historial en Configuración"
            onTriggered: {
                root.settingsRequested()
                root.close()
            }
        }
    }
}

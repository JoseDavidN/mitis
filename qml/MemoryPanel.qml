pragma ComponentBehavior: Bound
import QtQuick

// Panel de memoria (desarrollo; Shift+Esc u Opciones → Uso de memoria):
// cuánta RAM usa Mitis en total, por tipo de proceso y por pestaña. Flota
// arriba a la izquierda y no se cierra al usar la página. Solo muestra: las
// medidas las pone quien lo abre en `sample`, cada `Theme.memoryPanelRefresh`
// mientras está abierto (ver refreshRequested).
Item {
    id: root

    // { total, processCount, groups: [{ label, bytes }],
    //   tabs: [{ url, title, bytes, detail }] } (una por pestaña, en orden)
    property var sample: null
    property bool shown: false

    signal refreshRequested()
    signal tabSelected(int index)
    signal closeRequested()

    implicitWidth: Theme.memoryPanelWidth
    implicitHeight: content.implicitHeight + 2 * Theme.spacing

    visible: opacity > 0
    opacity: shown ? 1 : 0
    transform: Translate { y: root.shown ? 0 : -Theme.spacing }
    Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

    Timer {
        interval: Theme.memoryPanelRefresh
        repeat: true
        triggeredOnStart: true
        running: root.shown
        onTriggered: root.refreshRequested()
    }

    // Las filas de las pestañas se actualizan en su sitio: recrearlas en cada
    // medición volvería a pedir los favicons
    ListModel {
        id: tabRows
    }
    onSampleChanged: {
        const list = sample ? sample.tabs : []
        for (let i = 0; i < list.length; i++) {
            if (i < tabRows.count)
                tabRows.set(i, list[i])
            else
                tabRows.append(list[i])
        }
        if (tabRows.count > list.length)
            tabRows.remove(list.length, tabRows.count - list.length)
    }

    // 123 MB, 1,2 GB
    function formatBytes(bytes) {
        const mb = bytes / (1024 * 1024)
        if (mb >= 1024)
            return (mb / 1024).toFixed(1).replace(".", ",") + " GB"
        return Math.round(mb) + " MB"
    }

    PopupBackground {
        anchors.fill: parent
    }

    Column {
        id: content
        x: Theme.spacing
        y: Theme.spacing
        width: parent.width - 2 * Theme.spacing

        // Cabecera: icono, título, total y cerrar
        Item {
            width: parent.width
            height: Theme.popupRowHeight

            Icon {
                id: headerIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.margin
                anchors.verticalCenter: parent.verticalCenter
                name: "memory"
                color: Theme.brandLight1
            }
            Text {
                anchors.left: headerIcon.right
                anchors.leftMargin: Theme.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: "Memoria"
                color: Theme.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.Bold
            }
            Text {
                anchors.right: closeButton.left
                anchors.rightMargin: Theme.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: root.sample ? root.formatBytes(root.sample.total) : "…"
                color: Theme.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.Bold
            }
            IconButton {
                id: closeButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing / 2
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.buttonSizeSmall
                height: Theme.buttonSizeSmall
                flat: true
                icon: "close"
                iconSize: Theme.iconSizeSmall
                tooltip: "Cerrar"
                shortcut: "Shift+Esc"
                tooltipBelow: true
                onClicked: root.closeRequested()
            }
        }

        Text {
            x: Theme.margin
            width: parent.width - 2 * Theme.margin
            bottomPadding: Theme.spacing
            text: root.sample ? root.sample.processCount + " procesos · se mide cada "
                                + Theme.memoryPanelRefresh / 1000 + " s" : ""
            color: Theme.inkMuted
            font.pixelSize: Theme.fontSizeSmall
        }

        // Por tipo de proceso
        Repeater {
            model: root.sample ? root.sample.groups : []

            delegate: Item {
                id: group

                required property var modelData

                width: parent.width
                height: Theme.popupRowHeight - Theme.spacing

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.margin
                    anchors.right: groupValue.left
                    anchors.rightMargin: Theme.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: group.modelData.label
                    color: Theme.inkSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
                Text {
                    id: groupValue
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.formatBytes(group.modelData.bytes)
                    color: Theme.inkSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                }
            }
        }

        Item {
            width: parent.width
            height: Theme.spacing + 1

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.margin
                anchors.rightMargin: Theme.margin
                height: 1
                color: Theme.line
            }
        }

        Text {
            x: Theme.margin
            topPadding: Theme.spacing
            bottomPadding: Theme.spacing / 2
            text: "Pestañas de esta ventana"
            color: Theme.inkMuted
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
        }

        ListView {
            id: tabList
            width: parent.width
            height: Math.min(contentHeight, Theme.popupMaxHeight - Theme.settingsRowHeight * 3)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: tabRows

            delegate: PageRow {
                required property int index
                required url
                required title
                required detail
                required property real bytes

                width: tabList.width
                removable: false
                value: bytes > 0 ? root.formatBytes(bytes) : "—"
                onClicked: root.tabSelected(index)
            }
        }
    }
}

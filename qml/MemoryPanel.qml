pragma ComponentBehavior: Bound
import QtQuick

// Monitor de rendimiento (Configuración → Desarrollo; Shift+Esc u Opciones →
// Monitor de rendimiento): memoria, CPU y GPU de Mitis en total, por tipo de
// proceso y por pestaña, con una gráfica de lo último medido. Flota arriba a
// la izquierda y no se cierra al usar la página. Solo muestra: las medidas
// las pone quien lo abre en `sample`, cada `Theme.memoryPanelRefresh`
// mientras se ve (ver refreshRequested).
Item {
    id: root

    // { total, cpu, processCount, gpu: { usage, memory, systemUsage, vramUsed, vramTotal },
    //   groups: [{ label, bytes, cpu }],
    //   tabs: [{ url, title, bytes, cpu, detail }] } (una por pestaña, en orden).
    // CPU y GPU: -1 = sin dato (la CPU lo está en la primera medición)
    property var sample: null
    property bool shown: false

    // Últimas medidas, la más reciente al final (Theme.performanceHistoryLength)
    property var cpuHistory: []
    property var memoryHistory: []

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
    // Oculto no se mide: al volver, se empieza de cero
    onShownChanged: {
        if (!shown)
            sample = null
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

        if (!sample) {
            cpuHistory = []
            memoryHistory = []
            return
        }
        const keep = Theme.performanceHistoryLength - 1
        if (sample.cpu >= 0)
            cpuHistory = cpuHistory.slice(-keep).concat([sample.cpu])
        memoryHistory = memoryHistory.slice(-keep).concat([sample.total])
    }

    // 123 MB, 1,2 GB
    function formatBytes(bytes) {
        const mb = bytes / (1024 * 1024)
        if (mb >= 1024)
            return (mb / 1024).toFixed(1).replace(".", ",") + " GB"
        return Math.round(mb) + " MB"
    }
    // 0,4 %, 12 %
    function formatPercent(value) {
        if (value < 10)
            return value.toFixed(1).replace(".", ",") + " %"
        return Math.round(value) + " %"
    }
    // «3 % · 120 MB», o solo la memoria sin dato de CPU
    function formatUsage(cpu, bytes) {
        return (cpu >= 0 ? formatPercent(cpu) + " · " : "") + formatBytes(bytes)
    }

    // Filas de la GPU: la de Mitis y, si el sistema lo dice, la de todo el equipo
    readonly property var gpuRows: {
        const gpu = sample ? sample.gpu : null
        if (!gpu)
            return []
        const own = []
        if (gpu.usage >= 0)
            own.push(formatPercent(gpu.usage))
        if (gpu.memory >= 0)
            own.push(formatBytes(gpu.memory))
        const system = []
        if (gpu.systemUsage >= 0)
            system.push(formatPercent(gpu.systemUsage))
        if (gpu.vramTotal > 0)
            system.push(formatBytes(Math.max(gpu.vramUsed, 0)) + " de " + formatBytes(gpu.vramTotal))
        if (own.length === 0 && system.length === 0)
            return [{ label: "GPU", value: "No disponible" }]
        const rows = [{ label: "GPU de Mitis", value: own.length > 0 ? own.join(" · ") : "No disponible" }]
        if (system.length > 0)
            rows.push({ label: "GPU del sistema", value: system.join(" · ") })
        return rows
    }

    // Una cifra con su nombre encima de la gráfica de su historial
    component ChartCell: Column {
        id: cell

        property string label
        property string value
        property var values: []
        property real maximum: 1
        property color color

        spacing: Theme.spacing / 2

        Item {
            width: cell.width
            height: cellValue.implicitHeight

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: cell.label
                color: Theme.inkSecondary
                font.pixelSize: Theme.fontSizeSmall
            }
            Text {
                id: cellValue
                anchors.right: parent.right
                text: cell.value
                color: Theme.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.Bold
            }
        }
        Canvas {
            id: chart
            width: cell.width
            height: Theme.performanceChartHeight

            Connections {
                target: cell
                function onValuesChanged() { chart.requestPaint() }
                function onColorChanged() { chart.requestPaint() }
            }
            onWidthChanged: requestPaint()

            // La más reciente en el borde derecho; la base, la línea `line`
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const line = Theme.performanceChartLineWidth
                ctx.fillStyle = Theme.line
                ctx.fillRect(0, height - 1, width, 1)
                const values = cell.values
                if (values.length < 2)
                    return
                const step = width / (Theme.performanceHistoryLength - 1)
                const top = line
                const usable = height - 1 - top
                const xAt = i => width - (values.length - 1 - i) * step
                const yAt = v => height - 1 - usable * Math.min(v / cell.maximum, 1)
                ctx.beginPath()
                ctx.moveTo(xAt(0), yAt(values[0]))
                for (let i = 1; i < values.length; i++)
                    ctx.lineTo(xAt(i), yAt(values[i]))
                ctx.strokeStyle = cell.color
                ctx.lineWidth = line
                ctx.lineJoin = "round"
                ctx.stroke()
                ctx.lineTo(width, height - 1)
                ctx.lineTo(xAt(0), height - 1)
                ctx.closePath()
                ctx.globalAlpha = Theme.performanceChartFillOpacity
                ctx.fillStyle = cell.color
                ctx.fill()
            }
        }
    }

    PopupBackground {
        anchors.fill: parent
    }

    Column {
        id: content
        x: Theme.spacing
        y: Theme.spacing
        width: parent.width - 2 * Theme.spacing

        // Cabecera: icono, título y cerrar
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
                text: "Rendimiento"
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

        // Totales de Mitis con su historial: CPU (0–100 %, con un mínimo de
        // escala para que el reposo no parezca un pico) y memoria (hasta su máximo)
        Row {
            x: Theme.margin
            width: parent.width - 2 * Theme.margin
            spacing: Theme.margin
            bottomPadding: Theme.spacing

            ChartCell {
                width: (parent.width - parent.spacing) / 2
                label: "CPU"
                value: root.sample && root.sample.cpu >= 0 ? root.formatPercent(root.sample.cpu) : "…"
                values: root.cpuHistory
                maximum: Math.min(100, Math.max(10, ...root.cpuHistory) * 1.2)
                color: Theme.performanceCpu
            }
            ChartCell {
                width: (parent.width - parent.spacing) / 2
                label: "Memoria"
                value: root.sample ? root.formatBytes(root.sample.total) : "…"
                values: root.memoryHistory
                maximum: Math.max(1, ...root.memoryHistory) * 1.2
                color: Theme.performanceMemory
            }
        }

        // Por tipo de proceso y la GPU
        Repeater {
            model: root.sample ? root.sample.groups.map(group => ({
                label: group.label, value: root.formatUsage(group.cpu, group.bytes)
            })).concat(root.gpuRows) : []

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
                    text: group.modelData.value
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
                required property real cpu

                width: tabList.width
                removable: false
                value: bytes > 0 ? root.formatUsage(cpu, bytes) : "—"
                onClicked: root.tabSelected(index)
            }
        }
    }
}

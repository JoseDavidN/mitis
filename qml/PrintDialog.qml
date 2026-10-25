pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs
import QtQuick.Pdf
import Mitis.Core

// Imprimir y guardar como PDF (Ctrl+P, Opciones, menú contextual o la página
// con window.print()): ventana propia de Mitis sobre la página de su
// pestaña, como PageDialog. A la izquierda, la vista previa de las hojas
// (el PDF que hace el motor, BrowserTab.printToPdf); a la derecha, el
// destino (impresoras del sistema o «Guardar como PDF») y las opciones.
// Cada cambio de diseño vuelve a pedir el PDF. Imprimir y guardar lo hace
// el singleton Printing (C++).
FocusScope {
    id: root

    // Pestaña que se imprime
    property BrowserTab page: null

    readonly property bool shown: _shown
    property bool _shown: false

    // Opciones (se recuerdan mientras la pestaña está abierta)
    // Destino: "" = guardar como PDF; si no, el nombre de la impresora
    property string destination: ""
    property bool _destinationChosen: false
    property bool landscape: false
    // "a4", "letter" o "legal"
    property string paper: "a4"
    property bool backgrounds: false
    property int copies: 1
    property bool color: true

    // Estado
    property url _previewUrl: ""
    property bool _rendering: false
    property bool _printing: false
    property int _job: 0
    property string _error: ""
    readonly property bool _toPrinter: destination !== ""

    // Se cerró (impreso, guardado o cancelado)
    signal finished()

    function open() {
        if (!root.page)
            return
        Printing.refreshPrinters()
        // La primera vez, la impresora predeterminada (o PDF si no hay); si la
        // elegida ya no está, PDF
        if (!root._destinationChosen)
            root.destination = Printing.defaultPrinter
        if (root.destination !== "" && Printing.printers.indexOf(root.destination) < 0)
            root.destination = ""
        root._error = ""
        root._shown = true
        root.forceActiveFocus()
        root._render()
    }
    function close() {
        if (!root._shown || root._printing)
            return
        root._shown = false
        root._job++
        root._previewUrl = ""
        Printing.clear()
        root.finished()
    }

    function _render() {
        root._rendering = true
        const job = ++root._job
        root.page.printToPdf(data => {
            if (job !== root._job || !root._shown)
                return
            root._previewUrl = Printing.setDocument(data)
            root._rendering = false
            if (root._previewUrl.toString() === "")
                root._error = "No se pudo preparar la página."
        }, root.landscape, root.paper, root.backgrounds)
    }
    // Varios cambios seguidos: un solo PDF
    Timer {
        id: renderLater
        interval: Theme.durationFast
        onTriggered: if (root._shown) root._render()
    }
    onLandscapeChanged: renderLater.restart()
    onPaperChanged: renderLater.restart()
    onBackgroundsChanged: renderLater.restart()

    function accept() {
        if (root._rendering || root._printing || root._previewUrl.toString() === "")
            return
        root._error = ""
        if (root._toPrinter) {
            root._printing = true
            Printing.print(root.destination, root.copies, root.color, root.page.title)
        } else {
            // Nombre propuesto: el título de la página, sin lo que no admiten
            // los sistemas de archivos
            const name = (root.page.title || "pagina").replace(/[\\/:*?"<>|]+/g, " ").trim().slice(0, 120) || "pagina"
            saveDialog.currentFolder = Printing.saveFolder()
            saveDialog.selectedFile = saveDialog.currentFolder + "/" + name + ".pdf"
            saveDialog.open()
        }
    }

    Connections {
        target: Printing
        function onPrintFinished(error) {
            if (!root._printing)
                return
            root._printing = false
            if (error === "")
                root.close()
            else
                root._error = error
        }
    }

    FileDialog {
        id: saveDialog
        title: "Guardar como PDF"
        fileMode: FileDialog.SaveFile
        nameFilters: ["PDF (*.pdf)"]
        defaultSuffix: "pdf"
        onAccepted: {
            if (Printing.saveDocument(selectedFile))
                root.close()
            else
                root._error = "No se pudo guardar el PDF ahí. Prueba en otra carpeta."
        }
    }

    anchors.fill: parent
    z: 10
    visible: opacity > 0
    opacity: _shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

    onVisibleChanged: if (visible && _shown) root.forceActiveFocus()

    Keys.onEscapePressed: root.close()
    Keys.onReturnPressed: root.accept()
    Keys.onEnterPressed: root.accept()

    // Velo: tapa la página para que no reciba clics, rueda ni hover
    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundScrim
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    PopupBackground {
        id: card
        anchors.centerIn: parent
        width: Math.min(Theme.printDialogWidth, root.width - 2 * Theme.margin)
        height: Math.min(Theme.printDialogHeight, root.height - 2 * Theme.margin)
        scale: root._shown ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: Theme.durationBase; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

        // ── Vista previa ─────────────────────────────────────────────
        Rectangle {
            id: previewArea
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: options.left
            anchors.margins: Theme.spacing
            radius: Theme.radius
            color: Theme.tintHover
            clip: true

            // Solo con un PDF que mostrar: al cerrar se suelta (y su memoria)
            Loader {
                id: preview
                anchors.fill: parent
                active: root._previewUrl.toString() !== ""
                readonly property int pageCount: item ? (item as ListView).count : 0

                sourceComponent: ListView {
                    id: pages
                    anchors.fill: parent
                    anchors.margins: Theme.margin
                    spacing: Theme.margin
                    model: document.status === PdfDocument.Ready ? document.pageCount : 0
                    boundsBehavior: Flickable.StopAtBounds
                    opacity: root._rendering ? 0.4 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                    PdfDocument {
                        id: document
                        source: root._previewUrl
                    }

                    delegate: Item {
                        id: pageItem
                        required property int index
                        readonly property size points: document.pagePointSize(index)
                        width: ListView.view.width
                        height: points.width > 0 ? Math.round(width * points.height / points.width) : width

                        // La hoja, siempre blanca como el papel
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.printPaper
                        }
                        PdfPageImage {
                            anchors.fill: parent
                            document: document
                            currentFrame: pageItem.index
                            sourceSize.width: pageItem.width * Screen.devicePixelRatio
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root._rendering && preview.pageCount === 0
                text: "Preparando la vista previa…"
                color: Theme.inkSecondary
                font.pixelSize: Theme.fontSize
            }
        }

        // ── Opciones ─────────────────────────────────────────────────
        Item {
            id: options
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Theme.printOptionsWidth

            Row {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.margin + Theme.spacing
                spacing: Theme.spacing

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "print"
                    color: Theme.brandLight1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Imprimir"
                    color: Theme.ink
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: preview.pageCount > 0
                    text: preview.pageCount === 1 ? "1 hoja" : preview.pageCount + " hojas"
                    color: Theme.inkMuted
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Flickable {
                id: optionsScroll
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.bottom: footer.top
                anchors.topMargin: Theme.spacing
                anchors.leftMargin: Theme.margin
                anchors.rightMargin: Theme.margin
                contentHeight: optionsColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: optionsColumn
                    width: parent.width
                    spacing: Theme.spacing / 2

                    SectionLabel { text: "Destino" }
                    ChoiceLine {
                        label: "Guardar como PDF"
                        checked: root.destination === ""
                        onPicked: {
                            root.destination = ""
                            root._destinationChosen = true
                        }
                    }
                    Repeater {
                        model: Printing.printers
                        delegate: ChoiceLine {
                            required property string modelData
                            label: modelData === Printing.defaultPrinter ? modelData + " (predeterminada)" : modelData
                            checked: root.destination === modelData
                            onPicked: {
                                root.destination = modelData
                                root._destinationChosen = true
                            }
                        }
                    }

                    SectionLabel { text: "Copias"; visible: root._toPrinter }
                    Row {
                        visible: root._toPrinter
                        spacing: Theme.spacing
                        leftPadding: Theme.spacing

                        IconButton {
                            width: Theme.buttonSizeSmall
                            height: Theme.buttonSizeSmall
                            flat: true
                            glyph: "−"
                            tooltip: "Menos copias"
                            enabled: root.copies > 1
                            onClicked: root.copies--
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.zoomLabelWidth
                            horizontalAlignment: Text.AlignHCenter
                            text: root.copies
                            color: Theme.ink
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.DemiBold
                        }
                        IconButton {
                            width: Theme.buttonSizeSmall
                            height: Theme.buttonSizeSmall
                            flat: true
                            glyph: "+"
                            tooltip: "Más copias"
                            enabled: root.copies < Theme.printMaxCopies
                            onClicked: root.copies++
                        }
                    }
                    ToggleLine {
                        visible: root._toPrinter
                        label: "En color"
                        checked: root.color
                        onToggled: value => root.color = value
                    }

                    SectionLabel { text: "Orientación" }
                    ChoiceLine {
                        label: "Vertical"
                        checked: !root.landscape
                        onPicked: root.landscape = false
                    }
                    ChoiceLine {
                        label: "Horizontal"
                        checked: root.landscape
                        onPicked: root.landscape = true
                    }

                    SectionLabel { text: "Tamaño del papel" }
                    ChoiceLine {
                        label: "A4"
                        checked: root.paper === "a4"
                        onPicked: root.paper = "a4"
                    }
                    ChoiceLine {
                        label: "Carta"
                        checked: root.paper === "letter"
                        onPicked: root.paper = "letter"
                    }
                    ChoiceLine {
                        label: "Oficio"
                        checked: root.paper === "legal"
                        onPicked: root.paper = "legal"
                    }

                    SectionLabel { text: "Opciones" }
                    ToggleLine {
                        label: "Colores e imágenes de fondo"
                        checked: root.backgrounds
                        onToggled: value => root.backgrounds = value
                    }
                }
            }

            Column {
                id: footer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.margin + Theme.spacing
                spacing: Theme.spacing

                Text {
                    width: parent.width
                    visible: root._error !== "" || root._printing
                    text: root._printing ? "Enviando a la impresora…" : root._error
                    color: root._printing ? Theme.inkSecondary : Theme.danger
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                }
                Row {
                    anchors.right: parent.right
                    spacing: Theme.spacing

                    TextButton {
                        text: "Cancelar"
                        enabled: !root._printing
                        onClicked: root.close()
                    }
                    TextButton {
                        text: root._toPrinter ? "Imprimir" : "Guardar"
                        primary: true
                        enabled: !root._rendering && !root._printing && preview.pageCount > 0
                        onClicked: root.accept()
                    }
                }
            }
        }
    }

    component SectionLabel: Text {
        topPadding: Theme.spacing
        bottomPadding: Theme.spacing / 2
        leftPadding: Theme.spacing
        color: Theme.inkSecondary
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
    }

    // Fila de elección única: círculo y texto; toda la fila es pulsable
    component ChoiceLine: Item {
        id: line
        property string label: ""
        property bool checked: false
        signal picked()

        width: parent ? parent.width : 0
        height: Theme.printRowHeight

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: lineHover.hovered ? Theme.tintHover : "transparent"
        }
        RadioMark {
            id: mark
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            checked: line.checked
            hovered: lineHover.hovered
        }
        Text {
            anchors.left: mark.right
            anchors.leftMargin: Theme.spacing
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: line.label
            color: Theme.ink
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
        HoverHandler {
            id: lineHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: line.picked()
        }
    }

    // Fila con interruptor: texto a la izquierda, Toggle a la derecha
    component ToggleLine: Item {
        id: toggleLine
        property string label: ""
        property bool checked: false
        signal toggled(bool value)

        width: parent ? parent.width : 0
        height: Theme.printRowHeight

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing
            anchors.right: toggle.left
            anchors.rightMargin: Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: toggleLine.label
            color: Theme.ink
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
        Toggle {
            id: toggle
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            checked: toggleLine.checked
            onToggled: toggleLine.toggled(checked)
        }
    }
}

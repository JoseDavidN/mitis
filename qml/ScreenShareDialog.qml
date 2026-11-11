pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

// ¿Qué compartir? (BrowserTab.screenShareRequested): una página pide ver tu
// pantalla (Meet, Teams, Discord…), ya con el permiso concedido. Lista las
// pantallas y ventanas que da el motor (se llenan poco a poco) o, en Wayland
// con la captura propia de Mitis, las suyas (listas { name, detail }).
// En un Loader del delegado de Main.qml: solo existe abierta.
PageDialog {
    id: root

    // { site, screens, windows, selectScreen(i), selectWindow(i), cancel() }
    required property var request

    // Se respondió (compartiendo o no)
    signal finished()

    // Lo elegido: "screen" o "window" y su fila
    property string _kind: ""
    property int _index: -1
    property bool _answered: false
    // La petición de cuando se abrió, sin enlazar: si llega otra, este
    // diálogo se destruye y debe cancelar la suya, no la nueva
    property var _own: null

    function _answer(share) {
        if (_answered)
            return
        _answered = true
        if (share && _kind === "screen")
            _own.selectScreen(_index)
        else if (share && _kind === "window")
            _own.selectWindow(_index)
        else
            _own.cancel()
        root.hide()
        root.finished()
    }

    iconName: "screen"
    title: "Compartir pantalla"
    message: (request.site !== "" ? request.site : "Esta página")
             + " quiere ver tu pantalla o una ventana. Elige qué compartir."
    cardWidth: Theme.screenShareWidth

    Component.onCompleted: {
        _own = request
        show()
    }
    // Cerrado sin responder (la pestaña se cierra, llega otra): que la página no espere
    Component.onDestruction: if (!_answered && _own) _own.cancel()

    onAccepted: if (_index >= 0) _answer(true)
    onRejected: _answer(false)

    Flickable {
        id: list
        width: parent.width
        height: Math.min(contentHeight, Theme.screenShareListHeight)
        contentHeight: sources.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: list.contentHeight > list.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        Column {
            id: sources
            width: list.width - (list.contentHeight > list.height ? Theme.spacing : 0)

            SourceGroup {
                title: "Pantallas"
                kind: "screen"
                chosenKind: root._kind
                chosenIndex: root._index
                onPicked: (index, share) => {
                    root._kind = "screen"
                    root._index = index
                    if (share)
                        root._answer(true)
                }
                model: root.request.screens
                fallback: "Pantalla"
            }
            SourceGroup {
                title: "Ventanas"
                kind: "window"
                chosenKind: root._kind
                chosenIndex: root._index
                onPicked: (index, share) => {
                    root._kind = "window"
                    root._index = index
                    if (share)
                        root._answer(true)
                }
                model: root.request.windows
                fallback: "Ventana"
            }
            Text {
                width: parent.width
                visible: screensCount.count === 0 && windowsCount.count === 0
                text: "Buscando pantallas y ventanas…"
                color: Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                topPadding: Theme.spacing
            }
            // Solo para saber si las listas ya tienen algo (se llenan después)
            Repeater { id: screensCount; model: root.request.screens; delegate: Item {} }
            Repeater { id: windowsCount; model: root.request.windows; delegate: Item {} }
        }
    }

    buttons: [
        TextButton {
            text: "Cancelar"
            onClicked: root._answer(false)
        },
        TextButton {
            text: "Compartir"
            primary: true
            enabled: root._index >= 0
            onClicked: root._answer(true)
        }
    ]

    // Título y filas de una lista (pantallas o ventanas); oculta si está vacía
    component SourceGroup: Column {
        id: group

        required property string title
        required property string kind
        required property var model
        // Nombre si el sistema no da ninguno
        required property string fallback
        // Lo elegido en el diálogo (las inline components no ven sus ids)
        property string chosenKind: ""
        property int chosenIndex: -1

        // Fila pulsada; `share` con doble clic: compartir ya
        signal picked(int index, bool share)

        width: parent.width
        visible: rows.count > 0

        Text {
            width: parent.width
            text: group.title
            color: Colors.inkMuted
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            topPadding: Theme.spacing
            bottomPadding: Theme.spacing / 2
        }
        Repeater {
            id: rows
            model: group.model
            delegate: Item {
                id: row

                required property int index
                required property var model
                readonly property bool chosen: group.chosenKind === group.kind && group.chosenIndex === index

                width: group.width
                height: Theme.popupRowHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: rowHover.hovered ? Colors.tintHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
                RadioMark {
                    id: mark
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    checked: row.chosen
                    hovered: rowHover.hovered
                }
                // Listas propias (captura de Mitis en Wayland): { name, detail };
                // las del motor son modelos con el rol `display`
                readonly property var own: typeof row.model.modelData?.name === "string" ? row.model.modelData : null
                Text {
                    id: detail
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, row.width / 3)
                    visible: text !== ""
                    text: row.own?.detail ?? ""
                    color: Colors.inkMuted
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                Text {
                    anchors.left: mark.right
                    anchors.leftMargin: Theme.spacing
                    anchors.right: detail.visible ? detail.left : parent.right
                    anchors.rightMargin: Theme.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.own ? row.own.name
                          : row.model.display ? row.model.display
                          : group.fallback + (rows.count > 1 ? " " + (row.index + 1) : "")
                    color: Colors.ink
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                HoverHandler {
                    id: rowHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: group.picked(row.index, false)
                    onDoubleTapped: group.picked(row.index, true)
                }
            }
        }
    }
}

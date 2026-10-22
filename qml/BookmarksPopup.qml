pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

// Lista de marcadores (botón de marcadores): guardar o quitar la página
// actual (Ctrl+D), buscar entre ellos, abrir y quitar. Lee y actúa sobre el
// singleton Bookmarks.
Popup {
    id: root

    // Página de la pestaña activa
    property string pageUrl: ""
    property string pageTitle: ""
    // Solo las páginas web se guardan (no la nueva pestaña)
    readonly property bool canBookmark: /^https?:\/\//.test(pageUrl)
    readonly property bool bookmarked: Bookmarks.urls.indexOf(pageUrl) >= 0

    signal openRequested(string url)

    function toggleCurrent() {
        if (!canBookmark)
            return
        if (bookmarked)
            Bookmarks.remove(pageUrl)
        else
            Bookmarks.add(pageUrl, pageTitle)
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

    onAboutToShow: filter.text = ""
    onOpened: if (Bookmarks.items.length > 0) filter.forceActiveFocus()

    contentItem: Column {
        id: column
        spacing: Theme.spacing / 2

        readonly property real listMaxHeight: Theme.popupMaxHeight - root.topPadding - root.bottomPadding
            - toggle.height - separator.height - (filter.visible ? filter.height + spacing : 0) - 3 * spacing

        PopupAction {
            id: toggle
            width: parent.width
            enabled: root.canBookmark
            icon: root.bookmarked ? "bookmark" : "bookmark-add"
            text: root.bookmarked ? "Quitar esta página" : "Añadir esta página"
            shortcut: "Ctrl+D"
            onTriggered: root.toggleCurrent()
        }

        Rectangle {
            id: separator
            width: parent.width
            height: 1
            color: Theme.hairline
        }

        FormField {
            id: filter
            visible: Bookmarks.items.length > 0
            width: parent.width
            placeholderText: "Buscar en marcadores"
            Keys.onEscapePressed: root.close()
        }

        Text {
            visible: list.count === 0
            width: parent.width
            height: Theme.popupRowHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: Bookmarks.items.length === 0 ? "Aún no hay marcadores" : "Ningún marcador coincide"
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
            // Se recalcula al cambiar los marcadores o el texto buscado
            model: filter.text.trim() === "" ? Bookmarks.items : Bookmarks.search(filter.text)

            delegate: PageRow {
                required property var modelData

                width: ListView.view.width
                url: modelData.url
                title: modelData.title
                removeTooltip: "Quitar de marcadores"
                onClicked: {
                    root.openRequested(modelData.url)
                    root.close()
                }
                onRemoveRequested: Bookmarks.remove(modelData.url)
            }
        }
    }
}

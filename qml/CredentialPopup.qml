pragma ComponentBehavior: Bound
import QtQuick
import Mitis.Core

// Lista bajo un campo de usuario o contraseña de una página (gestor de
// contraseñas): las guardadas del sitio para rellenarlas, desbloquear el
// gestor si está bloqueado o, en un registro, una contraseña segura generada.
// Está en el delegado de cada pestaña de Main.qml, en un Loader: solo existe
// mientras se ve. No se queda el foco: se sigue escribiendo en la página, y las
// flechas, Enter y Esc del campo llegan por key().
Item {
    id: root

    // Rectángulo del campo, en coordenadas de la pestaña
    property rect field
    // "username", "password" o "new-password"
    property string kind: ""
    // Las del sitio (Passwords.matches): [{ id, username, title }]
    property var entries: []
    // Lo escrito en el campo de usuario: filtra la lista
    property string filter: ""
    // Contraseña propuesta en un registro
    property string generated: ""

    signal entrySelected(string id)
    signal generatedAccepted(string password)
    signal regenerateRequested()
    signal unlockRequested()
    signal manageRequested()
    // No queda nada que mostrar
    signal dismissed()

    // Filas: { action: "fill" | "unlock" | "generate" | "manage", … }
    readonly property var rows: {
        const list = []
        if (kind === "new-password") {
            list.push({ action: "generate" })
        } else if (Passwords.unlocked) {
            const text = filter.toLowerCase()
            for (const entry of entries) {
                if (text === "" || entry.username.toLowerCase().startsWith(text))
                    list.push({ action: "fill", id: entry.id, username: entry.username, title: entry.title })
            }
        } else if (Passwords.exists) {
            list.push({ action: "unlock" })
        }
        if (list.length > 0)
            list.push({ action: "manage" })
        return list
    }
    property int currentIndex: -1

    onRowsChanged: {
        currentIndex = -1
        if (rows.length === 0)
            dismissed()
    }
    // Sin nada que mostrar ya al crearse (sitio sin guardadas): se va
    Component.onCompleted: if (rows.length === 0) Qt.callLater(root.dismissed)
    visible: rows.length > 0

    // Flechas, Enter y Esc desde el campo de la página
    function key(name) {
        if (name === "down")
            currentIndex = (currentIndex + 1) % rows.length
        else if (name === "up")
            currentIndex = currentIndex <= 0 ? rows.length - 1 : currentIndex - 1
        else if (name === "enter" && currentIndex >= 0)
            activate(rows[currentIndex])
        else if (name === "escape" || name === "enter")
            dismissed()
    }
    function activate(row) {
        if (row.action === "fill")
            entrySelected(row.id)
        else if (row.action === "generate")
            generatedAccepted(generated)
        else if (row.action === "unlock")
            unlockRequested()
        else
            manageRequested()
    }

    // Ocupa la pestaña (el Loader de Main la llena); la lista va bajo el
    // campo o, si no cabe, encima
    readonly property real _below: field.y + field.height + Theme.spacing / 2

    Item {
        id: card
        x: Math.max(Theme.spacing, Math.min(root.field.x, root.width - width - Theme.spacing))
        y: root._below + height <= root.height - Theme.spacing ? root._below
           : Math.max(Theme.spacing, root.field.y - height - Theme.spacing / 2)
        width: Math.min(Math.max(root.field.width, Theme.credentialPopupWidth), root.width - 2 * Theme.spacing)
        height: column.implicitHeight + 2 * Theme.spacing

        // Que la página de debajo no reciba clics, rueda ni hover
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onWheel: wheel => wheel.accepted = true
        }

        PopupBackground {
            anchors.fill: parent
        }

        Column {
            id: column
            anchors.fill: parent
            anchors.margins: Theme.spacing

            Repeater {
                model: root.rows

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool highlighted: rowHover.hovered || root.currentIndex === index
                    readonly property bool twoLines: modelData.action === "fill" || modelData.action === "generate"

                    width: parent.width
                    height: twoLines ? Theme.credentialRowHeight : Theme.popupRowHeight

                    // La de gestionar va separada de las demás
                    Rectangle {
                        visible: row.modelData.action === "manage"
                        width: parent.width
                        height: 1
                        color: Colors.hairlineSoft
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: row.modelData.action === "manage" ? Theme.spacing / 2 : 0
                        radius: Theme.radiusSmall
                        color: row.highlighted ? Colors.tintHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    }

                    Icon {
                        id: rowIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: row.modelData.action === "manage" ? Theme.spacing / 4 : 0
                        name: ({ fill: "user", unlock: "lock", generate: "generate", manage: "passwords" })[row.modelData.action]
                        color: row.modelData.action === "generate" ? Colors.brandLight1 : Colors.inkSoft
                    }

                    Column {
                        anchors.left: rowIcon.right
                        anchors.leftMargin: Theme.spacing
                        anchors.right: regenerate.visible ? regenerate.left : parent.right
                        anchors.rightMargin: Theme.spacing
                        anchors.verticalCenter: rowIcon.verticalCenter

                        Text {
                            width: parent.width
                            text: row.modelData.action === "fill" ? (row.modelData.username || "(sin usuario)")
                                : row.modelData.action === "generate" ? "Usar una contraseña segura"
                                : row.modelData.action === "unlock" ? "Desbloquear contraseñas guardadas"
                                : "Gestionar contraseñas"
                            color: Colors.ink
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                        Text {
                            width: parent.width
                            visible: row.twoLines
                            text: row.modelData.action === "fill" ? row.modelData.title : root.generated
                            color: Colors.inkMuted
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: row.modelData.action === "generate" ? Theme.monospaceFont : font.family
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }

                    HoverHandler {
                        id: rowHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.activate(row.modelData)
                    }

                    // Otra contraseña distinta
                    IconButton {
                        id: regenerate
                        visible: row.modelData.action === "generate"
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacing / 2
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "reload"
                        flat: true
                        width: Theme.buttonSizeSmall
                        height: Theme.buttonSizeSmall
                        iconSize: Theme.iconSizeSmall
                        tooltip: "Otra contraseña"
                        onClicked: root.regenerateRequested()
                    }
                }
            }
        }
    }
}

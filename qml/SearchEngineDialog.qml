pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic

import "urls.js" as Urls

// Diálogo para elegir el motor de búsqueda: pulsar un buscador lo elige al
// momento y cierra. Abajo, uno personalizado: nombre y dirección con %s.
Popup {
    id: root

    // Se intentó guardar un personalizado no válido
    property bool customError: false

    function useCustom() {
        if (!SearchEngines.setCustom(nameField.text, urlField.text)) {
            customError = true
            urlField.forceActiveFocus()
            return
        }
        close()
    }

    width: Theme.dialogWidth
    padding: Theme.margin + Theme.spacing
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent

    onAboutToShow: {
        nameField.text = SearchEngines.customName
        urlField.text = SearchEngines.customUrl
        customError = false
    }

    Overlay.modal: Rectangle { color: Theme.backgroundScrim }

    background: PopupBackground {}

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationBase }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationFast }
    }

    contentItem: Column {
        spacing: Theme.margin

        Text {
            text: "Motor de búsqueda"
            color: Theme.ink
            font.pixelSize: Theme.fontSizeTitle
            font.weight: Font.DemiBold
        }

        Column {
            width: parent.width

            Repeater {
                // Los incluidos y, si existe, el personalizado
                model: SearchEngines.hasCustom
                       ? SearchEngines.engines.concat([{ key: "custom", name: SearchEngines.customName,
                                                         url: SearchEngines.customUrl }])
                       : SearchEngines.engines

                delegate: Item {
                    id: row

                    required property var modelData
                    readonly property bool selected: modelData.key === SearchEngines.key

                    width: parent.width
                    height: Theme.popupRowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: row.selected ? Theme.tintActive : (rowHover.hovered ? Theme.tintHover : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    }

                    // Marca del elegido
                    Rectangle {
                        visible: row.selected
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.markerWidth
                        height: parent.height - Theme.spacing * 2
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.brand1 }
                            GradientStop { position: 1.0; color: Theme.brand2 }
                        }
                    }

                    Image {
                        id: favicon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.faviconSize
                        height: Theme.faviconSize
                        sourceSize: Qt.size(2 * Theme.faviconSize, 2 * Theme.faviconSize)
                        source: Urls.favicon(row.modelData.url)
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }

                    // Sin favicon (sin conexión): la lupa
                    Icon {
                        visible: !favicon.visible
                        anchors.centerIn: favicon
                        name: "search"
                        color: Theme.inkSoft
                    }

                    Text {
                        anchors.left: favicon.right
                        anchors.leftMargin: Theme.spacing
                        anchors.right: domain.left
                        anchors.rightMargin: Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: Theme.ink
                        font.pixelSize: Theme.fontSize
                        font.weight: row.selected ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        id: domain
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.margin
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, row.width / 2)
                        text: Urls.host(row.modelData.url)
                        color: Theme.inkMuted
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideLeft
                    }

                    HoverHandler {
                        id: rowHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        // Agarre exclusivo: si no, lo que hay debajo del diálogo
                        // (un acceso rápido, una noticia) recibe también el clic
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            SearchEngines.select(row.modelData.key)
                            root.close()
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.line
        }

        Text {
            text: "Personalizado"
            color: Theme.inkSecondary
            font.pixelSize: Theme.fontSizeSmall
        }

        FormField {
            id: nameField
            width: parent.width
            placeholderText: "Nombre, p. ej. Wikipedia"
            onAccepted: root.useCustom()
        }

        FormField {
            id: urlField
            width: parent.width
            placeholderText: "Dirección con %s en lugar del texto"
            onTextChanged: root.customError = false
            onAccepted: root.useCustom()
        }

        Text {
            width: parent.width
            text: root.customError
                  ? "Dirección no válida: falta el dominio o el %s"
                  : "Ejemplo: es.wikipedia.org/w/index.php?search=%s"
            color: root.customError ? Theme.danger : Theme.inkMuted
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }

        Row {
            anchors.right: parent.right
            spacing: Theme.spacing

            TextButton {
                text: "Cerrar"
                onClicked: root.close()
            }
            TextButton {
                text: "Usar personalizado"
                primary: true
                enabled: urlField.text.trim() !== ""
                onClicked: root.useCustom()
            }
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick

// Novedades de la versión instalada: título, versión y la lista de cambios
// (Updates.takeReleaseNotes, de CHANGELOG.md). Se ve en su propia pestaña
// solo al arrancar tras actualizarse; al cerrarla no se puede volver a abrir.
Item {
    id: root

    // { title, version, groups: [{ name, items }] }
    property var notes: null

    signal closeRequested()

    // Los grupos del CHANGELOG, con un nombre para quien usa Mitis
    readonly property var groupInfo: ({
        "Añadido": { name: "Nuevo", icon: "new-tab" },
        "Cambiado": { name: "Cambios", icon: "reload" },
        "Corregido": { name: "Correcciones", icon: "check" },
        "Eliminado": { name: "Ya no está", icon: "close" }
    })

    GlassBackdrop {
        anchors.fill: parent

        ThemeBackground {
            anchors.fill: parent
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.y + column.height + Theme.ntpSectionSpacing * 3
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column
            width: Math.min(root.width - 4 * Theme.margin, Theme.releaseNotesMaxWidth)
            x: (root.width - width) / 2
            y: Theme.ntpSectionSpacing * 2
            spacing: Theme.releaseNotesGroupSpacing

            // Logo, título y versión
            Column {
                width: parent.width
                spacing: Theme.spacing

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Theme.ntpLogoWidth
                    height: width * implicitHeight / Math.max(1, implicitWidth)
                    source: Theme.dark ? "qrc:/branding/mitis-logo-dark.png" : "qrc:/branding/mitis-logo-light.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
                Item {
                    width: 1
                    height: Theme.margin
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.notes ? root.notes.title : ""
                    color: Theme.ink
                    font.pixelSize: Theme.fontSizeHeading
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.notes ? "Versión " + root.notes.version : ""
                    color: Theme.inkSecondary
                    font.pixelSize: Theme.fontSizeTitle
                }
            }

            Repeater {
                model: root.notes ? root.notes.groups : []

                delegate: Column {
                    id: group

                    required property var modelData
                    readonly property var info: root.groupInfo[modelData.name]
                                                ?? { name: modelData.name, icon: "info" }

                    width: column.width
                    spacing: Theme.margin

                    Row {
                        spacing: Theme.spacing + Theme.spacing / 2

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: group.info.icon
                            color: Theme.brandLight1
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: group.info.name
                            color: Theme.ink
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                        }
                    }

                    Surface {
                        width: parent.width
                        height: items.height
                        radius: Theme.radius
                        fill: Theme.surfaceFloat

                        Column {
                            id: items
                            width: parent.width
                            padding: Theme.margin + Theme.spacing / 2
                            spacing: Theme.margin

                            Repeater {
                                model: group.modelData.items

                                delegate: Item {
                                    id: change

                                    required property string modelData

                                    width: items.width - 2 * items.padding
                                    height: changeText.implicitHeight

                                    FontMetrics {
                                        id: metrics
                                        font: changeText.font
                                    }
                                    // Punto con el degradado de la marca, a la altura de la primera línea
                                    Rectangle {
                                        y: (metrics.height - height) / 2
                                        width: Theme.releaseNotesDotSize
                                        height: width
                                        radius: width / 2
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: Theme.brand1 }
                                            GradientStop { position: 1.0; color: Theme.brand2 }
                                        }
                                    }
                                    Text {
                                        id: changeText
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.releaseNotesDotSize + Theme.margin
                                        anchors.right: parent.right
                                        text: change.modelData
                                        textFormat: Text.MarkdownText
                                        color: Theme.ink
                                        font.pixelSize: Theme.fontSize
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }
                }
            }

            TextButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Entendido"
                primary: true
                onClicked: root.closeRequested()
            }
        }
    }
}

pragma ComponentBehavior: Bound
import QtCore as Core
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import Mitis.Core

// Página de nueva pestaña, en QML: buscador en el centro, accesos rápidos
// y noticias de tecnología, sobre el fondo del tema o una imagen propia.
// Una sola instancia para todas las pestañas (ver Main.qml).
Item {
    id: root

    signal navigate(url target)

    function focusSearch() {
        search.forceActiveFocus()
    }

    readonly property var defaultLinks: [
        { name: "YouTube", url: "https://www.youtube.com/" },
        { name: "Wikipedia", url: "https://es.wikipedia.org/" },
        { name: "GitHub", url: "https://github.com/" },
        { name: "Gmail", url: "https://mail.google.com/" }
    ]

    ListModel {
        id: links
    }

    function saveLinks() {
        const list = []
        for (let i = 0; i < links.count; i++)
            list.push({ name: links.get(i).name, url: links.get(i).url })
        Settings.quickLinks = JSON.stringify(list)
    }

    Component.onCompleted: {
        let list = root.defaultLinks
        try {
            if (Settings.quickLinks !== "")
                list = JSON.parse(Settings.quickLinks)
        } catch (error) {
            console.warn("[Mitis] Accesos rápidos dañados; se usan los de serie")
        }
        list.forEach(link => links.append({ name: link.name, url: link.url }))
    }

    onVisibleChanged: if (visible) News.refreshIfStale()

    // ── Fondo ────────────────────────────────────────────────────────
    // Del tema
    ThemeBackground {
        anchors.fill: parent
    }

    // Imagen propia, decodificada al tamaño de la pantalla (no al de la foto)
    Image {
        id: wallpaper
        anchors.fill: parent
        source: Settings.newTabBackground
        sourceSize: Qt.size(Screen.width, Screen.height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
    }
    Rectangle {
        anchors.fill: parent
        visible: wallpaper.visible
        color: Theme.backgroundScrim
    }

    FileDialog {
        id: picker
        title: "Elegir imagen de fondo"
        nameFilters: ["Imágenes (*.png *.jpg *.jpeg *.webp *.bmp)"]
        currentFolder: Core.StandardPaths.standardLocations(Core.StandardPaths.PicturesLocation)[0]
        onAccepted: Settings.newTabBackground = selectedFile.toString()
    }

    // ── Contenido ────────────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        contentHeight: column.y + column.height + Theme.ntpSectionSpacing * 2
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column
            width: Math.min(root.width - 4 * Theme.margin, Theme.ntpMaxWidth)
            x: (root.width - width) / 2
            y: Math.max(Theme.ntpSectionSpacing * 2, root.height * 0.22)
            spacing: Theme.ntpSectionSpacing

            // Buscador
            TextField {
                id: search
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, Theme.ntpSearchWidth)
                height: Theme.ntpSearchHeight
                leftPadding: Theme.margin * 2 + Theme.iconSize
                rightPadding: Theme.margin * 2
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.ink
                placeholderText: "Buscar en " + SearchEngines.name + " o escribir una dirección"
                placeholderTextColor: Theme.inkMuted
                selectionColor: Theme.selection
                selectedTextColor: Theme.ink
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightInput
                selectByMouse: true

                // Mismo degradado que el campo de dirección y los controles
                background: Rectangle {
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.controlsStart }
                        GradientStop { position: 1.0; color: Theme.controlsEnd }
                    }
                    border.width: 1
                    border.color: search.activeFocus ? Theme.focusRing
                                                     : (searchHover.hovered ? Theme.hairlineHover : Theme.hairline)
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                    Icon {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin + Theme.spacing / 2
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        color: search.activeFocus ? Theme.brandLight1 : Theme.inkMuted
                    }
                }

                HoverHandler {
                    id: searchHover
                    cursorShape: Qt.IBeamCursor
                }

                onAccepted: {
                    const target = SearchEngines.resolve(text)
                    if (target !== "") {
                        text = ""
                        root.navigate(target)
                    }
                }
            }

            // Accesos rápidos
            Item {
                width: parent.width
                height: quickLinks.height

                Flow {
                    id: quickLinks
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width,
                                    (links.count + 1) * (Theme.tileWidth + spacing) - spacing)
                    spacing: Theme.spacing

                    Repeater {
                        model: links

                        delegate: QuickLinkTile {
                            required property int index
                            required url
                            required name
                            onOpened: root.navigate(url)
                            onRemoveRequested: {
                                links.remove(index)
                                root.saveLinks()
                            }
                        }
                    }

                    QuickLinkTile {
                        visible: links.count < Theme.quickLinksMax
                        adder: true
                        onOpened: editor.openEmpty()
                    }
                }
            }

            // Noticias
            Column {
                width: parent.width
                spacing: Theme.margin

                Item {
                    width: parent.width
                    height: Theme.buttonSizeSmall

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "news"
                            color: Theme.brandLight1
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Tecnología"
                            color: Theme.ink
                            font.pixelSize: Theme.fontSizeTitle
                            font.weight: Font.DemiBold
                        }
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.buttonSizeSmall
                        height: Theme.buttonSizeSmall
                        flat: true
                        icon: "reload"
                        iconSize: Theme.iconSizeSmall
                        tooltip: "Actualizar noticias"
                        enabled: !News.loading
                        onClicked: News.refresh()
                    }
                }

                Text {
                    visible: News.items.count === 0
                    text: News.loading ? "Cargando noticias…"
                                       : (News.failed ? "No se pudieron cargar las noticias." : "")
                    color: Theme.inkMuted
                    font.pixelSize: Theme.fontSize
                }

                Grid {
                    id: news
                    width: parent.width
                    columns: width >= Theme.ntpNewsTwoColumnsWidth ? 2 : 1
                    spacing: Theme.spacing

                    Repeater {
                        model: News.items

                        delegate: NewsCard {
                            required title
                            required source
                            required property string link
                            required property real published
                            width: (news.width - (news.columns - 1) * news.spacing) / news.columns
                            age: News.age(published)
                            onOpened: root.navigate(link)
                        }
                    }
                }
            }
        }
    }

    // Botones de fondo, arriba a la derecha
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.margin
        spacing: Theme.spacing

        IconButton {
            visible: Settings.newTabBackground !== ""
            icon: "background-reset"
            tooltip: "Quitar fondo"
            tooltipBelow: true
            onClicked: Settings.newTabBackground = ""
        }
        IconButton {
            icon: "background"
            tooltip: "Cambiar fondo"
            tooltipBelow: true
            onClicked: picker.open()
        }
    }

    QuickLinkEditor {
        id: editor
        parent: root
        onAdded: (name, url) => {
            links.append({ name: name, url: url })
            root.saveLinks()
        }
    }
}

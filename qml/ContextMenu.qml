pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic

// Menú contextual de la página (clic derecho). Recibe la descripción neutral
// de BrowserTab.contextMenuRequested y decide qué opciones mostrar; quien lo
// usa ejecuta la acción elegida (actionSelected).
// Se abre en el cursor y nunca se sale de su `parent` (la ventana).
Popup {
    id: root

    // Lo que había bajo el cursor (ver BrowserTab.contextMenuRequested), más
    // canGoBack y canGoForward de la pestaña para el grupo de la página
    property var info: ({})
    // «Inspeccionar»: solo con las herramientas de desarrollo activadas en Configuración
    property bool inspectAvailable: false
    // Filas: { action, label, icon, shortcut, enabled } o { separator: true }
    property var entries: []
    // Fila resaltada (ratón o teclado); -1 = ninguna
    property int current: -1

    signal actionSelected(string action)

    readonly property int separatorHeight: Theme.spacing + 1
    readonly property int searchTextMax: 24

    padding: Theme.spacing
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: PopupBackground {}

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationFast }
    }

    // Abre el menú para `info` con la esquina en (px, py), coordenadas del parent
    function show(menuInfo, px, py) {
        info = menuInfo
        entries = buildEntries(menuInfo)
        current = -1

        // Ancho según la fila más larga, entre optionsWidth y popupWidth
        let widest = 0
        let menuHeight = 2 * padding
        for (const entry of entries) {
            if (entry.separator) {
                menuHeight += separatorHeight
                continue
            }
            menuHeight += Theme.popupRowHeight
            labelMetrics.text = entry.label
            shortcutMetrics.text = entry.shortcut ?? ""
            const shortcutWidth = entry.shortcut ? Theme.margin + shortcutMetrics.advanceWidth : 0
            widest = Math.max(widest, Theme.margin + Theme.iconSize + Theme.spacing
                              + labelMetrics.advanceWidth + shortcutWidth + Theme.margin)
        }
        width = Math.min(Theme.popupWidth, Math.max(Theme.optionsWidth, Math.ceil(widest + 2 * padding)))

        // Si no cabe a la derecha o abajo, se abre hacia el otro lado
        const area = parent
        const left = px + width > area.width ? px - width : px
        const top = py + menuHeight > area.height ? py - menuHeight : py
        x = Math.max(0, Math.min(left, area.width - width))
        y = Math.max(0, Math.min(top, area.height - menuHeight))
        open()
    }

    // Grupos en el orden de Chrome. La página solo sale si no hay nada más.
    function buildEntries(menuInfo) {
        const groups = []
        const row = (action, label, icon, shortcut, enabled) =>
            ({ action: action, label: label, icon: icon, shortcut: shortcut ?? "", enabled: enabled ?? true })

        if (menuInfo.linkUrl) {
            groups.push([
                row("openLinkBackground", "Abrir en pestaña nueva", "new-tab"),
                row("openLink", "Abrir en pestaña nueva y cambiar a ella", "open-link"),
                row("copyLink", "Copiar dirección del enlace", "copy-link"),
                row("saveLink", "Guardar enlace", "save")
            ])
        }
        if (menuInfo.mediaType === "image" && menuInfo.mediaUrl) {
            groups.push([
                row("openImage", "Abrir imagen en pestaña nueva", "open-image"),
                row("copyImage", "Copiar imagen", "copy"),
                row("copyImageUrl", "Copiar dirección de la imagen", "copy-link"),
                row("saveImage", "Guardar imagen", "save")
            ])
        } else if ((menuInfo.mediaType === "video" || menuInfo.mediaType === "audio") && menuInfo.mediaUrl) {
            groups.push([
                row("copyMediaUrl", "Copiar dirección del archivo", "copy-link"),
                row("saveMedia", "Guardar archivo", "save")
            ])
        }
        if (menuInfo.editable) {
            groups.push([
                row("undo", "Deshacer", "undo", "Ctrl+Z", menuInfo.canUndo),
                row("redo", "Rehacer", "redo", "Ctrl+Mayús+Z", menuInfo.canRedo),
                row("cut", "Cortar", "cut", "Ctrl+X", menuInfo.canCut),
                row("copy", "Copiar", "copy", "Ctrl+C", menuInfo.canCopy),
                row("paste", "Pegar", "paste", "Ctrl+V", menuInfo.canPaste),
                row("selectAll", "Seleccionar todo", "select-all", "Ctrl+A", menuInfo.canSelectAll)
            ])
        } else if (menuInfo.selectedText.trim() !== "") {
            const text = menuInfo.selectedText.trim().replace(/\s+/g, " ")
            const short = text.length > searchTextMax ? text.slice(0, searchTextMax).trimEnd() + "…" : text
            groups.push([
                row("copy", "Copiar", "copy", "Ctrl+C"),
                row("search", "Buscar “" + short + "” en " + SearchEngines.name, "search")
            ])
        }
        if (groups.length === 0) {
            groups.push([
                row("back", "Atrás", "back", "Alt+←", menuInfo.canGoBack),
                row("forward", "Adelante", "forward", "Alt+→", menuInfo.canGoForward),
                row("reload", "Recargar", "reload", "Ctrl+R"),
                row("savePage", "Guardar página", "save")
            ])
        }
        // Al final
        if (inspectAvailable)
            groups.push([row("inspect", "Inspeccionar", "inspect", "F12")])

        let result = []
        for (const group of groups) {
            if (result.length > 0)
                result.push({ separator: true })
            result = result.concat(group)
        }
        return result
    }

    function trigger(index) {
        const entry = entries[index]
        if (!entry || entry.separator || !entry.enabled)
            return
        close()
        actionSelected(entry.action)
    }

    // Siguiente fila disponible en `step` (1 o -1), dando la vuelta
    function move(step) {
        const count = entries.length
        let index = current >= 0 ? current : (step > 0 ? -1 : count)
        for (let i = 0; i < count; i++) {
            index = (index + step + count) % count
            const entry = entries[index]
            if (!entry.separator && entry.enabled) {
                current = index
                return
            }
        }
    }

    TextMetrics {
        id: labelMetrics
        font.pixelSize: Theme.fontSize
    }
    TextMetrics {
        id: shortcutMetrics
        font.pixelSize: Theme.fontSizeSmall
    }

    contentItem: Column {
        focus: true

        Keys.onUpPressed: root.move(-1)
        Keys.onDownPressed: root.move(1)
        Keys.onReturnPressed: root.trigger(root.current)
        Keys.onEnterPressed: root.trigger(root.current)

        Repeater {
            model: root.entries

            delegate: Item {
                id: entryItem

                required property var modelData
                required property int index

                readonly property bool separator: modelData.separator === true
                readonly property bool available: !separator && modelData.enabled

                width: parent.width
                height: separator ? root.separatorHeight : Theme.popupRowHeight

                Rectangle {
                    visible: entryItem.separator
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.spacing
                    anchors.rightMargin: Theme.spacing
                    height: 1
                    color: Theme.line
                }

                Rectangle {
                    visible: !entryItem.separator
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: entryItem.available && root.current === entryItem.index ? Theme.tintHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Icon {
                    id: entryIcon
                    visible: !entryItem.separator
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    name: entryItem.modelData.icon ?? ""
                    color: entryItem.available ? Theme.inkSoft : Theme.inkDisabled
                }

                Text {
                    visible: !entryItem.separator
                    anchors.left: entryIcon.right
                    anchors.leftMargin: Theme.spacing
                    anchors.right: shortcutText.text ? shortcutText.left : parent.right
                    anchors.rightMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    text: entryItem.modelData.label ?? ""
                    color: entryItem.available ? Theme.ink : Theme.inkDisabled
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }

                Text {
                    id: shortcutText
                    visible: !entryItem.separator
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.margin
                    anchors.verticalCenter: parent.verticalCenter
                    text: entryItem.modelData.shortcut ?? ""
                    color: entryItem.available ? Theme.inkMuted : Theme.inkDisabled
                    font.pixelSize: Theme.fontSizeSmall
                }

                HoverHandler {
                    enabled: entryItem.available
                    onHoveredChanged: {
                        if (hovered)
                            root.current = entryItem.index
                        else if (root.current === entryItem.index)
                            root.current = -1
                    }
                }
                TapHandler {
                    enabled: entryItem.available
                    // Agarre exclusivo: si no, lo que hay debajo recibe también el clic
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.trigger(entryItem.index)
                }
            }
        }
    }
}

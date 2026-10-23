pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic

// Lista desplegable de pestañas abiertas: favicon, título y botones de fijar,
// sonido y cerrar. Las suspendidas (para ahorrar memoria) salen atenuadas y
// con una luna. Las fijadas van arriba, separadas del resto.
// Las filas se reordenan arrastrándolas, cada una dentro de su grupo.
// Arriba, un campo filtra las pestañas por título o dirección.
Popup {
    id: root

    // Modelo con los roles: title, icon, url, audible, muted, microphone, camera, pinned, lifecycle
    required property var tabs
    property int currentIndex: 0
    // Pestañas cerradas que se pueden reabrir
    property int closedCount: 0
    // Las fijadas son las primeras `pinnedCount` filas
    property int pinnedCount: 0
    // Reordenar arrastrando. Con un filtro de texto activo va a false:
    // las filas visibles no son consecutivas y el destino sería confuso.
    readonly property bool dragEnabled: !filtering

    // ── Filtro ───────────────────────────────────────────────────────
    // No hay modelo filtrado: las filas que no coinciden se ocultan (alto 0)
    // y cada fila conserva su índice real en `tabs`, que usan el arrastre
    // y todas las señales.
    readonly property string filterKey: fold(filterField.text.trim())
    readonly property bool filtering: filterKey !== ""
    // Índices del modelo de las filas visibles, en orden. Se recalcula con
    // refilter() al cambiar el filtro o el modelo.
    property var visibleRows: []

    // ── Navegación por teclado ───────────────────────────────────────
    // Índice del modelo de la fila resaltada (-1: ninguna). Al abrir es la
    // pestaña activa; al empezar a filtrar, la primera coincidencia. Las
    // teclas llegan a `filterField`, que conserva el foco, y la mueven por
    // `visibleRows`. Sigue a su pestaña si el modelo cambia (ver Connections).
    property int highlightedIndex: -1
    // Si había filtro en el último cambio del texto: al empezar a filtrar
    // el resaltado salta a la primera coincidencia
    property bool wasFiltering: false

    signal tabSelected(int index)
    signal tabCloseRequested(int index)
    signal tabMuteToggled(int index)
    signal tabPinToggled(int index)
    // Al soltar una fila arrastrada; Main limita `to` al grupo de la pestaña
    signal tabMoveRequested(int from, int to)
    signal newTabRequested()
    signal reopenRequested()

    // Minúsculas y sin tildes: "Café" y "cafe" coinciden
    function fold(text: string): string {
        return text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
    }

    // ¿La pestaña coincide con el filtro? Busca en título y dirección; sin
    // ninguno de los dos, en el texto que se ve ("Nueva pestaña").
    function textMatches(title: string, address: string): bool {
        if (!filtering)
            return true
        const shown = title || address ? title + "\n" + address : "Nueva pestaña"
        return fold(shown).includes(filterKey)
    }

    // Índices visibles en orden; punto de partida de la navegación por teclado
    function refilter() {
        const rows = []
        for (let i = 0; i < tabs.count; ++i) {
            const tab = tabs.get(i)
            if (textMatches(tab.title, String(tab.url)))
                rows.push(i)
        }
        visibleRows = rows
        // Se mantiene si sigue visible; si no, la activa (sin filtro) o la
        // primera visible
        if (!rows.includes(highlightedIndex))
            highlightedIndex = rows.length === 0 ? -1
                             : (!filtering && rows.includes(currentIndex) ? currentIndex : rows[0])
        // Aunque el índice no cambie, la fila pudo quedar fuera de la vista al
        // ocultarse otras. Sin filtro no se ocultan: así no salta la vista al
        // soltar una fila arrastrada.
        if (filtering && highlightedIndex >= 0)
            list.positionViewAtIndex(highlightedIndex, ListView.Contain)
    }

    // Mueve el resaltado `step` filas visibles (-1 arriba, 1 abajo), sin dar
    // la vuelta. Flechas y AvPág/RePág.
    function moveHighlight(step: int) {
        if (visibleRows.length === 0)
            return
        const pos = visibleRows.indexOf(highlightedIndex)
        const next = pos < 0 ? (step > 0 ? 0 : visibleRows.length - 1)
                             : Math.max(0, Math.min(pos + step, visibleRows.length - 1))
        highlightedIndex = visibleRows[next]
    }

    // Enter: la resaltada o, si no hay, la primera visible
    function activateHighlighted() {
        const index = highlightedIndex >= 0 ? highlightedIndex
                                            : (visibleRows.length > 0 ? visibleRows[0] : -1)
        if (index < 0)
            return
        tabSelected(index)
        close()
    }

    // Supr: cierra la resaltada. Las fijadas no se cierran: no hace nada.
    // El nuevo resaltado lo elige onRowsRemoved.
    function closeHighlighted() {
        if (highlightedIndex < 0 || tabs.get(highlightedIndex).pinned)
            return
        tabCloseRequested(highlightedIndex)
    }

    // Filas visibles que caben en la vista, para AvPág/RePág
    function pageStep(): int {
        return Math.max(1, Math.floor(list.height / Theme.popupRowHeight))
    }

    onFilterKeyChanged: {
        if (filtering && !wasFiltering)
            highlightedIndex = -1
        wasFiltering = filtering
        refilter()
    }
    onHighlightedIndexChanged: if (highlightedIndex >= 0) list.positionViewAtIndex(highlightedIndex, ListView.Contain)
    Component.onCompleted: refilter()
    // Cada vez que se abre, el filtro empieza vacío y con el foco
    // y el resaltado en la pestaña activa
    onAboutToShow: {
        filterField.clear()
        highlightedIndex = -1
        refilter()
    }
    onOpened: filterField.forceActiveFocus()

    // El modelo cambia con la lista abierta: pestañas nuevas, cerradas,
    // movidas o con otro título. El resaltado es un índice del modelo:
    // se corrige para que siga en la misma pestaña.
    Connections {
        target: root.tabs
        function onRowsInserted(parent: var, first: int, last: int) {
            if (root.highlightedIndex >= first)
                root.highlightedIndex += last - first + 1
            root.refilter()
        }
        function onRowsRemoved(parent: var, first: int, last: int) {
            const old = root.highlightedIndex
            // Posición entre las visibles antes de quitarla (visibleRows aún es la vieja)
            const pos = root.visibleRows.indexOf(old)
            const removed = old >= first && old <= last
            if (old > last)
                root.highlightedIndex = old - (last - first + 1)
            else if (removed)
                root.highlightedIndex = -1
            root.refilter()
            // Cerrada la resaltada: pasa a la que ocupa su lugar, o a la
            // anterior si era la última visible
            const rows = root.visibleRows
            if (removed && pos >= 0 && rows.length > 0)
                root.highlightedIndex = rows[Math.min(pos, rows.length - 1)]
        }
        function onRowsMoved(parent: var, start: int, end: int, destination: var, row: int) {
            const h = root.highlightedIndex
            const n = end - start + 1
            // `row` es el destino antes de mover: al bajar, la fila tras la que cae + 1
            if (h >= start && h <= end)
                root.highlightedIndex = (row > end ? row - n : row) + h - start
            else if (row > end && h > end && h < row)
                root.highlightedIndex = h - n
            else if (row < start && h >= row && h < start)
                root.highlightedIndex = h + n
            root.refilter()
        }
        function onModelReset() { root.refilter() }
        // Sin filtro, un cambio de título no cambia qué filas se ven
        function onDataChanged() { if (root.filtering) root.refilter() }
    }

    width: Theme.popupWidth
    height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, Theme.popupMaxHeight)
    padding: Theme.spacing
    focus: true
    // Con texto en el filtro, Escape no cierra: lo recibe el campo y lo borra
    closePolicy: filterField.text !== "" ? Popup.CloseOnPressOutsideParent
                                         : Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

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

    contentItem: Column {
        id: column
        spacing: Theme.spacing / 2

        // Alto libre para la lista: el máximo menos campo, separador,
        // acciones, relleno y los tres huecos entre los cuatro bloques
        readonly property real listMaxHeight: Theme.popupMaxHeight - root.topPadding - root.bottomPadding
            - filterField.height - separator.height - actions.height - 3 * spacing

        FormField {
            id: filterField
            width: parent.width
            leftPadding: Theme.margin + Theme.iconSizeSmall + Theme.spacing
            placeholderText: "Buscar pestañas"
            // Toma el foco en cuanto el popup lo recibe
            focus: true

            Icon {
                name: "search"
                size: Theme.iconSizeSmall
                color: filterField.activeFocus ? Theme.brandLight1 : Theme.inkMuted
                x: Theme.margin
                anchors.verticalCenter: parent.verticalCenter
            }

            onAccepted: root.activateHighlighted()

            // Teclas de la lista. Solo sin modificadores (salvo el del teclado
            // numérico), para no quitarle al campo Mayús+flecha y similares.
            function plain(event: KeyEvent): bool {
                return (event.modifiers & ~Qt.KeypadModifier) === Qt.NoModifier
            }
            Keys.onUpPressed: event => {
                if (plain(event)) root.moveHighlight(-1); else event.accepted = false
            }
            Keys.onDownPressed: event => {
                if (plain(event)) root.moveHighlight(1); else event.accepted = false
            }
            Keys.onPressed: event => {
                if (!plain(event))
                    return
                if (event.key === Qt.Key_PageUp)
                    root.moveHighlight(-root.pageStep())
                else if (event.key === Qt.Key_PageDown)
                    root.moveHighlight(root.pageStep())
                else
                    return
                event.accepted = true
            }
            // Supr cierra la pestaña solo con el cursor al final y sin
            // selección; si no, borra texto como siempre
            Keys.onDeletePressed: event => {
                if (plain(event) && cursorPosition === length && selectedText === "")
                    root.closeHighlighted()
                else
                    event.accepted = false
            }
            // Tab no saca el foco del campo hacia los botones de las filas:
            // la lista se maneja entera desde aquí
            Keys.onTabPressed: event => event.accepted = true
            Keys.onBacktabPressed: event => event.accepted = true
            // Primer Escape: borra el texto. Con el campo vacío, cierra
            // (closePolicy ya lo hace; esto cubre el caso por si acaso).
            Keys.onEscapePressed: event => {
                if (text !== "")
                    clear()
                else
                    root.close()
            }
        }

        // Ninguna fila coincide: este texto ocupa el sitio de la lista
        Text {
            visible: root.filtering && root.visibleRows.length === 0
            width: parent.width
            height: Theme.popupRowHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "Ninguna pestaña coincide"
            color: Theme.inkMuted
            font.pixelSize: Theme.fontSize
        }

        ListView {
            id: list
            visible: root.visibleRows.length > 0
            width: parent.width
            // Alto calculado y no contentHeight: con filas ocultas (alto 0),
            // ListView estima contentHeight con las filas creadas y puede fallar
            height: Math.min(root.visibleRows.length * Theme.popupRowHeight
                             + (showSeparator ? Theme.spacing : 0), column.listMaxHeight)
            clip: true
            model: root.tabs
            boundsBehavior: Flickable.StopAtBounds
            // Sin desplazar con el ratón mientras se arrastra una fila
            interactive: !rowDragging

            // ── Arrastre para reordenar ──────────────────────────────
            // La fila arrastrada se desplaza con un Translate; el modelo no
            // cambia hasta soltar, y entonces se pide un solo movimiento.
            property int dragFrom: -1
            property bool dragCanceled: false
            // Centro de la fila al empezar, en coordenadas del contenido
            property real dragOriginY: 0
            property real dragStartContentY: 0
            property real dragTranslation: 0
            readonly property bool rowDragging: dragFrom >= 0
            // Suma el desplazamiento automático para que la fila siga al puntero
            readonly property real dragOffset: rowDragging ? dragTranslation + contentY - dragStartContentY : 0
            readonly property real dragCenterY: dragOriginY + dragOffset
            readonly property int dragTo: rowDragging ? targetIndex(dragCenterY) : -1
            // -1 sube, 1 baja, 0 quieto: la fila está cerca de un borde
            readonly property int scrollDirection: {
                if (!rowDragging || contentHeight <= height)
                    return 0
                const y = dragCenterY - contentY
                if (y < Theme.popupRowHeight / 2)
                    return -1
                if (y > height - Theme.popupRowHeight / 2)
                    return 1
                return 0
            }

            // Fila bajo `y`, limitada al grupo de la arrastrada (fijadas o no)
            function targetIndex(y: real): int {
                let i = indexAt(width / 2, y)
                if (i < 0)
                    i = y < 0 ? 0 : count - 1
                const pinned = dragFrom < root.pinnedCount
                const first = pinned ? 0 : root.pinnedCount
                const last = pinned ? root.pinnedCount - 1 : count - 1
                return Math.max(first, Math.min(i, last))
            }

            function startDrag(index: int, centerY: real) {
                dragCanceled = false
                dragTranslation = 0
                dragOriginY = centerY
                dragStartContentY = contentY
                dragFrom = index
            }

            // Se llama con callLater: la cancelación llega justo después
            // de desactivarse el DragHandler
            function finishDrag() {
                if (!rowDragging)
                    return
                const from = dragFrom
                const to = dragTo
                // Antes de mover: si no, otra fila heredaría el desplazamiento
                dragFrom = -1
                if (!dragCanceled && to >= 0 && to !== from)
                    root.tabMoveRequested(from, to)
            }

            // Separador entre fijadas y normales: solo sin filtro. Con filtro
            // la lista es una sola tira de resultados y se oculta.
            readonly property bool showSeparator: !root.filtering && root.pinnedCount > 0
                                                  && root.pinnedCount < count

            // Si se abre o cierra una pestaña a mitad, los índices ya no valen
            onCountChanged: if (rowDragging) dragCanceled = true

            Timer {
                interval: Theme.dragScrollInterval
                repeat: true
                running: list.scrollDirection !== 0
                onTriggered: {
                    const max = list.originY + list.contentHeight - list.height
                    list.contentY = Math.max(list.originY, Math.min(
                        list.contentY + list.scrollDirection * Theme.dragScrollStep, max))
                }
            }

            // Dónde caerá: borde de la fila destino del lado al que se mueve
            Rectangle {
                z: 3
                visible: list.dragTo >= 0 && list.dragTo !== list.dragFrom
                x: Theme.spacing
                y: {
                    const item = list.itemAtIndex(list.dragTo)
                    if (!item)
                        return 0
                    const bottom = item.y + item.height
                    return list.dragTo > list.dragFrom ? bottom - height
                                                       : bottom - Theme.popupRowHeight
                }
                width: list.width - 2 * Theme.spacing
                height: Theme.dropIndicatorHeight
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.brand1 }
                    GradientStop { position: 1.0; color: Theme.brand2 }
                }
            }

            // Al soltar, las filas desplazadas se deslizan a su sitio. La
            // movida no se anima: ya está donde se soltó.
            moveDisplaced: Transition {
                NumberAnimation {
                    property: "y"; duration: Theme.durationBase
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut
                }
            }

            delegate: Item {
                id: row

                required property int index
                required property string title
                required property url icon
                required property url url
                required property bool audible
                required property bool muted
                // 0 sin uso, 1 silenciado, 2 en uso (BrowserTab.microphone/camera)
                required property int microphone
                required property int camera
                required property bool pinned
                required property string lifecycle

                // Congelada o descargada (ver BrowserTab.lifecycle)
                readonly property bool suspended: lifecycle !== "active"
                readonly property bool current: index === root.currentIndex
                // Primera no fijada tras las fijadas: lleva el separador encima
                readonly property bool groupStart: list.showSeparator && !pinned && index === root.pinnedCount
                // Coincide con el filtro; si no, la fila se oculta con alto 0
                readonly property bool matches: root.textMatches(title, url.toString())
                // Resaltada por teclado (Enter, Supr). Se pinta como el hover
                readonly property bool highlighted: index === root.highlightedIndex
                // La que se está arrastrando
                readonly property bool lifted: list.dragFrom === index
                // Sin realce de hover mientras se arrastra cualquier fila
                readonly property bool hovered: rowHover.hovered && !list.rowDragging

                z: lifted ? 2 : 1
                visible: matches
                width: ListView.view.width
                height: matches ? content.height + (groupStart ? Theme.spacing : 0) : 0

                // Separador entre fijadas y el resto, en el hueco sobre la fila
                Rectangle {
                    visible: row.groupStart
                    width: parent.width
                    height: 1
                    y: Theme.spacing / 2
                    color: Theme.line
                }

                Item {
                    id: content
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Theme.popupRowHeight
                    opacity: row.lifted ? Theme.dragOpacity : 1
                    transform: Translate { y: row.lifted ? list.dragOffset : 0 }

                    // Base opaca de la fila levantada: tapa las que pasa por encima
                    Rectangle {
                        visible: row.lifted
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: Theme.surfacePopup
                        border.width: 1
                        border.color: Theme.hairline
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: row.current || row.lifted ? Theme.tintActive
                                                         : (row.hovered || row.highlighted ? Theme.tintHover : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        // Marca de la pestaña activa
                        Rectangle {
                            visible: row.current
                            width: Theme.markerWidth
                            height: parent.height - 2 * Theme.spacing
                            radius: width / 2
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.markerWidth
                            anchors.verticalCenter: parent.verticalCenter
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Theme.brand1 }
                                GradientStop { position: 1.0; color: Theme.brand2 }
                            }
                        }
                    }

                    Image {
                        id: favicon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.faviconSize
                        height: Theme.faviconSize
                        sourceSize: Qt.size(Theme.faviconSize, Theme.faviconSize)
                        source: row.icon
                        visible: status === Image.Ready
                        opacity: row.suspended ? Theme.suspendedOpacity : 1
                    }

                    Text {
                        anchors.left: favicon.right
                        anchors.leftMargin: Theme.spacing
                        anchors.right: buttons.left
                        anchors.rightMargin: Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.title || row.url.toString() || "Nueva pestaña"
                        color: row.current ? Theme.ink : row.suspended ? Theme.inkMuted : Theme.inkSecondary
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }

                    // Botones de la fila, de izquierda a derecha: fijar, sonido, cerrar
                    // (delante, la luna de las suspendidas, que no es un botón)
                    Row {
                        id: buttons
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacing / 2
                        anchors.verticalCenter: parent.verticalCenter

                        Item {
                            visible: row.suspended
                            width: Theme.buttonSizeSmall
                            height: Theme.buttonSizeSmall

                            Icon {
                                anchors.centerIn: parent
                                name: "suspended"
                                size: Theme.iconSizeSmall
                                color: Theme.inkMuted
                            }
                            HoverHandler { id: suspendedHover }
                            Tooltip {
                                text: row.lifecycle === "frozen" ? "Congelada para ahorrar memoria"
                                                                 : "Descargada para ahorrar memoria: se recargará al abrirla"
                                visible: suspendedHover.hovered
                            }
                        }

                        // Micrófono o cámara en uso: rojo; abiertos pero silenciados: apagado
                        Item {
                            visible: row.microphone > 0 || row.camera > 0
                            width: Theme.buttonSizeSmall
                            height: Theme.buttonSizeSmall

                            Icon {
                                anchors.centerIn: parent
                                name: row.microphone > 0 && row.camera > 0 ? "camera-microphone"
                                    : row.camera > 0 ? "camera" : "microphone"
                                size: Theme.iconSizeSmall
                                color: row.microphone === 2 || row.camera === 2 ? Theme.dangerStrong : Theme.inkMuted
                            }
                            HoverHandler { id: captureHover }
                            Tooltip {
                                text: {
                                    const parts = []
                                    if (row.microphone > 0)
                                        parts.push(row.microphone === 2 ? "Usando el micrófono" : "Micrófono silenciado")
                                    if (row.camera > 0)
                                        parts.push(row.camera === 2 ? "usando la cámara" : "cámara apagada")
                                    const text = parts.join(" · ")
                                    return text.charAt(0).toUpperCase() + text.slice(1)
                                }
                                visible: captureHover.hovered
                            }
                        }

                        // En las fijadas se ve siempre: indica que lo está
                        IconButton {
                            id: pinButton
                            width: Theme.buttonSizeSmall
                            height: Theme.buttonSizeSmall
                            icon: row.pinned && pinButton.hovered ? "unpin" : "pin"
                            iconSize: Theme.iconSizeSmall
                            tooltip: row.pinned ? "Desfijar pestaña" : "Fijar pestaña"
                            flat: true
                            opacity: row.pinned || row.hovered ? 1 : 0
                            onClicked: root.tabPinToggled(row.index)
                        }

                        // Sonido: visible mientras suena o si está silenciada
                        IconButton {
                            visible: row.audible || row.muted
                            width: Theme.buttonSizeSmall
                            height: Theme.buttonSizeSmall
                            icon: row.muted ? "muted" : "sound"
                            iconSize: Theme.iconSizeSmall
                            tooltip: row.muted ? "Activar sonido" : "Silenciar pestaña"
                            flat: true
                            onClicked: root.tabMuteToggled(row.index)
                        }

                        // Las fijadas no se cierran: hay que desfijarlas antes
                        IconButton {
                            visible: !row.pinned
                            width: Theme.buttonSizeSmall
                            height: Theme.buttonSizeSmall
                            icon: "close"
                            iconSize: Theme.iconSizeSmall
                            tooltip: "Cerrar pestaña"
                            flat: true
                            danger: true
                            opacity: row.hovered || row.current ? 1 : 0
                            onClicked: root.tabCloseRequested(row.index)
                        }
                    }

                    HoverHandler { id: rowHover }

                    // Solo vertical. Puede quitarle el puntero al ListView y a
                    // los botones, pero no dejar que se lo quiten: así no hay
                    // desplazamiento de la lista ni clic al soltar.
                    DragHandler {
                        id: rowDrag
                        target: null
                        enabled: root.dragEnabled
                        xAxis.enabled: false
                        grabPermissions: PointerHandler.CanTakeOverFromAnything
                        cursorShape: Qt.ClosedHandCursor
                        onActiveChanged: {
                            if (active)
                                list.startDrag(row.index, row.y + content.y + content.height / 2)
                            else
                                Qt.callLater(list.finishDrag)
                        }
                        onActiveTranslationChanged: if (active) list.dragTranslation = activeTranslation.y
                        onCanceled: list.dragCanceled = true
                    }

                    TapHandler {
                        // Agarre exclusivo al pulsar: si no, la página de debajo
                        // (p. ej. una noticia de la nueva pestaña) recibe también el clic
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            root.tabSelected(row.index)
                            root.close()
                        }
                    }
                }
            }
        }

        // Separador
        Rectangle {
            id: separator
            width: parent.width
            height: 1
            color: Theme.hairline
        }

        Column {
            id: actions
            width: parent.width

            PopupAction {
                width: parent.width
                icon: "new-tab"
                text: "Nueva pestaña"
                shortcut: "Ctrl+T"
                onTriggered: {
                    root.newTabRequested()
                    root.close()
                }
            }
            PopupAction {
                width: parent.width
                visible: root.closedCount > 0
                icon: "reopen"
                text: "Reabrir pestaña cerrada"
                shortcut: "Ctrl+Shift+T"
                onTriggered: {
                    root.reopenRequested()
                    root.close()
                }
            }
        }
    }
}

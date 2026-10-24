pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Mitis.Core

// Captura de pantalla de la página, como en Zen y Firefox (Ctrl+Mayús+S o el
// panel del sitio). Sobre la página, oscurecida:
//  · Al pasar el ratón se resalta la sección de debajo (un bloque de la
//    página: artículo, tarjeta…); un clic la elige. Arrastrando se elige un
//    área libre. Arriba, «Página visible» y «Página completa».
//  · La selección se ajusta con sus tiradores y se mueve arrastrándola.
//    Llevando el borde de arriba o de abajo al borde de la ventana, la página
//    se desplaza y la selección crece en vertical, más allá de lo visible (la
//    rueda también desplaza la página).
//  · Debajo, su tamaño y Copiar / Guardar / Cancelar. Guardar la deja en la
//    carpeta de descargas y en la lista de descargas.
// La imagen es la de la capa de las páginas (`source`, sin la interfaz). Lo
// que no cabe en la ventana se captura en trozos (desplazando la página) que
// junta Screenshot (C++); desde el segundo, lo que la página fija en pantalla
// (cabeceras…) se oculta para que no salga repetido.
// Coordenadas: la selección va en px CSS del documento; en pantalla, por `zoom`.
Item {
    id: root

    // Pestaña que se captura y capa que se copia (las páginas, sin la interfaz)
    property BrowserTab tab: null
    property Item source: null

    // "" (cerrada), "hover", "drag", "selected", "capturing" o "done"
    property string mode: ""
    readonly property bool active: mode !== ""
    // Ver BrowserTab.pageMetrics
    property var metrics: null
    // Sección bajo el ratón y selección: { x, y, w, h } del documento (px CSS)
    property var hovered: null
    property var selection: null
    // Aviso al terminar («Captura copiada»…)
    property string notice: ""

    readonly property real zoom: tab ? tab.zoom : 1
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1

    signal closed()

    function open(target) {
        tab = target
        hovered = null
        selection = null
        notice = ""
        mode = "hover"
        refresh()
        forceActiveFocus()
    }
    function close() {
        autoScroll.stop()
        sliceDelay.stop()
        Screenshot.clear()
        mode = ""
        tab = null
        closed()
    }
    function refresh(done) {
        if (!tab)
            return
        tab.pageMetrics(measured => {
            if (measured)
                root.metrics = measured
            if (done)
                done()
        })
    }

    // ── Coordenadas ──────────────────────────────────────────────────
    function toView(r) {
        if (!r || !metrics)
            return Qt.rect(0, 0, 0, 0)
        return Qt.rect((r.x - metrics.scrollX) * zoom, (r.y - metrics.scrollY) * zoom, r.w * zoom, r.h * zoom)
    }
    function docX(viewX) {
        return viewX / zoom + (metrics ? metrics.scrollX : 0)
    }
    function docY(viewY) {
        return viewY / zoom + (metrics ? metrics.scrollY : 0)
    }
    // Dentro del documento (en horizontal, lo visible) y con un alto máximo
    function clamp(r) {
        if (!metrics)
            return r
        const left = Math.max(metrics.scrollX, r.x)
        const right = Math.min(metrics.scrollX + metrics.width, r.x + r.w)
        const top = Math.max(0, r.y)
        const bottom = Math.min(Math.max(metrics.pageHeight, metrics.scrollY + metrics.height),
                                r.y + r.h, top + Theme.screenshotMaxHeight)
        return { x: left, y: top, w: Math.max(0, right - left), h: Math.max(0, bottom - top) }
    }
    // Lo que se ve de la página, en px CSS del documento
    function visibleArea() {
        return metrics ? { x: metrics.scrollX, y: metrics.scrollY, w: metrics.width, h: metrics.height } : null
    }

    // ── Elegir ───────────────────────────────────────────────────────
    // Una consulta a la página a la vez; si el ratón se movió entretanto, otra
    property bool _querying: false
    property point _pendingPoint: Qt.point(-1, -1)
    function querySection(point) {
        _pendingPoint = point
        if (_querying || !tab)
            return
        _querying = true
        const asked = point
        tab.sectionAt(asked.x / zoom, asked.y / zoom, found => {
            root._querying = false
            if (root.mode === "hover")
                root.hovered = found ? root.clamp(found) : null
            if (root._pendingPoint !== asked && root.mode === "hover")
                root.querySection(root._pendingPoint)
        })
    }

    function selectVisible() {
        refresh(() => {
            root.selection = root.clamp(root.visibleArea())
            root.mode = "selected"
        })
    }
    function selectWholePage() {
        refresh(() => {
            root.selection = root.clamp({ x: root.metrics.scrollX, y: 0, w: root.metrics.width,
                                          h: root.metrics.pageHeight })
            root.mode = "selected"
        })
    }

    // ── Ajustar (tiradores) y ampliar desplazando ────────────────────
    // Bordes: 1 izquierda, 2 derecha, 4 arriba, 8 abajo
    property int _edges: 0
    property point _lastPoint: Qt.point(0, 0)
    property int _scrollDirection: 0

    function resize(edges, point) {
        if (!selection)
            return
        const minimum = Theme.screenshotMinSize / zoom
        let left = selection.x
        let top = selection.y
        let right = selection.x + selection.w
        let bottom = selection.y + selection.h
        if (edges & 1)
            left = Math.min(docX(point.x), right - minimum)
        if (edges & 2)
            right = Math.max(docX(point.x), left + minimum)
        if (edges & 4)
            top = Math.min(docY(point.y), bottom - minimum)
        if (edges & 8)
            bottom = Math.max(docY(point.y), top + minimum)
        selection = clamp({ x: left, y: top, w: right - left, h: bottom - top })
    }
    // Arrastrando el borde de arriba o de abajo hasta el borde de la ventana,
    // la página se desplaza sola
    function dragEdge(edges, point) {
        _edges = edges
        _lastPoint = point
        resize(edges, point)
        _scrollDirection = (edges & 8) && point.y > height - Theme.screenshotEdgeZone ? 1
                         : (edges & 4) && point.y < Theme.screenshotEdgeZone ? -1 : 0
        if (_scrollDirection !== 0)
            autoScroll.start()
        else
            autoScroll.stop()
    }
    Timer {
        id: autoScroll
        interval: Theme.screenshotScrollInterval
        repeat: true
        onTriggered: {
            if (!root.tab || root._scrollDirection === 0) {
                stop()
                return
            }
            root.tab.scrollPageBy(root._scrollDirection * Theme.screenshotScrollStep, measured => {
                if (!measured)
                    return
                root.metrics = measured
                root.resize(root._edges, root._lastPoint)
            })
        }
    }

    // ── Capturar ─────────────────────────────────────────────────────
    // `action`: "copy" o "save". Si la selección no cabe en la ventana, por
    // trozos: desplaza, espera a que la página se pinte, copia y sigue
    property var _afterDelay: null
    Timer {
        id: sliceDelay
        interval: Theme.screenshotSliceDelay
        onTriggered: {
            const next = root._afterDelay
            root._afterDelay = null
            if (next)
                next()
        }
    }

    function capture(action) {
        if (!selection || !tab || !source || selection.w <= 0 || selection.h <= 0)
            return
        mode = "capturing"
        const sel = selection
        const z = zoom
        const ratio = dpr
        const offset = tab.mapToItem(source, 0, 0)
        const startScroll = metrics ? metrics.scrollY : 0
        const pixel = value => Math.round(value * z * ratio)
        Screenshot.begin(pixel(sel.w), pixel(sel.h), ratio)
        let next = sel.y        // Siguiente línea del documento por capturar
        // Lo que la página fija en pantalla (cabeceras…) se oculta en cada
        // trozo salvo con la página arriba del todo, donde está en su sitio:
        // si no, taparía el contenido y saldría repetido
        let hidFloating = false
        const floating = (hidden, then) => {
            if (hidFloating === hidden) {
                then()
                return
            }
            hidFloating = hidden
            root.tab.setFloatingHidden(hidden, then)
        }

        const finish = ok => {
            const done = () => {
                root.tab.scrollPageTo(startScroll, measured => {
                    if (measured)
                        root.metrics = measured
                    root.deliver(ok ? action : "")
                })
            }
            if (hidFloating)
                root.tab.setFloatingHidden(false, done)
            else
                done()
        }
        // Se llaman entre sí: declarada antes, definida después
        let scrollAndGrab = null
        const grabSlice = measured => {
            root.metrics = measured
            root.source.grabToImage(result => {
                const top = Math.max(next, measured.scrollY)
                const bottom = Math.min(sel.y + sel.h, measured.scrollY + measured.height)
                if (bottom <= top) {
                    finish(false)
                    return
                }
                const targetTop = Math.round((top - sel.y) * z * ratio)
                const targetBottom = Math.round((bottom - sel.y) * z * ratio)
                const area = Qt.rect(Math.round((offset.x + (sel.x - measured.scrollX) * z) * ratio),
                                     Math.round((offset.y + (top - measured.scrollY) * z) * ratio),
                                     pixel(sel.w), targetBottom - targetTop)
                Screenshot.paste(result.image, area, targetTop)
                next = bottom
                if (next >= sel.y + sel.h - 0.5)
                    finish(true)
                else
                    scrollAndGrab()
            }, Qt.size(Math.round(root.source.width * ratio), Math.round(root.source.height * ratio)))
        }
        scrollAndGrab = () => {
            root.tab.scrollPageTo(next, measured => {
                if (!measured) {
                    finish(false)
                    return
                }
                floating(measured.scrollY > 0, () => {
                    // Esperar a que la página se vuelva a pintar
                    root._afterDelay = () => grabSlice(measured)
                    sliceDelay.restart()
                })
            })
        }

        // Cabe en lo que se ve: tal como se ve, sin desplazar ni ocultar nada
        refresh(() => {
            const m = root.metrics
            if (sel.y >= m.scrollY && sel.y + sel.h <= m.scrollY + m.height)
                grabSlice(m)
            else
                scrollAndGrab()
        })
    }

    function deliver(action) {
        if (action === "copy") {
            notice = Screenshot.copy() ? "Captura copiada" : "No se pudo copiar la captura"
        } else if (action === "save") {
            const folder = BrowserProfile.downloadPath
            const saved = Screenshot.save(folder)
            if (saved.path) {
                // En la lista de descargas, ya terminada: desde ahí se abre
                const id = Downloads.add({ fileName: saved.fileName, path: saved.path, folder: folder,
                                           url: tab ? tab.url.toString() : "", total: saved.bytes,
                                           privateMode: tab ? tab.privateMode : false }, null)
                Downloads.update(id, { received: saved.bytes, state: "done" })
                notice = "Captura guardada en descargas"
            } else {
                notice = "No se pudo guardar la captura"
            }
        } else {
            notice = "No se pudo hacer la captura"
        }
        Screenshot.clear()
        mode = "done"
        noticeHold.restart()
    }
    Timer {
        id: noticeHold
        interval: Theme.screenshotNoticeHold
        onTriggered: root.close()
    }

    visible: active
    focus: active
    Keys.onEscapePressed: root.close()

    // ── Dibujo ───────────────────────────────────────────────────────
    // Lo que no entra, oscurecido: cuatro franjas alrededor del hueco
    readonly property rect focusRect: {
        const r = mode === "hover" ? hovered
                : (mode === "drag" || mode === "selected" || mode === "capturing") ? selection : null
        if (!r)
            return Qt.rect(0, 0, 0, 0)
        const v = toView(r)
        const left = Math.max(0, v.x)
        const top = Math.max(0, v.y)
        const right = Math.min(width, v.x + v.width)
        const bottom = Math.min(height, v.y + v.height)
        return Qt.rect(left, top, Math.max(0, right - left), Math.max(0, bottom - top))
    }
    readonly property bool hasFocusRect: focusRect.width > 0 && focusRect.height > 0

    Rectangle {
        visible: root.mode !== "done"
        x: 0; y: 0; width: root.width
        height: root.hasFocusRect ? root.focusRect.y : root.height
        color: Theme.screenshotDim
    }
    Rectangle {
        visible: root.hasFocusRect && root.mode !== "done"
        x: 0; y: root.focusRect.y + root.focusRect.height; width: root.width
        height: root.height - y
        color: Theme.screenshotDim
    }
    Rectangle {
        visible: root.hasFocusRect && root.mode !== "done"
        x: 0; y: root.focusRect.y; width: root.focusRect.x; height: root.focusRect.height
        color: Theme.screenshotDim
    }
    Rectangle {
        visible: root.hasFocusRect && root.mode !== "done"
        x: root.focusRect.x + root.focusRect.width; y: root.focusRect.y
        width: root.width - x; height: root.focusRect.height
        color: Theme.screenshotDim
    }

    // Elegir: resaltar al pasar, clic o arrastrar; la rueda desplaza la página
    MouseArea {
        id: picker
        anchors.fill: parent
        enabled: root.mode === "hover" || root.mode === "drag" || root.mode === "selected"
        hoverEnabled: true
        cursorShape: Qt.CrossCursor
        property point start: Qt.point(0, 0)

        onPositionChanged: mouse => {
            if (root.mode === "hover") {
                root.querySection(Qt.point(mouse.x, mouse.y))
            } else if (root.mode === "drag" && pressed) {
                const x1 = root.docX(Math.min(start.x, mouse.x))
                const y1 = root.docY(Math.min(start.y, mouse.y))
                const x2 = root.docX(Math.max(start.x, mouse.x))
                const y2 = root.docY(Math.max(start.y, mouse.y))
                root.selection = root.clamp({ x: x1, y: y1, w: x2 - x1, h: y2 - y1 })
            }
        }
        onPressed: mouse => {
            start = Qt.point(mouse.x, mouse.y)
            root.selection = null
            root.mode = "drag"
        }
        onReleased: mouse => {
            if (root.mode !== "drag")
                return
            const small = Math.abs(mouse.x - start.x) < Theme.screenshotMinSize
                          && Math.abs(mouse.y - start.y) < Theme.screenshotMinSize
            // Un clic: la sección resaltada o, si no hay, lo visible
            if (small)
                root.selection = root.hovered ?? root.clamp(root.visibleArea())
            root.mode = "selected"
        }
        onWheel: wheel => {
            if (!root.tab)
                return
            root.tab.scrollPageBy(-wheel.angleDelta.y / 120 * Theme.screenshotScrollStep * 2.5, measured => {
                if (measured)
                    root.metrics = measured
                if (root.mode === "hover")
                    root.querySection(root._pendingPoint)
            })
        }
    }

    // Sección bajo el ratón
    Rectangle {
        visible: root.mode === "hover" && root.hasFocusRect
        x: root.focusRect.x
        y: root.focusRect.y
        width: root.focusRect.width
        height: root.focusRect.height
        color: Theme.screenshotHoverFill
        border.width: Theme.screenshotBorder
        border.color: Theme.brandLight1
        radius: Theme.radiusSmall
    }

    // Selección: marco, mover arrastrando y tiradores
    Item {
        id: frame
        visible: root.selection !== null && (root.mode === "drag" || root.mode === "selected"
                                             || root.mode === "capturing")
        readonly property rect area: root.toView(root.selection)
        x: area.x
        y: area.y
        width: area.width
        height: area.height

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: Theme.screenshotBorder
            border.color: Theme.brandLight1
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.mode === "selected"
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point grab: Qt.point(0, 0)
            property var original: null
            onPressed: mouse => {
                grab = mapToItem(root, mouse.x, mouse.y)
                original = root.selection
            }
            onPositionChanged: mouse => {
                if (!pressed || !original)
                    return
                const p = mapToItem(root, mouse.x, mouse.y)
                const moved = { x: original.x + (p.x - grab.x) / root.zoom, y: original.y + (p.y - grab.y) / root.zoom,
                                w: original.w, h: original.h }
                // Sin encoger al llegar al borde del documento
                moved.x = Math.max(root.metrics.scrollX, Math.min(moved.x, root.metrics.scrollX + root.metrics.width - moved.w))
                moved.y = Math.max(0, Math.min(moved.y, root.metrics.pageHeight - moved.h))
                root.selection = moved
            }
        }

        Repeater {
            // Esquinas y lados: bordes que mueve y dónde va (fracción del marco)
            model: [
                { edges: 5, fx: 0, fy: 0, cursor: Qt.SizeFDiagCursor },
                { edges: 4, fx: 0.5, fy: 0, cursor: Qt.SizeVerCursor },
                { edges: 6, fx: 1, fy: 0, cursor: Qt.SizeBDiagCursor },
                { edges: 2, fx: 1, fy: 0.5, cursor: Qt.SizeHorCursor },
                { edges: 10, fx: 1, fy: 1, cursor: Qt.SizeFDiagCursor },
                { edges: 8, fx: 0.5, fy: 1, cursor: Qt.SizeVerCursor },
                { edges: 9, fx: 0, fy: 1, cursor: Qt.SizeBDiagCursor },
                { edges: 1, fx: 0, fy: 0.5, cursor: Qt.SizeHorCursor }
            ]
            delegate: Rectangle {
                id: handle
                required property var modelData
                visible: root.mode === "selected"
                width: Theme.screenshotHandle
                height: Theme.screenshotHandle
                radius: width / 2
                x: frame.width * modelData.fx - width / 2
                y: frame.height * modelData.fy - height / 2
                color: Theme.onBrand
                border.width: Theme.screenshotBorder
                border.color: Theme.brandLight1

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.spacing / 2
                    preventStealing: true
                    cursorShape: handle.modelData.cursor
                    onPositionChanged: mouse => {
                        if (pressed)
                            root.dragEdge(handle.modelData.edges, mapToItem(root, mouse.x, mouse.y))
                    }
                    onReleased: autoScroll.stop()
                }
            }
        }
    }

    // ── Barra de arriba: qué hacer y atajos ──────────────────────────
    Surface {
        id: topBar
        visible: root.mode === "hover" || root.mode === "drag" || root.mode === "selected"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.margin * 2
        width: topRow.implicitWidth + 2 * Theme.margin
        height: Theme.controlHeight + Theme.spacing
        radius: height / 2
        fill: Theme.surfacePopup

        Row {
            id: topRow
            anchors.centerIn: parent
            spacing: Theme.spacing

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "screenshot"
                color: Theme.brandLight1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.mode === "selected"
                      ? "Ajusta los bordes; llévalos al borde de la ventana para ampliar"
                      : "Elige una sección o arrastra para seleccionar un área"
                color: Theme.ink
                font.pixelSize: Theme.fontSize
            }
            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Página visible"
                onClicked: root.selectVisible()
            }
            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Página completa"
                onClicked: root.selectWholePage()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                flat: true
                icon: "close"
                iconSize: Theme.iconSizeSmall
                implicitWidth: Theme.buttonSizeSmall
                implicitHeight: Theme.buttonSizeSmall
                tooltip: "Cancelar"
                shortcut: "Esc"
                tooltipBelow: true
                onClicked: root.close()
            }
        }
    }

    // ── Acciones bajo la selección ───────────────────────────────────
    Surface {
        id: actions
        visible: root.mode === "selected" && root.selection !== null
        width: actionRow.implicitWidth + 2 * Theme.margin
        height: Theme.controlHeight + Theme.spacing
        radius: height / 2
        fill: Theme.surfacePopup
        // Debajo de la selección; si no cabe, dentro de ella, abajo
        x: Math.max(Theme.margin, Math.min(root.width - width - Theme.margin,
                                           frame.x + frame.width / 2 - width / 2))
        y: {
            const below = frame.y + frame.height + Theme.spacing
            const inside = Math.min(root.height, frame.y + frame.height) - height - Theme.spacing
            return below + height <= root.height - Theme.margin ? below : Math.max(Theme.margin, inside)
        }

        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: Theme.spacing

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.selection
                      ? Math.round(root.selection.w * root.zoom * root.dpr) + " × "
                        + Math.round(root.selection.h * root.zoom * root.dpr) + " px"
                      : ""
                color: Theme.inkSecondary
                font.pixelSize: Theme.fontSizeSmall
                rightPadding: Theme.spacing
            }
            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Cancelar"
                onClicked: root.close()
            }
            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Copiar"
                onClicked: root.capture("copy")
            }
            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Guardar"
                primary: true
                onClicked: root.capture("save")
            }
        }
    }

    // ── Capturando y aviso final ─────────────────────────────────────
    Surface {
        visible: root.mode === "capturing" || root.mode === "done"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.margin * 2
        width: noticeText.implicitWidth + 2 * Theme.margin
        height: Theme.controlHeight
        radius: height / 2
        fill: Theme.surfacePopup

        Text {
            id: noticeText
            anchors.centerIn: parent
            text: root.mode === "capturing" ? "Capturando…" : root.notice
            color: Theme.ink
            font.pixelSize: Theme.fontSize
        }
    }
}

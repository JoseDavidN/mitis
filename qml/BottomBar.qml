import QtQuick
import Mitis.Core

// Controles inferiores: botones y campo de dirección independientes que
// flotan sobre la página, sin barra de fondo. Los huecos entre ellos dejan
// pasar los clics a la página.
// Botones y campo forman un solo grupo centrado: los botones van pegados
// al campo con la misma separación, sea pequeño o grande.
// Comparten un solo degradado (controlsStart → controlsEnd) de lado a lado
// del grupo: cada control pinta el tramo que le toca según su posición.
Item {
    id: root

    // Estado de la pestaña activa
    property url currentUrl
    // Pestañas de la ventana y la actual, para las sugerencias de la dirección
    property var openTabs: null
    property int currentTabIndex: -1
    property string pageTitle: ""
    property bool canGoBack: false
    property bool canGoForward: false
    property bool loading: false
    property int loadProgress: 0
    property int tabCount: 1
    // Conexión de la página (ver AddressBar.security)
    property string security: ""
    // La página actual está en marcadores: la estrella se ilumina
    property bool bookmarked: false

    // Descargas: el botón solo se ve con `downloadsShown`. Con el panel
    // cerrado y la descarga en curso (`download`, roles de Downloads), un
    // anillo alrededor del botón muestra el progreso.
    property bool downloadsShown: false
    property var download: null
    property bool downloadPanelOpen: false
    // Hay una versión nueva de Mitis: botón de actualizar tras Opciones
    property bool updateAvailable: false

    // Tamaño elegido (Configuración → Apariencia): factor sobre las medidas
    // de Theme para botones, iconos y campo de dirección
    readonly property real sizeScale: Theme.controlsScales[Settings.controlsSize] ?? 1
    readonly property int buttonSize: Math.round(Theme.buttonSize * sizeScale)
    readonly property int iconSize: Math.round(Theme.iconSize * sizeScale)
    readonly property int controlHeight: Math.round(Theme.controlHeight * sizeScale)

    // Botones para anclar las listas desplegables
    readonly property Item downloadsButton: downloadsButton
    readonly property Item tabsButton: tabsButton
    readonly property Item bookmarksButton: bookmarksButton
    readonly property Item optionsButton: optionsButton
    readonly property Item updateButton: updateButton
    readonly property Item addressField: address
    // Se está escribiendo en el campo de dirección
    readonly property bool editing: address.editing

    signal backRequested()
    signal forwardRequested()
    signal reloadRequested()
    signal stopRequested()
    signal navigateRequested(url target)
    // «Ir a la pestaña» en las sugerencias de la dirección
    signal tabRequested(int index, string url)
    signal downloadsRequested()
    signal tabsRequested()
    signal bookmarksRequested()
    signal optionsRequested()
    signal updateRequested()
    signal siteInfoRequested()

    function focusAddress() {
        address.focusAndSelect()
    }

    // Color del degradado compartido en la posición x del grupo
    function tone(x) {
        const t = cluster.width > 0 ? Math.max(0, Math.min(1, x / cluster.width)) : 0
        const a = Colors.controlsStart
        const b = Colors.controlsEnd
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
    }

    implicitHeight: root.controlHeight + 2 * Theme.floatingMargin

    // Espacio máximo que puede ocupar el grupo
    readonly property real maxWidth: Math.min(width - 2 * Theme.floatingMargin, Theme.bottomBarMaxWidth)

    Item {
        id: cluster

        // Separación entre el campo y los botones, igual en ambos modos
        readonly property real gap: 2 * Theme.spacing
        // Ancho máximo del campo de dirección: lo que dejan los botones
        readonly property real available: root.maxWidth - leftGroup.width - downloadsSlot.width
                                          - rightGroup.width - 2 * gap

        anchors.centerIn: parent
        width: leftGroup.width + address.width + downloadsSlot.width + rightGroup.width + 2 * gap
        height: root.controlHeight

        Row {
            id: leftGroup
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing

            IconButton {
                width: root.buttonSize
                height: root.buttonSize
                iconSize: root.iconSize
                fillStart: root.tone(leftGroup.x + x)
                fillEnd: root.tone(leftGroup.x + x + width)
                icon: "back"
                tooltip: "Atrás"
                shortcut: "Alt+←"
                enabled: root.canGoBack
                onClicked: root.backRequested()
            }
            IconButton {
                width: root.buttonSize
                height: root.buttonSize
                iconSize: root.iconSize
                fillStart: root.tone(leftGroup.x + x)
                fillEnd: root.tone(leftGroup.x + x + width)
                icon: "forward"
                tooltip: "Adelante"
                shortcut: "Alt+→"
                enabled: root.canGoForward
                onClicked: root.forwardRequested()
            }
            IconButton {
                width: root.buttonSize
                height: root.buttonSize
                iconSize: root.iconSize
                fillStart: root.tone(leftGroup.x + x)
                fillEnd: root.tone(leftGroup.x + x + width)
                icon: root.loading ? "close" : "reload"
                tooltip: root.loading ? "Detener" : "Recargar"
                shortcut: root.loading ? "" : "Ctrl+R"
                onClicked: root.loading ? root.stopRequested() : root.reloadRequested()
            }
        }

        // Ocupa todo el espacio al escribir; en reposo se encoge al título
        AddressBar {
            id: address
            sizeScale: root.sizeScale
            anchors.verticalCenter: parent.verticalCenter
            width: editing ? cluster.available : Math.min(compactWidth, cluster.available)
            x: leftGroup.width + cluster.gap
            fillStart: root.tone(x)
            fillEnd: root.tone(x + width)
            currentUrl: root.currentUrl
            pageTitle: root.pageTitle
            loading: root.loading
            loadProgress: root.loadProgress
            security: root.security
            onNavigate: target => root.navigateRequested(target)
            onSiteInfoRequested: root.siteInfoRequested()
            openTabs: root.openTabs
            currentTabIndex: root.currentTabIndex
            onTabRequested: (index, url) => root.tabRequested(index, url)

            // Se anima solo al empezar o dejar de escribir. Su ancho depende
            // también del de la ventana: animarlo al redimensionar lo hacía ir
            // siempre por detrás, buscando acomodarse.
            property bool animateWidth: false
            onEditingChanged: {
                animateWidth = true
                widthAnimationEnd.restart()
            }
            Timer {
                id: widthAnimationEnd
                interval: Theme.durationBase
                onTriggered: address.animateWidth = false
            }

            Behavior on width {
                enabled: address.animateWidth
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeOut
                }
            }
        }

        // Hueco del botón de descargas, justo antes de pestañas. Aparece y
        // desaparece animando su ancho: el grupo se recentra sin saltos.
        Item {
            id: downloadsSlot

            // 0 oculto, 1 visible
            property real reveal: root.downloadsShown ? 1 : 0
            Behavior on reveal {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeOut
                }
            }

            anchors.right: rightGroup.left
            anchors.verticalCenter: parent.verticalCenter
            width: reveal * (root.buttonSize + Theme.spacing)
            height: root.buttonSize
            // Solo recorta mientras se anima (el recorte también corta los clics)
            clip: reveal < 1

            readonly property var download: root.download
            readonly property bool downloading: download !== null
                                                && (download.state === "progress" || download.state === "paused")

            IconButton {
                id: downloadsButton
                width: root.buttonSize
                height: root.buttonSize
                iconSize: root.iconSize
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                opacity: downloadsSlot.reveal
                fillStart: root.tone(downloadsSlot.x + x)
                fillEnd: root.tone(downloadsSlot.x + x + width)
                icon: "downloads"
                tooltip: "Descargas"
                onClicked: if (root.downloadsShown) root.downloadsRequested()
            }

            // Progreso con el panel cerrado, sobre el borde del botón
            ProgressRing {
                anchors.fill: downloadsButton
                visible: opacity > 0
                opacity: downloadsSlot.downloading && !root.downloadPanelOpen ? downloadsSlot.reveal : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
                // Acompaña al botón al pasar por encima y al pulsar
                scale: downloadsButton.pressed ? Theme.pressScale
                                               : (downloadsButton.hovered ? Theme.hoverScale : 1.0)
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durationFast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.easeInOut
                    }
                }
                value: downloadsSlot.download && downloadsSlot.download.total > 0
                       ? downloadsSlot.download.received / downloadsSlot.download.total : 0
                indeterminate: downloadsSlot.downloading && downloadsSlot.download.state === "progress"
                               && !(downloadsSlot.download.total > 0)
                color: downloadsSlot.downloading && downloadsSlot.download.state === "paused"
                       ? Colors.inkMuted : Colors.brandLight1
            }
        }

        Row {
            id: rightGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing

            IconButton {
                id: tabsButton
                width: root.buttonSize
                height: root.buttonSize
                iconSize: root.iconSize
                fillStart: root.tone(rightGroup.x + x)
                fillEnd: root.tone(rightGroup.x + x + width)
                icon: "tabs"
                // Cuántas hay, en el tooltip (el botón lleva el icono, no el número)
                tooltip: "Pestañas (" + root.tabCount + ")"
                shortcut: "Ctrl+Shift+A"
                onClicked: root.tabsRequested()
            }
            IconButton {
                id: bookmarksButton
                width: root.buttonSize
                height: root.buttonSize
                iconSize: root.iconSize
                fillStart: root.tone(rightGroup.x + x)
                fillEnd: root.tone(rightGroup.x + x + width)
                icon: "bookmarks"
                highlighted: root.bookmarked
                tooltip: "Marcadores"
                onClicked: root.bookmarksRequested()
            }
            IconButton {
                id: optionsButton
                width: root.buttonSize
                height: root.buttonSize
                iconSize: root.iconSize
                fillStart: root.tone(rightGroup.x + x)
                fillEnd: root.tone(rightGroup.x + x + width)
                icon: "options"
                tooltip: "Opciones"
                onClicked: root.optionsRequested()
            }
            UpdateButton {
                id: updateButton
                width: root.buttonSize
                height: root.buttonSize
                iconSize: root.iconSize
                visible: root.updateAvailable
                fillStart: root.tone(rightGroup.x + x)
                fillEnd: root.tone(rightGroup.x + x + width)
                onClicked: root.updateRequested()
            }
        }
    }
}

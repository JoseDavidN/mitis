pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

import "urls.js" as Urls

// Panel del sitio (botón del candado del campo de dirección), como el de
// Zen: en un solo sitio, la conexión (al desplegarla, el certificado y quién
// lo emitió), la protección contra rastreadores del sitio y acciones con la
// página: marcadores, copiar el enlace, enviarlo por correo y permisos.
// Se abre hacia arriba, sobre el campo.
Popup {
    id: root

    // Página de la pestaña activa
    property string pageUrl: ""
    property string pageTitle: ""
    property url pageIcon
    // "secure", "insecure" u "overridden" (ver AddressBar.security)
    property string security: ""

    // Cambió la protección del sitio: hay que recargar para aplicarla
    signal reloadRequested()
    signal settingsRequested(string section)

    readonly property string host: Urls.host(pageUrl)
    readonly property string site: /^https?:/.test(pageUrl) ? BrowserProfile.siteOf(pageUrl) : ""
    readonly property bool bookmarked: Bookmarks.urls.indexOf(pageUrl) >= 0

    // Bloqueador: activado en Configuración y no permitido en este sitio
    readonly property bool protectedSite: Settings.blockAds && !Settings.adBlockAllowedSites.includes(site)

    // Certificado: se pide al desplegar la conexión. null = consultando
    property bool certificateOpen: false
    property var certificate: null
    property bool copied: false

    function toggleCertificate() {
        if (security === "insecure")
            return
        certificateOpen = !certificateOpen
        if (certificateOpen && certificate === null)
            BrowserProfile.requestCertificate(host)
    }

    function toggleProtection() {
        if (site === "" || !Settings.blockAds)
            return
        const allowed = Settings.adBlockAllowedSites
        Settings.adBlockAllowedSites = protectedSite ? allowed.concat([site]).sort()
                                                     : allowed.filter(item => item !== site)
        reloadRequested()
    }

    function formatDate(value) {
        if (!value || isNaN(value.getTime()))
            return ""
        return value.toLocaleDateString(Qt.locale("es_ES"), "d 'de' MMMM 'de' yyyy")
    }

    width: Theme.popupWidth
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

    onAboutToShow: {
        certificateOpen = false
        certificate = null
        copied = false
    }

    Connections {
        target: BrowserProfile
        function onCertificateReady(host, certificate) {
            if (host === root.host)
                root.certificate = certificate
        }
    }

    // Copiar al portapapeles sin C++: un campo de texto invisible
    TextEdit {
        id: clipboardHelper
        visible: false
    }
    Timer {
        id: copiedReset
        interval: Theme.siteInfoCopiedHold
        onTriggered: root.copied = false
    }

    contentItem: Column {
        spacing: Theme.spacing / 2

        // ── Sitio ────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: Theme.popupRowHeight + Theme.spacing

            Image {
                id: favicon
                anchors.left: parent.left
                anchors.leftMargin: Theme.margin
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.faviconSize
                height: Theme.faviconSize
                sourceSize: Qt.size(2 * Theme.faviconSize, 2 * Theme.faviconSize)
                source: root.pageIcon
                visible: status === Image.Ready
                smooth: true
                mipmap: true
            }
            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.margin + (favicon.visible ? Theme.faviconSize + Theme.spacing : 0)
                anchors.right: parent.right
                anchors.rightMargin: Theme.margin
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    text: root.host
                    color: Theme.ink
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.pageTitle
                    color: Theme.inkMuted
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.line }

        // ── Conexión (al pulsarla, el certificado) ───────────────────
        StatusRow {
            width: parent.width
            icon: root.security === "secure" ? "site-secure" : "site-insecure"
            tone: root.security === "secure" ? Theme.ok : root.security === "insecure" ? Theme.warn : Theme.danger
            title: root.security === "secure" ? "Conexión segura"
                 : root.security === "insecure" ? "Conexión no segura" : "Certificado no válido"
            detail: root.security === "secure" ? "Lo que envíes y recibas viaja cifrado."
                  : root.security === "insecure" ? "Sin cifrar: no escribas contraseñas ni datos de pago aquí."
                  : "Elegiste continuar aunque el certificado no es válido: la conexión está cifrada, pero no se sabe con quién."
            expandable: root.security !== "insecure"
            expanded: root.certificateOpen
            onClicked: root.toggleCertificate()
        }

        // Certificado: quién lo emitió, para quién, validez y problemas
        Column {
            visible: root.certificateOpen
            width: parent.width
            leftPadding: Theme.margin + Theme.iconSize + Theme.spacing
            rightPadding: Theme.margin
            bottomPadding: Theme.spacing
            spacing: Theme.spacing / 2

            readonly property real textWidth: width - leftPadding - rightPadding

            Text {
                visible: root.certificate === null || root.certificate.error !== undefined
                width: parent.textWidth
                text: root.certificate === null ? "Comprobando el certificado…" : (root.certificate.error ?? "")
                color: Theme.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
            Detail {
                width: parent.textWidth
                visible: root.certificate !== null && root.certificate.error === undefined
                label: "Verificado por"
                value: root.certificate && root.certificate.error === undefined
                       ? (root.certificate.issuer || root.certificate.issuerName || "Desconocido")
                         + (root.certificate.issuer && root.certificate.issuerName
                            ? " (" + root.certificate.issuerName + ")" : "")
                       : ""
            }
            Detail {
                width: parent.textWidth
                visible: root.certificate !== null && root.certificate.error === undefined
                label: "Emitido para"
                value: root.certificate && root.certificate.error === undefined
                       ? (root.certificate.subject || root.host)
                         + (root.certificate.subjectOrganization ? " · " + root.certificate.subjectOrganization : "")
                       : ""
            }
            Detail {
                width: parent.textWidth
                visible: root.certificate !== null && root.certificate.error === undefined
                label: "Válido"
                value: root.certificate && root.certificate.error === undefined
                       ? "Del " + root.formatDate(root.certificate.validFrom)
                         + " al " + root.formatDate(root.certificate.validTo)
                       : ""
            }
            Detail {
                width: parent.textWidth
                visible: root.certificate !== null && root.certificate.error === undefined
                         && (root.certificate.protocol ?? "") !== ""
                label: "Protocolo"
                value: root.certificate && root.certificate.protocol ? root.certificate.protocol : ""
            }
            Text {
                visible: root.certificate !== null && root.certificate.error === undefined
                         && (root.certificate.errors ?? []).length > 0
                width: parent.textWidth
                text: root.certificate && root.certificate.errors ? root.certificate.errors.join("\n") : ""
                color: Theme.danger
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
        }

        // ── Rastreadores ─────────────────────────────────────────────
        StatusRow {
            width: parent.width
            icon: "blocker"
            tone: root.protectedSite ? Theme.ok : Theme.inkMuted
            title: "Protección contra rastreadores"
            detail: !Settings.blockAds ? "Desactivada en Configuración."
                  : root.protectedSite ? "Activada en este sitio." : "Desactivada en este sitio."
            showToggle: Settings.blockAds && root.site !== ""
            toggleChecked: root.protectedSite
            onClicked: root.toggleProtection()
        }

        Rectangle { width: parent.width; height: 1; color: Theme.line }

        // ── Acciones con la página ───────────────────────────────────
        PopupAction {
            width: parent.width
            icon: root.bookmarked ? "bookmark" : "bookmark-add"
            text: root.bookmarked ? "Quitar de marcadores" : "Añadir a marcadores"
            shortcut: "Ctrl+D"
            onTriggered: root.bookmarked ? Bookmarks.remove(root.pageUrl) : Bookmarks.add(root.pageUrl, root.pageTitle)
        }
        PopupAction {
            width: parent.width
            icon: "copy-link"
            text: root.copied ? "Enlace copiado" : "Copiar enlace"
            onTriggered: {
                clipboardHelper.text = root.pageUrl
                clipboardHelper.selectAll()
                clipboardHelper.copy()
                root.copied = true
                copiedReset.restart()
            }
        }
        PopupAction {
            width: parent.width
            icon: "share-mail"
            text: "Enviar por correo"
            onTriggered: {
                Qt.openUrlExternally("mailto:?subject=" + encodeURIComponent(root.pageTitle || root.host)
                                     + "&body=" + encodeURIComponent(root.pageUrl))
                root.close()
            }
        }
        PopupAction {
            width: parent.width
            icon: "permissions"
            text: "Permisos de sitios"
            onTriggered: {
                root.close()
                root.settingsRequested("permissions")
            }
        }
    }

    // Fila de estado: icono de color, título y detalle; pulsable (despliega
    // algo o cambia un interruptor)
    component StatusRow: Item {
        id: row

        property string icon: ""
        property color tone: Theme.inkSoft
        property string title: ""
        property string detail: ""
        property bool expandable: false
        property bool expanded: false
        property bool showToggle: false
        property bool toggleChecked: false

        signal clicked()

        implicitHeight: Math.max(Theme.popupRowHeight, texts.implicitHeight + 2 * Theme.spacing)

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: rowHover.hovered && (row.expandable || row.showToggle) ? Theme.tintHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
        Icon {
            id: rowIcon
            anchors.left: parent.left
            anchors.leftMargin: Theme.margin
            anchors.top: parent.top
            anchors.topMargin: Theme.spacing + 1
            name: row.icon
            color: row.tone
        }
        Column {
            id: texts
            anchors.left: rowIcon.right
            anchors.leftMargin: Theme.spacing
            anchors.right: trailing.left
            anchors.rightMargin: Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: row.title
                color: Theme.ink
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: row.detail
                color: Theme.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
        }
        Item {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter
            width: row.showToggle ? Theme.toggleWidth : (row.expandable ? Theme.iconSizeSmall : 0)
            height: Theme.toggleHeight

            Icon {
                visible: row.expandable
                anchors.centerIn: parent
                name: "expand"
                size: Theme.iconSizeSmall
                color: Theme.inkMuted
                rotation: row.expanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: Theme.durationFast } }
            }
            Toggle {
                id: rowToggle
                visible: row.showToggle
                anchors.fill: parent
                checked: row.toggleChecked
                // Toggle cambia su `checked` al pulsarlo: se vuelve a enlazar
                // para que siga al valor real (también si se pulsa la fila)
                onToggled: {
                    rowToggle.checked = Qt.binding(() => row.toggleChecked)
                    row.clicked()
                }
            }
        }
        HoverHandler {
            id: rowHover
            cursorShape: row.expandable || row.showToggle ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
        TapHandler {
            enabled: row.expandable || row.showToggle
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: row.clicked()
        }
    }

    // Dato del certificado: etiqueta pequeña y valor debajo
    component Detail: Column {
        property string label: ""
        property string value: ""

        spacing: 1

        Text {
            width: parent.width
            text: parent.label
            color: Theme.inkMuted
            font.pixelSize: Theme.fontSizeSmall
        }
        Text {
            width: parent.width
            text: parent.value
            color: Theme.ink
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
        }
    }
}

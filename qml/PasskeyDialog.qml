pragma ComponentBehavior: Bound
import QtQuick

// Llave de acceso (BrowserTab.passkey): con el móvil (QR que se escanea con la
// cámara; Mitis habla con él por Bluetooth y el servidor de enlace, ver
// src/hybrid.*) o con una llave física (USB/NFC: cuenta, PIN, tocar la llave).
// En un Loader del delegado de Main.qml: solo existe abierta.
PageDialog {
    id: root

    required property var tab
    readonly property var passkey: tab.passkey
    readonly property bool phone: passkey.mode === "phone"
    readonly property string step: passkey.state

    iconName: "security"
    cardWidth: Theme.passkeyWidth
    title: passkey.kind === "create" ? "Crear una llave de acceso" : "Usar una llave de acceso"
    message: {
        const site = passkey.site !== "" ? passkey.site : "Esta página"
        if (phone) {
            switch (step) {
            case "connecting": return "Conectando con el móvil…"
            case "confirm": return passkey.kind === "create"
                                   ? "Confirma en el móvil que quieres guardar la llave de " + site + "."
                                   : "Confirma en el móvil para entrar en " + site + "."
            case "bluetoothOff": return "El Bluetooth de este equipo está apagado. Hace falta para usar el móvil: el móvil tiene que estar cerca."
            case "noBluetooth": return "Este equipo no tiene Bluetooth, que hace falta para usar el móvil. Puedes usar una llave de seguridad."
            default: return "Escanea el código con la cámara del iPhone (o del Android) para usar la llave de acceso de " + site
                            + ". Ten el Bluetooth encendido en los dos."
            }
        }
        switch (step) {
        case "account": return "Elige la cuenta con la que entrar en " + site + "."
        case "pin": return root.pinMessage()
        case "failed": return root.failureMessage()
        default: return passkey.kind === "create"
                        ? "Conecta tu llave de seguridad y tócala para crear la llave de " + site + "."
                        : "Conecta tu llave de seguridad y tócala para entrar en " + site + "."
        }
    }

    function pinMessage() {
        const errors = {
            wrong: "El PIN no es correcto.",
            short: "El PIN es demasiado corto.",
            characters: "El PIN tiene caracteres que no valen.",
            same: "El PIN nuevo debe ser distinto del actual.",
            locked: "La llave está bloqueada: escribe su PIN."
        }
        const start = errors[passkey.pinError] ? errors[passkey.pinError] + " " : ""
        const attempts = passkey.pinAttempts > 0 && passkey.pinAttempts <= 3
                         ? " Te quedan " + passkey.pinAttempts + " intentos." : ""
        if (passkey.pinReason === "set")
            return start + "Elige un PIN para tu llave de seguridad (al menos " + passkey.pinMinLength + " caracteres)."
        if (passkey.pinReason === "change")
            return start + "Tu llave pide un PIN nuevo (al menos " + passkey.pinMinLength + " caracteres)."
        return start + "Escribe el PIN de tu llave de seguridad." + attempts
    }
    function failureMessage() {
        switch (passkey.failure) {
        case "timeout": return "Se acabó el tiempo. Vuelve a intentarlo."
        case "notRegistered": return "Esta llave no está registrada en este sitio. Prueba con otra."
        case "alreadyRegistered": return "Esta llave ya está registrada en este sitio."
        case "pinBlocked": return "La llave está bloqueada por demasiados intentos de PIN. Desconéctala y vuelve a conectarla."
        case "removed": return "Se desconectó la llave. Vuelve a conectarla."
        case "unsupported": return "Esta llave no admite lo que pide el sitio. Prueba con otra o con el móvil."
        case "storageFull": return "La llave no tiene espacio para otra llave de acceso."
        default: return "No se pudo usar la llave."
        }
    }

    Component.onCompleted: show()
    onRejected: root.tab.passkeyCancel()

    Column {
        width: parent.width
        spacing: Theme.spacing

        // Código QR (siempre negro sobre blanco: la cámara lo lee con cualquier tema)
        Rectangle {
            visible: root.phone && (root.step === "scanning" || root.step === "")
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.passkeyQrSize
            height: Theme.passkeyQrSize
            radius: Theme.radiusSmall
            color: Theme.qrLight

            Canvas {
                id: qr
                anchors.fill: parent
                anchors.margins: Theme.spacing
                // qmllint disable unqualified
                readonly property var code: root.passkey.qr !== "" ? MitisEngine.qrCode(root.passkey.qr) : null
                // qmllint enable unqualified
                onCodeChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (!code)
                        return
                    const cell = Math.floor(Math.min(width, height) / code.size)
                    const offset = (width - cell * code.size) / 2
                    ctx.fillStyle = Theme.qrDark
                    for (let y = 0; y < code.size; y++) {
                        for (let x = 0; x < code.size; x++) {
                            if (code.modules[y * code.size + x] === "1")
                                ctx.fillRect(offset + x * cell, offset + y * cell, cell, cell)
                        }
                    }
                }
            }
        }

        // Cuentas de la llave física
        Repeater {
            model: root.step === "account" ? root.passkey.accounts : []
            delegate: TextButton {
                required property string modelData
                width: parent.width
                text: modelData
                onClicked: root.tab.passkeySelectAccount(modelData)
            }
        }

        // PIN de la llave física
        FormField {
            id: pinField
            visible: root.step === "pin"
            width: parent.width
            echoMode: TextInput.Password
            placeholderText: "PIN"
            onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
            onAccepted: if (text.length >= root.passkey.pinMinLength) root.tab.passkeySetPin(text)
        }
    }

    buttons: [
        TextButton {
            visible: root.phone && root.step === "bluetoothOff"
            text: "Encender Bluetooth"
            onClicked: root.tab.passkeyBluetoothOn()
        },
        TextButton {
            visible: root.phone && root.step !== "connecting" && root.step !== "confirm"
            text: "Usar una llave de seguridad"
            onClicked: root.tab.passkeyUseKey()
        },
        TextButton {
            visible: !root.phone && root.step === "failed"
            text: "Reintentar"
            onClicked: root.tab.passkeyRetry()
        },
        TextButton {
            text: "Cancelar"
            onClicked: root.tab.passkeyCancel()
        },
        TextButton {
            visible: !root.phone && root.step === "pin"
            text: "Continuar"
            primary: true
            enabled: pinField.text.length >= root.passkey.pinMinLength
            onClicked: root.tab.passkeySetPin(pinField.text)
        }
    ]
}

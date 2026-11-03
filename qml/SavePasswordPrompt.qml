import QtQuick
import Mitis.Core

// ¿Guardar la contraseña? Tras iniciar sesión o registrarse en un sitio
// (BrowserTab.passwordEvent "submit"), arriba a la derecha de la página de su
// pestaña: se ve con ella y espera hasta que se responde, aunque la página
// cambie. El usuario y la contraseña se pueden corregir antes de guardar. Con
// el gestor bloqueado pide su contraseña aquí mismo; sin cuenta, la crea en la
// ventana del gestor (createRequested). En un Loader del delegado de Main.qml:
// solo existe mientras se ve.
FocusScope {
    id: root

    // { url, host, username, password }
    required property var credential

    // Guardada, descartada o «Nunca en este sitio»
    signal finished()
    signal neverRequested()
    // Sin cuenta: crearla en el gestor y guardar después esta
    signal createRequested(var credential)

    // "new" o "update" (otra contraseña para ese usuario); sin desbloquear, "new"
    // (Passwords.items, para recalcularlo al cambiar las guardadas)
    readonly property string mode: Passwords.unlocked && Passwords.items.length >= 0
        ? Passwords.stateFor(credential.url, usernameField.text, passwordField.text) : "new"
    property bool showPassword: false
    property bool waiting: false
    property string error: ""

    function save() {
        if (!Passwords.exists) {
            root.createRequested({ url: credential.url, host: credential.host,
                                   username: usernameField.text, password: passwordField.text })
            return
        }
        if (!Passwords.unlocked) {
            if (masterField.text === "" || Passwords.busy)
                return
            root.error = ""
            root.waiting = true
            Passwords.unlock(masterField.text)
            return
        }
        Passwords.save("", credential.url, usernameField.text, passwordField.text)
        root.finished()
    }

    Connections {
        target: Passwords
        enabled: root.waiting
        function onUnlockFinished(ok) {
            root.waiting = false
            if (ok) {
                root.save()
            } else {
                root.error = "La contraseña no es correcta."
                masterField.selectAll()
                masterField.forceActiveFocus()
            }
        }
    }

    width: Theme.savePasswordWidth
    height: body.implicitHeight + 2 * body.anchors.margins
    z: 9

    Keys.onEscapePressed: root.finished()

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
        id: body
        anchors.fill: parent
        anchors.margins: Theme.margin + Theme.spacing / 2
        spacing: Theme.spacing

        Item {
            width: parent.width
            height: Math.max(titleColumn.implicitHeight, closeButton.height)

            Icon {
                id: titleIcon
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 2
                name: "passwords"
                color: Colors.brandLight1
            }
            Column {
                id: titleColumn
                anchors.left: titleIcon.right
                anchors.leftMargin: Theme.spacing
                anchors.right: closeButton.left
                anchors.rightMargin: Theme.spacing

                Text {
                    width: parent.width
                    text: root.mode === "update" ? "¿Actualizar la contraseña?" : "¿Guardar la contraseña?"
                    color: Colors.ink
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }
                Text {
                    width: parent.width
                    text: root.credential.host
                    color: Colors.inkMuted
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                }
            }
            IconButton {
                id: closeButton
                anchors.right: parent.right
                anchors.top: parent.top
                width: Theme.buttonSizeSmall
                height: Theme.buttonSizeSmall
                iconSize: Theme.iconSizeSmall
                icon: "close"
                flat: true
                tooltip: "Ahora no"
                tooltipBelow: true
                onClicked: root.finished()
            }
        }

        FormField {
            id: usernameField
            width: parent.width
            text: root.credential.username
            placeholderText: "Usuario o correo"
        }

        FormField {
            id: passwordField
            width: parent.width
            text: root.credential.password
            echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
            font.family: root.showPassword ? Theme.monospaceFont : Theme.interfaceFont
            rightPadding: Theme.buttonSizeSmall + Theme.spacing
            placeholderText: "Contraseña"

            IconButton {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing / 2
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.buttonSizeSmall
                height: Theme.buttonSizeSmall
                iconSize: Theme.iconSizeSmall
                icon: root.showPassword ? "hide-password" : "show-password"
                flat: true
                tooltip: root.showPassword ? "Ocultar" : "Mostrar"
                onClicked: root.showPassword = !root.showPassword
            }
        }

        // Gestor bloqueado: su contraseña, aquí mismo
        Text {
            width: parent.width
            visible: Passwords.exists && !Passwords.unlocked
            text: "Escribe la contraseña de tu gestor (" + Passwords.user + ") para guardarla."
            color: Colors.inkSoft
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }
        FormField {
            id: masterField
            width: parent.width
            visible: Passwords.exists && !Passwords.unlocked
            echoMode: TextInput.Password
            placeholderText: "Contraseña del gestor"
            enabled: !root.waiting
            onAccepted: root.save()
        }
        Text {
            width: parent.width
            visible: root.error !== "" || root.waiting
            text: root.waiting ? "Comprobando…" : root.error
            color: root.waiting ? Colors.inkMuted : Colors.danger
            font.pixelSize: Theme.fontSizeSmall
        }
        // Sin cuenta: se crea en la ventana del gestor
        Text {
            width: parent.width
            visible: !Passwords.exists
            text: "Para guardar contraseñas, crea antes tu cuenta del gestor."
            color: Colors.inkSoft
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }

        Item {
            width: parent.width
            height: Theme.textButtonHeight

            TextButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.mode !== "update"
                text: "Nunca aquí"
                onClicked: root.neverRequested()
            }
            TextButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                primary: true
                enabled: passwordField.text !== "" && !root.waiting
                text: !Passwords.exists ? "Crear cuenta"
                    : root.mode === "update" ? "Actualizar" : "Guardar"
                onClicked: root.save()
            }
        }
    }
}

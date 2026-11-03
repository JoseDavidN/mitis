pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Mitis.Core

import "urls.js" as Urls

// Ventana del gestor de contraseñas (Opciones → Contraseñas, Configuración y
// la lista de los formularios), sobre toda la ventana de Mitis. Sin cuenta, se
// crea (usuario y contraseña maestra); bloqueado, se desbloquea; abierto: las
// guardadas (buscar, copiar, editar, quitar), añadir, generador, importar y
// exportar (CSV) y la cuenta (cambiar la maestra, borrar todo). Lo cifrado y
// guardado es de Passwords (C++). En un Loader de Main.qml: solo existe abierta.
FocusScope {
    id: root

    // Credencial que guardar en cuanto haya cuenta (aviso de guardar sin
    // cuenta): { url, username, password }
    property var pendingCredential: null
    // Vista al abrir con el gestor abierto: "list" o "generator"
    property string startView: "list"

    signal closeRequested()
    // Elegir un archivo (FilePicker de Main): { save, filters, accept(urls), reject() }
    signal fileRequested(var dialog)

    // "list", "edit", "generator", "export", "account", "reset"
    property string view: startView
    // Lo que se edita: {} nueva; si no, Passwords.entry()
    property var editing: ({})
    property string message: ""
    property string error: ""
    property bool waiting: false

    readonly property string page: !Passwords.exists ? (view === "reset" ? "reset" : "setup")
                                 : !Passwords.unlocked ? (view === "reset" ? "reset" : "locked")
                                 : view

    function show(name) {
        root.error = ""
        root.message = ""
        root.view = name
        Qt.callLater(root.focusPage)
    }
    function focusPage() {
        const first = { setup: setupUser, locked: unlockField, list: searchField, edit: editUrl,
                        export: exportField, account: currentField }[root.page]
        if (first)
            first.forceActiveFocus()
        else
            root.forceActiveFocus()
    }
    function edit(id) {
        root.editing = id ? Passwords.entry(id) : ({})
        editUrl.text = root.editing.url ?? ""
        editUser.text = root.editing.username ?? ""
        editPassword.text = root.editing.password ?? ""
        editPassword.revealed = false
        editNotes.text = root.editing.notes ?? ""
        root.show("edit")
    }
    function back() {
        if (root.page === "list" || root.page === "setup" || root.page === "locked")
            root.closeRequested()
        else
            root.show(Passwords.unlocked ? "list" : "locked")
    }
    function savePending() {
        const pending = root.pendingCredential
        if (pending && Passwords.unlocked) {
            Passwords.save("", pending.url, pending.username, pending.password)
            root.message = "Se guardó la contraseña de " + Urls.host(pending.url) + "."
            root.pendingCredential = null
        }
    }

    Component.onCompleted: Qt.callLater(root.focusPage)
    onPageChanged: Qt.callLater(root.focusPage)

    Connections {
        target: Passwords
        enabled: root.waiting
        function onUnlockFinished(ok) {
            root.waiting = false
            if (!ok) {
                root.error = Passwords.exists ? "La contraseña no es correcta." : "No se pudo crear la cuenta."
                unlockField.selectAll()
                return
            }
            unlockField.text = ""
            setupPassword.text = ""
            setupRepeat.text = ""
            root.error = ""
            root.view = "list"
            root.savePending()
        }
        function onChangeFinished(ok) {
            root.waiting = false
            if (!ok) {
                root.error = "La contraseña actual no es correcta."
                return
            }
            currentField.text = ""
            newField.text = ""
            repeatField.text = ""
            root.show("list")
            root.message = "Se cambió la contraseña del gestor."
        }
        function onExportFinished(error) {
            root.waiting = false
            if (error !== "") {
                root.error = error
                return
            }
            exportField.text = ""
            root.show("list")
            root.message = "Se exportaron las contraseñas. Borra el archivo cuando ya no lo necesites."
        }
    }

    Keys.onEscapePressed: root.back()

    // Velo: tapa la ventana para que no reciba clics, rueda ni hover
    Rectangle {
        anchors.fill: parent
        color: Colors.backgroundScrim
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    PopupBackground {
        id: card
        anchors.centerIn: parent
        width: Math.min(Theme.passwordManagerWidth, root.width - 2 * Theme.margin)
        height: root.page === "list" || root.page === "edit"
            ? Math.min(Theme.passwordManagerHeight, root.height - 2 * Theme.margin)
            : Math.min(header.height + pages.current.implicitHeight + 3 * Theme.margin + Theme.spacing,
                       root.height - 2 * Theme.margin)

        // Los clics dentro no cierran
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        // ── Cabecera ──
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.margin + Theme.spacing / 2
            height: Theme.buttonSize

            IconButton {
                id: backButton
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: Passwords.unlocked && root.page !== "list"
                icon: "back"
                flat: true
                tooltip: "Volver"
                tooltipBelow: true
                onClicked: root.back()
            }
            Icon {
                id: headerIcon
                anchors.left: backButton.visible ? backButton.right : parent.left
                anchors.leftMargin: backButton.visible ? Theme.spacing / 2 : Theme.spacing / 2
                anchors.verticalCenter: parent.verticalCenter
                name: "passwords"
                color: Colors.brandLight1
            }
            Text {
                anchors.left: headerIcon.right
                anchors.leftMargin: Theme.spacing
                anchors.right: headerButtons.left
                anchors.rightMargin: Theme.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: ({ setup: "Crea tu gestor de contraseñas", locked: "Contraseñas",
                         list: "Contraseñas", edit: root.editing.id ? "Editar contraseña" : "Añadir contraseña",
                         generator: "Generador de contraseñas", export: "Exportar contraseñas",
                         account: "Cuenta del gestor", reset: "Borrar el gestor" })[root.page] ?? ""
                color: Colors.ink
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Row {
                id: headerButtons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing / 2

                IconButton {
                    visible: Passwords.unlocked && root.page === "list"
                    icon: "user"
                    flat: true
                    tooltip: "Cuenta: " + Passwords.user
                    tooltipBelow: true
                    onClicked: root.show("account")
                }
                IconButton {
                    visible: Passwords.unlocked
                    icon: "lock"
                    flat: true
                    tooltip: "Bloquear"
                    tooltipBelow: true
                    onClicked: {
                        Passwords.lock()
                        root.view = "list"
                    }
                }
                IconButton {
                    icon: "close"
                    flat: true
                    tooltip: "Cerrar"
                    tooltipBelow: true
                    onClicked: root.closeRequested()
                }
            }
        }

        Item {
            id: pages
            anchors.top: header.bottom
            anchors.topMargin: Theme.margin
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.margin + Theme.spacing
            anchors.rightMargin: Theme.margin + Theme.spacing
            anchors.bottomMargin: Theme.margin + Theme.spacing / 2

            // La vista que se ve, para el alto de la ventana
            readonly property Item current: ({ setup: setupPage, locked: lockedPage, reset: resetPage,
                                               generator: generator, export: exportPage,
                                               account: accountPage })[root.page] ?? setupPage

            // ── Crear la cuenta ──
            Column {
                id: setupPage
                width: parent.width
                visible: root.page === "setup"
                spacing: Theme.spacing

                Explanation {
                    text: "Tus contraseñas se guardan cifradas en este equipo y solo se abren con la contraseña "
                        + "que elijas ahora. Si la olvidas no se pueden recuperar."
                }
                FieldLabel { text: "Usuario" }
                FormField {
                    id: setupUser
                    width: parent.width
                    placeholderText: "Tu nombre o correo"
                    KeyNavigation.tab: setupPassword
                }
                FieldLabel { text: "Contraseña del gestor" }
                SecretField {
                    id: setupPassword
                    width: parent.width
                    placeholderText: "Al menos 8 caracteres"
                    KeyNavigation.tab: setupRepeat
                }
                SecretField {
                    id: setupRepeat
                    width: parent.width
                    placeholderText: "Repítela"
                    onAccepted: createButton.clicked()
                }
                Status { error: root.error; waiting: root.waiting }
                Item {
                    width: parent.width
                    height: Theme.textButtonHeight

                    TextButton {
                        id: createButton
                        anchors.right: parent.right
                        primary: true
                        text: "Crear cuenta"
                        enabled: !root.waiting && setupUser.text.trim() !== "" && setupPassword.text.length >= 8
                        onClicked: {
                            if (setupPassword.text !== setupRepeat.text) {
                                root.error = "Las contraseñas no coinciden."
                                return
                            }
                            root.error = ""
                            root.waiting = true
                            Passwords.createAccount(setupUser.text, setupPassword.text)
                        }
                    }
                }
            }

            // ── Desbloquear ──
            Column {
                id: lockedPage
                width: parent.width
                visible: root.page === "locked"
                spacing: Theme.spacing

                Explanation {
                    text: "Hola, " + Passwords.user + ". Escribe la contraseña de tu gestor para ver y "
                        + "autocompletar tus contraseñas. Se bloquea de nuevo al cerrar Mitis."
                }
                SecretField {
                    id: unlockField
                    width: parent.width
                    placeholderText: "Contraseña del gestor"
                    enabled: !root.waiting
                    onAccepted: unlockButton.clicked()
                }
                Status { error: root.error; waiting: root.waiting }
                Item {
                    width: parent.width
                    height: Theme.textButtonHeight

                    TextButton {
                        anchors.left: parent.left
                        danger: true
                        text: "¿La olvidaste?"
                        onClicked: root.show("reset")
                    }
                    TextButton {
                        id: unlockButton
                        anchors.right: parent.right
                        primary: true
                        text: "Desbloquear"
                        enabled: !root.waiting && unlockField.text !== ""
                        onClicked: {
                            root.error = ""
                            root.waiting = true
                            Passwords.unlock(unlockField.text)
                        }
                    }
                }
            }

            // ── Borrar el gestor (contraseña olvidada) ──
            Column {
                id: resetPage
                width: parent.width
                visible: root.page === "reset"
                spacing: Theme.margin

                Explanation {
                    text: "Se borrarán tu cuenta del gestor y todas las contraseñas guardadas en Mitis. "
                        + "No se puede deshacer. Las cuentas de los sitios no cambian."
                }
                Item {
                    width: parent.width
                    height: Theme.textButtonHeight

                    Row {
                        anchors.right: parent.right
                        spacing: Theme.spacing

                        TextButton {
                            text: "Cancelar"
                            onClicked: root.show(Passwords.unlocked ? "account" : "locked")
                        }
                        TextButton {
                            primary: true
                            text: "Borrar todo"
                            onClicked: {
                                Passwords.reset()
                                root.show("list")
                            }
                        }
                    }
                }
            }

            // ── Lista ──
            Item {
                anchors.fill: parent
                visible: root.page === "list"

                FormField {
                    id: searchField
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: tools.left
                    anchors.rightMargin: Theme.spacing
                    leftPadding: Theme.margin + Theme.iconSize + Theme.spacing
                    placeholderText: "Buscar sitio o usuario"

                    Icon {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.margin
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        color: Colors.inkMuted
                    }
                }
                Row {
                    id: tools
                    anchors.right: parent.right
                    anchors.verticalCenter: searchField.verticalCenter
                    spacing: Theme.spacing / 2

                    IconButton {
                        icon: "add"
                        tooltip: "Añadir contraseña"
                        tooltipBelow: true
                        onClicked: root.edit("")
                    }
                    IconButton {
                        icon: "generate"
                        tooltip: "Generador de contraseñas"
                        tooltipBelow: true
                        onClicked: {
                            generator.generate()
                            root.show("generator")
                        }
                    }
                    IconButton {
                        icon: "import"
                        tooltip: "Importar (CSV de Chrome, Firefox, Edge, Bitwarden…)"
                        tooltipBelow: true
                        onClicked: root.fileRequested({
                            filters: ["*.csv"],
                            accept: urls => {
                                const count = Passwords.importCsv(urls[0])
                                root.error = count < 0
                                    ? "Ese archivo no es una lista de contraseñas (CSV de Chrome, Firefox, Edge, Bitwarden…)."
                                    : ""
                                root.message = count === 0 ? "No había contraseñas nuevas en el archivo."
                                             : count === 1 ? "Se importó 1 contraseña."
                                             : count > 0 ? "Se importaron " + count + " contraseñas." : ""
                            },
                            reject: () => {}
                        })
                    }
                    IconButton {
                        icon: "export"
                        enabled: Passwords.items.length > 0
                        tooltip: "Exportar (CSV)"
                        tooltipBelow: true
                        onClicked: root.show("export")
                    }
                }

                ListView {
                    id: list
                    anchors.top: searchField.bottom
                    anchors.topMargin: Theme.spacing
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: listStatus.top
                    anchors.leftMargin: -Theme.spacing
                    anchors.rightMargin: -Theme.spacing
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: {
                        const text = searchField.text.trim().toLowerCase()
                        return text === "" ? Passwords.items
                             : Passwords.items.filter(item => item.host.includes(text) || item.username.toLowerCase().includes(text))
                    }
                    ScrollBar.vertical: ScrollBar {
                        policy: list.contentHeight > list.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: Colors.hairlineStrong
                        }
                    }

                    delegate: PasswordRow {
                        onEditRequested: id => root.edit(id)
                        onNotice: text => root.message = text
                    }
                }

                Text {
                    anchors.centerIn: list
                    width: list.width - 2 * Theme.margin
                    visible: list.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: Passwords.items.length === 0
                        ? "Aún no hay contraseñas guardadas.\nMitis te ofrecerá guardarlas al iniciar sesión en un sitio; también puedes añadirlas o importarlas."
                        : "Ninguna coincide con la búsqueda."
                    color: Colors.inkMuted
                    font.pixelSize: Theme.fontSize
                    wrapMode: Text.Wrap
                }

                Text {
                    id: listStatus
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    topPadding: Theme.spacing
                    text: root.error !== "" ? root.error
                        : root.message !== "" ? root.message
                        : Passwords.items.length === 1 ? "1 contraseña guardada"
                        : Passwords.items.length + " contraseñas guardadas"
                    color: root.error !== "" ? Colors.danger : Colors.inkMuted
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }

            // ── Añadir o editar ──
            Flickable {
                anchors.fill: parent
                visible: root.page === "edit"
                contentHeight: editColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: editColumn
                    width: parent.width
                    spacing: Theme.spacing

                    FieldLabel { text: "Sitio" }
                    FormField {
                        id: editUrl
                        width: parent.width
                        placeholderText: "ejemplo.com"
                        KeyNavigation.tab: editUser
                    }
                    FieldLabel { text: "Usuario" }
                    FormField {
                        id: editUser
                        width: parent.width
                        placeholderText: "Usuario o correo"
                        KeyNavigation.tab: editPassword
                    }
                    FieldLabel { text: "Contraseña" }
                    Row {
                        width: parent.width
                        spacing: Theme.spacing / 2

                        SecretField {
                            id: editPassword
                            width: parent.width - 2 * (Theme.buttonSize + parent.spacing)
                            KeyNavigation.tab: editNotes
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "generate"
                            tooltip: "Generar una segura"
                            onClicked: {
                                editPassword.text = Passwords.generate(Settings.passwordLength)
                                editPassword.revealed = true
                            }
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "copy"
                            enabled: editPassword.text !== ""
                            tooltip: "Copiar contraseña"
                            onClicked: Passwords.copy(editPassword.text, true)
                        }
                    }
                    FieldLabel { text: "Notas" }
                    FormField {
                        id: editNotes
                        width: parent.width
                        placeholderText: "Opcional"
                    }
                    Status { error: root.error; waiting: root.waiting }
                    Item {
                        width: parent.width
                        height: Theme.textButtonHeight + Theme.spacing

                        TextButton {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            visible: root.editing.id !== undefined
                            danger: true
                            text: "Eliminar"
                            onClicked: {
                                Passwords.remove(root.editing.id)
                                root.show("list")
                                root.message = "Se eliminó la contraseña de " + root.editing.host + "."
                            }
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            spacing: Theme.spacing

                            TextButton {
                                text: "Cancelar"
                                onClicked: root.show("list")
                            }
                            TextButton {
                                primary: true
                                text: "Guardar"
                                enabled: Urls.host(editUrl.text.includes("://") ? editUrl.text : "https://" + editUrl.text) !== ""
                                         && editPassword.text !== ""
                                onClicked: {
                                    Passwords.save(root.editing.id ?? "", editUrl.text, editUser.text,
                                                   editPassword.text, editNotes.text)
                                    root.show("list")
                                    root.message = "Se guardó la contraseña."
                                }
                            }
                        }
                    }
                }
            }

            // ── Generador ──
            Column {
                id: generator
                width: parent.width
                visible: root.page === "generator"
                spacing: Theme.margin

                property string password: ""
                function generate() {
                    password = Passwords.generate(Settings.passwordLength)
                    copied = false
                }
                property bool copied: false

                Explanation {
                    text: "Contraseñas al azar con letras, números y símbolos. Al registrarte en un sitio, "
                        + "Mitis te ofrece una en el campo de la contraseña."
                }
                Rectangle {
                    width: parent.width
                    height: Theme.ntpSearchHeight
                    radius: Theme.radiusSmall
                    color: Colors.tintSunken
                    border.width: 1
                    border.color: Colors.hairline

                    TextEdit {
                        anchors.left: parent.left
                        anchors.right: generatorButtons.left
                        anchors.leftMargin: Theme.margin
                        anchors.rightMargin: Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: generator.password
                        readOnly: true
                        selectByMouse: true
                        color: Colors.inkStrong
                        selectionColor: Colors.selection
                        font.family: Theme.monospaceFont
                        font.pixelSize: Theme.fontSizeLarge
                    }
                    Row {
                        id: generatorButtons
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing / 2

                        IconButton {
                            icon: "reload"
                            flat: true
                            tooltip: "Otra"
                            onClicked: generator.generate()
                        }
                        IconButton {
                            icon: generator.copied ? "check" : "copy"
                            flat: true
                            tooltip: "Copiar (se borra del portapapeles en 30 s)"
                            onClicked: {
                                Passwords.copy(generator.password, true)
                                generator.copied = true
                            }
                        }
                    }
                }
                Item {
                    width: parent.width
                    height: Theme.buttonSize

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Largo: " + Settings.passwordLength + " caracteres"
                        color: Colors.ink
                        font.pixelSize: Theme.fontSize
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing / 2

                        IconButton {
                            glyph: "−"
                            enabled: Settings.passwordLength > 8
                            tooltip: "Más corta"
                            onClicked: {
                                Settings.passwordLength = Settings.passwordLength - 1
                                generator.generate()
                            }
                        }
                        IconButton {
                            glyph: "+"
                            enabled: Settings.passwordLength < 16
                            tooltip: "Más larga"
                            onClicked: {
                                Settings.passwordLength = Settings.passwordLength + 1
                                generator.generate()
                            }
                        }
                    }
                }
            }

            // ── Exportar ──
            Column {
                id: exportPage
                width: parent.width
                visible: root.page === "export"
                spacing: Theme.spacing

                Explanation {
                    text: "Se guardarán en un archivo CSV, el formato que aceptan Chrome, Edge, Firefox, "
                        + "Bitwarden y casi todos los gestores. El archivo no va cifrado: cualquiera que lo abra "
                        + "verá tus contraseñas. Bórralo cuando lo hayas importado."
                }
                SecretField {
                    id: exportField
                    width: parent.width
                    placeholderText: "Contraseña del gestor, para confirmar"
                    enabled: !root.waiting
                    onAccepted: exportButton.clicked()
                }
                Status { error: root.error; waiting: root.waiting }
                Item {
                    width: parent.width
                    height: Theme.textButtonHeight

                    TextButton {
                        id: exportButton
                        anchors.right: parent.right
                        primary: true
                        text: "Elegir dónde guardar"
                        enabled: !root.waiting && exportField.text !== ""
                        onClicked: root.fileRequested({
                            save: true,
                            filters: ["*.csv"],
                            accept: urls => {
                                root.error = ""
                                root.waiting = true
                                Passwords.exportCsv(urls[0], exportField.text)
                            },
                            reject: () => {}
                        })
                    }
                }
            }

            // ── Cuenta ──
            Column {
                id: accountPage
                width: parent.width
                visible: root.page === "account"
                spacing: Theme.spacing

                Explanation {
                    text: "Usuario: " + Passwords.user + ". Cambia la contraseña del gestor:"
                }
                SecretField {
                    id: currentField
                    width: parent.width
                    placeholderText: "Contraseña actual"
                    KeyNavigation.tab: newField
                }
                SecretField {
                    id: newField
                    width: parent.width
                    placeholderText: "Nueva (al menos 8 caracteres)"
                    KeyNavigation.tab: repeatField
                }
                SecretField {
                    id: repeatField
                    width: parent.width
                    placeholderText: "Repite la nueva"
                    onAccepted: changeButton.clicked()
                }
                Status { error: root.error; waiting: root.waiting }
                Item {
                    width: parent.width
                    height: Theme.textButtonHeight

                    TextButton {
                        anchors.left: parent.left
                        danger: true
                        text: "Borrar el gestor"
                        onClicked: root.show("reset")
                    }
                    TextButton {
                        id: changeButton
                        anchors.right: parent.right
                        primary: true
                        text: "Cambiar contraseña"
                        enabled: !root.waiting && currentField.text !== "" && newField.text.length >= 8
                        onClicked: {
                            if (newField.text !== repeatField.text) {
                                root.error = "Las contraseñas nuevas no coinciden."
                                return
                            }
                            root.error = ""
                            root.waiting = true
                            Passwords.changeMaster(currentField.text, newField.text)
                        }
                    }
                }
            }
        }
    }

    // ── Piezas ──
    component Explanation: Text {
        width: parent ? parent.width : 0
        color: Colors.inkSoft
        font.pixelSize: Theme.fontSize
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        bottomPadding: Theme.spacing / 2
    }
    component FieldLabel: Text {
        color: Colors.inkSecondary
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        topPadding: Theme.spacing / 2
    }
    // Error o espera de la vista que se ve
    component Status: Text {
        property string error: ""
        property bool waiting: false
        width: parent ? parent.width : 0
        visible: error !== "" || waiting
        text: waiting ? "Un momento…" : error
        color: waiting ? Colors.inkMuted : Colors.danger
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.Wrap
    }
    // Campo de contraseña con el botón de mostrarla
    component SecretField: FormField {
        id: secret
        property bool revealed: false
        echoMode: revealed ? TextInput.Normal : TextInput.Password
        font.family: revealed ? Theme.monospaceFont : Theme.interfaceFont
        rightPadding: Theme.buttonSizeSmall + Theme.spacing

        IconButton {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.buttonSizeSmall
            height: Theme.buttonSizeSmall
            iconSize: Theme.iconSizeSmall
            icon: secret.revealed ? "hide-password" : "show-password"
            flat: true
            tooltip: secret.revealed ? "Ocultar" : "Mostrar"
            onClicked: secret.revealed = !secret.revealed
        }
    }
    // Una guardada: sitio y usuario; copiar usuario y contraseña; al pulsarla, editarla
    component PasswordRow: Item {
        id: row

        required property var modelData

        signal editRequested(string id)
        // Algo que contar en la línea de abajo («Contraseña copiada…»)
        signal notice(string text)

        width: ListView.view.width
        height: Theme.passwordRowHeight

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing / 2
            anchors.rightMargin: Theme.spacing / 2
            radius: Theme.radiusSmall
            color: rowHover.hovered ? Colors.tintHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        // Icono del sitio sobre un círculo claro; sin él, la inicial
        Rectangle {
            id: faviconBox
            anchors.left: parent.left
            anchors.leftMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.buttonSizeSmall
            height: Theme.buttonSizeSmall
            radius: width / 2
            color: favicon.visible ? Colors.faviconBackdrop : Colors.tintActive

            Image {
                id: favicon
                anchors.centerIn: parent
                width: Theme.faviconSize
                height: Theme.faviconSize
                sourceSize: Qt.size(2 * Theme.faviconSize, 2 * Theme.faviconSize)
                source: Urls.favicon(row.modelData.url)
                asynchronous: true
                mipmap: true
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }
            Text {
                visible: !favicon.visible
                anchors.centerIn: parent
                text: (row.modelData.host || "?").charAt(0).toUpperCase()
                color: Colors.brandLight1
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
            }
        }

        Column {
            anchors.left: faviconBox.right
            anchors.leftMargin: Theme.spacing + Theme.spacing / 2
            anchors.right: rowButtons.left
            anchors.rightMargin: Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing / 4

            Text {
                width: parent.width
                text: row.modelData.title
                color: Colors.ink
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            Text {
                width: parent.width
                text: row.modelData.username || "(sin usuario)"
                color: Colors.inkMuted
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }

        HoverHandler {
            id: rowHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: row.editRequested(row.modelData.id)
        }

        Row {
            id: rowButtons
            anchors.right: parent.right
            anchors.rightMargin: Theme.margin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing / 2
            opacity: rowHover.hovered ? 1 : 0

            IconButton {
                width: Theme.buttonSizeSmall
                height: Theme.buttonSizeSmall
                iconSize: Theme.iconSizeSmall
                icon: "user"
                flat: true
                enabled: row.modelData.username !== ""
                tooltip: "Copiar usuario"
                onClicked: {
                    Passwords.copy(row.modelData.username, false)
                    row.notice("Usuario copiado.")
                }
            }
            IconButton {
                width: Theme.buttonSizeSmall
                height: Theme.buttonSizeSmall
                iconSize: Theme.iconSizeSmall
                icon: "copy"
                flat: true
                tooltip: "Copiar contraseña"
                onClicked: {
                    Passwords.copy(Passwords.entry(row.modelData.id).password, true)
                    row.notice("Contraseña copiada: se borrará del portapapeles en 30 segundos.")
                }
            }
            IconButton {
                width: Theme.buttonSizeSmall
                height: Theme.buttonSizeSmall
                iconSize: Theme.iconSizeSmall
                icon: "edit"
                flat: true
                tooltip: "Editar"
                onClicked: row.editRequested(row.modelData.id)
            }
        }
    }
}

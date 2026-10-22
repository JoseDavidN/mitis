import QtCore
import QtQuick
import QtQuick.Dialogs

// Selector de archivos que piden las páginas (<input type=file>…), con el
// diálogo del sistema; también la carpeta de una descarga (Configuración →
// Descargas → Preguntar dónde guardar). Uno para toda la ventana: es modal, así que solo hay
// uno abierto a la vez; si llegan más mientras tanto, esperan su turno.
Item {
    id: root

    // Pendientes: { owner (la pestaña), dialog (de fileDialogRequested) };
    // el primero es el abierto
    property var queue: []
    readonly property var current: queue.length > 0 ? queue[0].dialog : null
    property bool closing: false

    // `owner`: la pestaña que lo pide, para dismiss() si se cierra (o null).
    // `dialog` puede traer además `title` y `startFolder` (URL) para carpetas
    function ask(owner, dialog) {
        queue = queue.concat([{ owner: owner, dialog: dialog }])
        if (queue.length === 1)
            present()
    }
    // La pestaña se cierra: sus peticiones ya no tienen a quién responder
    function dismiss(owner) {
        const wasOpen = queue.length > 0 && queue[0].owner === owner
        queue = queue.filter(entry => entry.owner !== owner)
        if (wasOpen) {
            // close() avisa con rejected: no debe responder a la siguiente
            closing = true
            fileDialog.close()
            folderDialog.close()
            closing = false
            present()
        }
    }

    function present() {
        const dialog = current
        if (!dialog)
            return
        if (dialog.folder) {
            folderDialog.title = dialog.title ?? "Elegir carpeta"
            folderDialog.currentFolder = dialog.startFolder
                ?? StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
            folderDialog.open()
            return
        }
        fileDialog.fileMode = dialog.save ? FileDialog.SaveFile
                            : dialog.multiple ? FileDialog.OpenFiles
                            : FileDialog.OpenFile
        fileDialog.nameFilters = dialog.filters.length > 0
            ? ["Archivos admitidos (" + dialog.filters.join(" ") + ")", "Todos los archivos (*)"]
            : ["Todos los archivos (*)"]
        // dialog.defaultName no se usa: FileDialog solo admite archivos que ya existen
        fileDialog.open()
    }
    function answer(urls) {
        const dialog = current
        if (!dialog || closing)
            return
        queue = queue.slice(1)
        if (urls)
            dialog.accept(urls)
        else
            dialog.reject()
        present()
    }

    FileDialog {
        id: fileDialog
        title: fileMode === FileDialog.SaveFile ? "Guardar archivo"
             : fileMode === FileDialog.OpenFiles ? "Elegir archivos" : "Elegir archivo"
        currentFolder: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        onAccepted: root.answer(selectedFiles)
        onRejected: root.answer(null)
    }

    FolderDialog {
        id: folderDialog
        onAccepted: root.answer([selectedFolder])
        onRejected: root.answer(null)
    }
}

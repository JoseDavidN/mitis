pragma Singleton
import QtCore
import QtQuick

// Descargas de Mitis: el modelo que ve la interfaz y sus acciones. No conoce
// el motor: BrowserProfile.qml registra cada descarga con add() y la va
// actualizando con update(); las acciones que necesitan al motor (cancelar,
// pausar, reanudar) llegan a través del `control` que pasa al registrarla.
QtObject {
    id: root

    // Roles:
    //  id          int     identificador (único en la sesión)
    //  fileName    string  nombre del archivo
    //  path        string  ruta local completa del archivo
    //  folder      string  carpeta donde se guarda
    //  url         string  dirección de origen
    //  received    real    bytes recibidos
    //  total       real    bytes totales (-1 si no se sabe)
    //  state       string  "progress", "paused", "done", "failed", "canceled"
    //  error       string  motivo del fallo ("" si no hay)
    //  startedAt   real    ms desde 1970
    //  finishedAt  real    ms desde 1970 (0 mientras no termina)
    readonly property ListModel items: ListModel {}

    // Descargas en curso (en progreso o en pausa)
    property int activeCount: 0
    // La descarga más reciente: la que muestra el panel de la descarga actual
    property int currentId: -1

    // Empezó una descarga / terminó (bien, mal o cancelada)
    signal started(int id)
    signal finished(int id)

    property int _nextId: 1
    // id → { cancel(), pause(), resume() } del motor (solo descargas en curso)
    property var _controls: ({})

    // Listado de descargas terminadas, guardado entre sesiones (JSON)
    readonly property int _maxSaved: 50
    readonly property Settings _settings: Settings {
        category: "Downloads"
    }

    Component.onCompleted: _load()

    function indexOf(id) {
        for (let i = 0; i < items.count; i++) {
            if (items.get(i).id === id)
                return i
        }
        return -1
    }

    // Copia de los datos de una descarga, o null
    function get(id) {
        const index = indexOf(id)
        return index < 0 ? null : JSON.parse(JSON.stringify(items.get(index)))
    }

    function isActive(state) {
        return state === "progress" || state === "paused"
    }

    function _recount() {
        let active = 0
        for (let i = 0; i < items.count; i++) {
            if (isActive(items.get(i).state))
                active++
        }
        activeCount = active
    }

    // ── Lo usa BrowserProfile ────────────────────────────────────────
    // `info`: { fileName, path, folder, url, total }. `control`: objeto con
    // cancel(), pause() y resume(). Devuelve el id de la descarga.
    function add(info, control) {
        const id = _nextId++
        items.insert(0, {
            id: id,
            fileName: info.fileName ?? "",
            path: info.path ?? "",
            folder: info.folder ?? "",
            url: info.url ?? "",
            received: 0,
            total: info.total ?? -1,
            state: "progress",
            error: "",
            startedAt: Date.now(),
            finishedAt: 0
        })
        _controls[id] = control
        currentId = id
        _recount()
        started(id)
        return id
    }

    // `changes`: cualquiera de received, total, state, error, fileName, path
    function update(id, changes) {
        const index = indexOf(id)
        if (index < 0)
            return
        const before = items.get(index).state
        for (const key in changes)
            items.setProperty(index, key, changes[key])
        const after = items.get(index).state
        if (before !== after) {
            if (!isActive(after)) {
                items.setProperty(index, "finishedAt", Date.now())
                delete _controls[id]
            }
            _recount()
            if (isActive(before) && !isActive(after)) {
                _save()
                finished(id)
            }
        }
    }

    // ── Acciones de la interfaz ──────────────────────────────────────
    function cancel(id) {
        _controls[id]?.cancel()
    }
    function pause(id) {
        _controls[id]?.pause()
    }
    function resume(id) {
        _controls[id]?.resume()
    }

    // Abre el archivo con la aplicación del sistema (o lo ejecuta)
    function openFile(id) {
        const item = get(id)
        if (item && item.state === "done")
            Qt.openUrlExternally(_fileUrl(item.path))
    }

    // Abre la carpeta donde está el archivo
    function openFolder(id) {
        const item = get(id)
        if (item)
            Qt.openUrlExternally(_fileUrl(item.folder))
    }

    // Quita una descarga terminada del listado (el archivo no se borra)
    function remove(id) {
        const index = indexOf(id)
        if (index < 0 || isActive(items.get(index).state))
            return
        items.remove(index)
        if (currentId === id)
            currentId = -1
        _save()
    }

    // Quita del listado todas las terminadas
    function clearFinished() {
        for (let i = items.count - 1; i >= 0; i--) {
            if (!isActive(items.get(i).state))
                items.remove(i)
        }
        if (indexOf(currentId) < 0)
            currentId = -1
        _save()
    }

    // En Windows la ruta empieza por la unidad (C:/…) y necesita "file:///"
    function _fileUrl(path) {
        return (path.startsWith("/") ? "file://" : "file:///") + path
    }

    // ── Persistencia ─────────────────────────────────────────────────
    // Solo las terminadas (las en curso no se pueden retomar) y las más
    // recientes; el id no se guarda: se asigna uno nuevo al cargar
    function _save() {
        const list = []
        for (let i = 0; i < items.count && list.length < _maxSaved; i++) {
            const item = items.get(i)
            if (isActive(item.state))
                continue
            list.push({
                fileName: item.fileName,
                path: item.path,
                folder: item.folder,
                url: item.url,
                received: item.received,
                total: item.total,
                state: item.state,
                error: item.error,
                startedAt: item.startedAt,
                finishedAt: item.finishedAt
            })
        }
        _settings.setValue("list", JSON.stringify(list))
    }

    function _load() {
        let list = []
        try {
            list = JSON.parse(_settings.value("list", "[]"))
        } catch (e) {
            console.warn("[Mitis] Listado de descargas guardado no válido; se descarta")
        }
        if (!Array.isArray(list))
            return
        for (const saved of list.slice(0, _maxSaved)) {
            if (isActive(saved.state))
                continue
            items.append({
                id: _nextId++,
                fileName: saved.fileName ?? "",
                path: saved.path ?? "",
                folder: saved.folder ?? "",
                url: saved.url ?? "",
                received: saved.received ?? 0,
                total: saved.total ?? -1,
                state: saved.state ?? "done",
                error: saved.error ?? "",
                startedAt: saved.startedAt ?? 0,
                finishedAt: saved.finishedAt ?? 0
            })
        }
    }

    // "3,2 MB", "850 KB"...
    function formatBytes(bytes) {
        if (bytes < 0)
            return "?"
        const units = ["B", "KB", "MB", "GB", "TB"]
        let value = bytes
        let unit = 0
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024
            unit++
        }
        const digits = unit === 0 || value >= 100 ? 0 : 1
        return value.toLocaleString(Qt.locale("es_ES"), "f", digits) + " " + units[unit]
    }
}

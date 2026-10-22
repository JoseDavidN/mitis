# Mitis: guía para Claude Code

Mitis es un navegador web personal, ligero y multiplataforma (Linux, Windows, macOS).
Chromium (vía Qt WebEngine) **solo renderiza páginas**. Toda la interfaz y sus funciones son propias.

Plan de desarrollo por fases: `docs/PLAN.md`. Antes de empezar una tarea, revisa en qué fase va el proyecto y respeta el orden.
Sistema de diseño (colores, tokens, componentes): `DESIGN.md`. Todo cambio visual debe seguirlo.

## Objetivos que guían toda decisión

1. **Interfaz 100% propia y nativa** en QML. Nunca construir partes de la interfaz con HTML dentro del motor.
2. **Bajo consumo de RAM.** Ante dos soluciones, elegir la que use menos memoria y procesos.
3. **Multiplataforma** con un solo código. Nada específico de un sistema sin alternativa para los otros dos.

## Stack

- Qt 6.8+ (desarrollo en Arch Linux con Qt 6.11), Qt Quick/QML, Qt WebEngine, Qt SVG, Qt SQL (SQLite), C++17, CMake 3.21+, Ninja.
- Windows requiere MSVC 2022; Qt WebEngine no funciona con MinGW.

## Compilar y ejecutar

```bash
cmake -S . -B build -G Ninja
cmake --build build
./build/bin/Mitis          # normal: QML empaquetado en el ejecutable
./build/bin/Mitis --dev    # desarrollo: QML desde qml/ con recarga al guardar
```

- El ejecutable va en `build/bin/` a propósito: en Linux, `build/Mitis/` es la carpeta del módulo QML y chocan.
- Solo hay que recompilar al cambiar C++ o `CMakeLists.txt`. Para cambios de QML basta con `--dev`.
- El entorno de desarrollo es un servidor sin pantalla. La interfaz se ve por VNC (`Xvnc :1`, luego `DISPLAY=:1`).

## Estructura

```
src/            C++ (main.cpp, devreloader.*, iconprovider.*: iconos SVG coloreados para QML,
                networkfactory.*: red de la interfaz QML con caché en disco,
                widevine.*: localiza Widevine (contenido protegido) y se lo pasa al motor,
                settings.*: ajustes guardados con QSettings, singleton `Settings` del módulo Mitis.Core,
                history.*: historial en SQLite, escritura en un hilo propio (singleton `History`),
                bookmarks.*: marcadores en SQLite (singleton `Bookmarks`),
                memorymonitor.*: memoria de Mitis y de sus procesos del motor (singleton `MemoryMonitor`),
                filterengine.*: motor de filtros de anuncios (sintaxis EasyList/uBlock y hosts de Pi-hole), sin dependencias del motor web,
                contentblocker.*: bloqueador: descarga, guarda, renueva y compila las listas; lo consulta RequestInterceptor,
                links.*: enlaces que el sistema pide abrir (navegador predeterminado) y un solo Mitis por perfil (singleton `Links`))
qml/            Interfaz. Todos los archivos planos en esta carpeta.
  Main.qml            Ventana, modelo de pestañas, navegación, atajos, sesión (no conoce el motor). La ventana privada es otra instancia (privateMode)
  BrowserTab.qml      Una pestaña: envuelve WebEngineView y ofrece solo lo que usa la interfaz
  BrowserProfile.qml  Singleton: completa y atiende el perfil que crea C++ (scripts inyectados, User-Agent, descargas, permisos) y el de las ventanas privadas
  Theme.qml           Singleton: colores (tres temas: Nocturno, Oscuro, Claro; Settings.theme), medidas, animaciones
  TitleBar.qml        Barra superior: marca (icono + "Mitis") y controles de ventana
  BottomBar.qml       Controles inferiores flotantes: navegación, dirección, pestañas, marcadores, opciones
  AddressBar.qml      Campo de dirección/búsqueda, con sugerencias de marcadores e historial
  TabsPopup.qml       Lista desplegable de pestañas
  OptionsPopup.qml    Menú de opciones (ventana privada, historial, descargas, configuración)
  BookmarksPopup.qml  Lista de marcadores: guardar la página actual (Ctrl+D), buscar, abrir, quitar
  HistoryPopup.qml    Historial (Opciones → Historial): lo visitado, reabrir la última cerrada, ir a Configuración
  PageRow.qml         Fila de una página guardada (favicon, título, detalle, quitar)
  DownloadsPopup.qml  Listado de descargas (menú de opciones → Descargas)
  ContextMenu.qml     Menú contextual de la página (clic derecho)
  DevToolsWindow.qml  Ventana de herramientas de desarrollo (F12), una por pestaña; paleta propia negra
  ProtectedContentNotice.qml Aviso (PageDialog) de que falta Widevine en una página con contenido protegido
  PopupBackground.qml Fondo común de las listas desplegables
  PopupAction.qml     Fila de acción de una lista: icono, texto y atajo
  IconButton.qml      Botón base, flotante y redondeado
  Icon.qml            Icono SVG de assets/icons/ coloreado con el tema
  Tooltip.qml         Tooltip propio: acción y atajo de teclado
  NewTabPage.qml      Página de nueva pestaña (una sola, sobre la pestaña sin dirección)
  QuickLinkTile.qml   Acceso rápido de la página de nueva pestaña
  QuickLinkEditor.qml Diálogo para añadir un acceso rápido
  SearchEngines.qml   Singleton: buscadores, el elegido (guardado en Settings, categoría Search) y resolve()/searchUrl()
  SettingsPage.qml    Página de Configuración (menú de opciones): sobre las pestañas, índice de secciones y ajustes
  ThemeBackground.qml Fondo del tema de las páginas propias (nueva pestaña, Configuración)
  Toggle.qml          Interruptor de encendido/apagado
  RadioMark.qml       Círculo de elección única (lo dibuja; el clic es de su fila)
  CheckMark.qml       Casilla de verificación (lo dibuja; el clic es de su fila)
  NewsCard.qml        Tarjeta de noticia
  MiniPlayer.qml      Mini reproductor sobre la barra de búsqueda
  FindBar.qml         Buscar en la página (Ctrl+F)
  ZoomIndicator.qml   Indicador de zoom (arriba a la derecha, se cierra solo)
  MemoryPanel.qml     Panel de memoria (desarrollo, Shift+Esc): total, por tipo de proceso y por pestaña
  News.qml            Singleton: noticias de tecnología (RSS), compartidas por todas las pestañas
  TextButton.qml      Botón con texto (primary = degradado de marca; danger = acción arriesgada)
  FormField.qml       Campo de texto de formulario
  urls.js             Texto escrito → URL o búsqueda (con la plantilla que recibe); dominio y favicon de una URL; ruta local ↔ file://. Sin estado: el buscador lo pone SearchEngines
  ResizeHandles.qml   Bordes para redimensionar la ventana sin marco
  FullscreenHint.qml  Aviso «Pulsa Esc/F11 para salir de la pantalla completa»
  CertificateDialog.qml Aviso de certificado inválido (PageDialog): volver o continuar
  PermissionDialog.qml Permisos de un sitio (PageDialog): cámara, micrófono, ubicación… en cola
  JsDialog.qml        alert, confirm, prompt y aviso de salir de la página (PageDialog), en cola
  FilePicker.qml      Selector de archivos de las páginas (<input type=file>): diálogo del sistema, uno por ventana
  qmldir              Solo para --dev: declara los singletons
assets/         icons/ (SVG de Lucide, nombrados por uso), fonts/ (Nunito),
                scripts/ (JS que Mitis inyecta: media.js, puente multimedia en las páginas;
                devtools.js, tema negro del panel de DevTools; drm.js, detecta páginas que
                piden Widevine cuando falta)
docs/           Documentación y plan (rendimiento.md: comparativa de memoria; versiones.md: esquema y cómo publicar)
licencias/      LEEME.md (GPL-3.0 de Mitis y cómo se cumple la LGPL de Qt), AVISOS.md (terceros) y textos de licencia; viaja en cada paquete. LICENSE (raíz): GPL-3.0
CHANGELOG.md    Cambios de cada versión, para usuarios («Sin publicar» arriba)
tools/codecs/   Compilar Qt WebEngine con códecs propietarios (H.264, AAC) para Windows y macOS, y página de prueba; guía en docs/codecs.md
tools/          medir_ram.py: mide la RAM de Mitis, Chrome o Firefox con las páginas de paginas.txt
installer/      Instalador de Windows (proyecto CMake aparte, Win32 + GDI+, sin Qt): src/main.cpp (ventana),
                src/instalacion.* (extraer, accesos, registro, desinstalar), empaquetar.ps1 (pega el ZIP al .exe)
assets/branding/ Logos para el instalador (startcode.png)
packaging/macos/ Info.plist.in (abre http/https y HTML: navegador predeterminado)
packaging/linux/ PKGBUILD (Arch, mitis-git), appimage.sh (+ apprun-sandbox.sh), mitis.desktop, mitis.svg (icono provisional)
.github/workflows/compilar.yml  Compila en Linux, Windows y macOS; instalador y .dmg; release con etiqueta v*
```

## Diseño de la interfaz

- **Arriba:** barra de título con el icono y el nombre "Mitis" a la izquierda, y minimizar/maximizar/cerrar a la derecha. Nada más. Se arrastra para mover y con doble clic maximiza.
- **Abajo:** controles independientes que flotan sobre la página, **sin barra ni fondo**: atrás, adelante, recargar, campo de dirección, pestañas, marcadores y opciones. La página llega hasta el borde inferior de la ventana y cada control lleva su propio fondo y borde, sin sombra. El progreso de carga va dentro del campo de dirección.
- Botones redondeados y flotantes (`IconButton`). Las listas desplegables de la barra inferior se abren hacia arriba.

## Reglas de código

### QML
- **Colores, medidas, radios y duraciones solo desde `Theme`.** Nada de colores escritos a mano en los componentes. Qué token usar en cada caso: `DESIGN.md`.
- Un componente por archivo, en `qml/`, con nombre en PascalCase.
- **Al crear un archivo QML nuevo:** añadirlo a `MITIS_QML_FILES` en `CMakeLists.txt`. Si es singleton, además marcarlo con `QT_QML_SINGLETON_TYPE` y declararlo en `qml/qmldir`.
- Los componentes reciben datos por propiedades (`required property` cuando son obligatorias) y comunican hacia arriba con señales. No acceder a ids de otros archivos.
- Las inline components (`component X: ...`) no ven los ids del archivo que las contiene.
- Para hover en elementos con hijos interactivos, usar `HoverHandler`, no `MouseArea.containsMouse`.
- Controles de Qt Quick Controls: importar `QtQuick.Controls.Basic` y estilizar todo (background, contentItem) para que no dependa del estilo del sistema.

### Motor web
- **Solo `BrowserTab.qml` y `BrowserProfile.qml` importan `QtWebEngine`.** El resto de la interfaz habla con las pestañas a través de la API de `BrowserTab` (propiedades `url`, `title`, `icon`, `loading`, `muted`…; funciones `navigate()`, `goBack()`, `mediaState()`…; señales `newTabRequested`, `closeRequested`). Así, cambiar de motor es reescribir esos dos archivos.
- Si la interfaz necesita algo nuevo del motor, se añade a `BrowserTab` (como alias cuando sea una propiedad: no cuesta nada), nunca usando `WebEngineView` desde fuera.
- En C++, el motor aparece en `QtWebEngineQuick::initialize()` de `main.cpp`, en `RequestInterceptor` (ve cada petición de las páginas: bloqueador, parámetros de rastreo, https) y en `EngineBridge` (lo publica en QML como la propiedad de contexto `MitisEngine`, porque los tipos del módulo no existen en `--dev`).
- **Perfiles:** los crea `EngineBridge` en C++: el normal con su nombre de almacenamiento desde el constructor (creado en QML, Qt avisa de que quedará obsoleto y arranca un instante sin disco) y el privado con nombre vacío (`createPrivateProfile()`/`destroyPrivateProfile()`). Viven toda la app, también entre recargas de `--dev`: lo que `BrowserProfile` les pone (scripts, enlaces) debe poder repetirse sin duplicar. `main.cpp` crea el puente antes de la interfaz y lo destruye después de ella y antes de la aplicación.
- **Navegador predeterminado:** los enlaces llegan como argumentos (`Mitis https://…`) o, en macOS, como evento FileOpen. `Links` (C++) deja un solo Mitis por perfil: el que arranca con otro abierto le pasa sus enlaces por `QLocalServer` (canal que depende de la carpeta de datos: un perfil de pruebas con otra carpeta XDG no se los manda al Mitis del usuario) y termina. `Main.qml` (solo la ventana principal) los abre en pestañas nuevas. Registro: `mitis.desktop` (Linux), `Info.plist.in` (macOS) y el instalador (Windows: ProgID `MitisHTML`, `RegisteredApplications`).
- **Opciones de Chromium** (`setupChromiumFlags()` en `main.cpp`, antes de iniciar el motor): sin peticiones en segundo plano, sin `<a ping>`, sin las APIs publicitarias de Privacy Sandbox, y `prefers-color-scheme` según el tema guardado (solo al arrancar: Qt WebEngine no deja cambiarlo en marcha). Las de `QTWEBENGINE_CHROMIUM_FLAGS` van detrás y ganan; un `--disable-features` propio sustituye la lista entera. Límite de procesos, `--process-per-site` y `--enable-low-end-device-mode` se midieron y no ahorran memoria (docs/rendimiento.md).
- **Descargas:** motor → `BrowserProfile` (`onDownloadRequested`: acepta, registra con `Downloads.add()` y mantiene el modelo con `Downloads.update()` desde las señales del objeto, sin sondeo) → `Downloads.qml` (singleton sin motor: modelo `items`, acciones, y listado de terminadas guardado en `Settings`, categoría `Downloads`) → interfaz, que solo usa `Downloads`. El nombre repetido lo resuelve el propio motor (`archivo (1).ext`).

### Ajustes
- **Todo lo que se guarda entre sesiones va por el singleton `Settings`** (`src/settings.*`, `import Mitis.Core`), nunca por `Settings` de `QtCore`. Las preferencias son propiedades (enlazables, con su clave fija en `settings.cpp`); los datos internos usan `Settings.value("Categoría/clave", porDefecto)` / `Settings.setValue()`.
- Un archivo que necesite además `StandardPaths` importa `QtCore as Core` (`Core.StandardPaths…`): así su `Settings` no choca con el de Mitis.
- Una preferencia nueva que se elija en la interfaz: propiedad en `Settings`, fila en `SettingsPage.qml` y su clave en `resetPreferences()` (`settings.cpp`).
- **Suspensión de pestañas** (Fase 5): `Main.qml` decide cuándo (temporizador: congelar a los 5 min oculta, descargar a los `Settings.suspendAfter`; nunca fijadas ni la del mini reproductor) y `BrowserTab.suspend()` aplica el estado del motor (`lifecycleState`) con sus excepciones (suena, DevTools, `recommendedState`, permiso de notificaciones, formulario con datos). Al volver a verse, la pestaña se reactiva sola.
- **Bloqueador de anuncios** (Fase 5): `ContentBlocker` guarda las listas en la carpeta de datos (`filtros/`), las renueva cada 4 días y las compila en un hilo con `FilterEngine` (~335 000 reglas, <1 s, ~4 MB, ~10 µs por petición). Para no romper páginas: la página principal solo se bloquea con reglas `$document`; si el usuario visita un dominio de las listas, sus propios recursos no se bloquean; una regla con opciones que no se entienden (`redirect`, `csp`…) se descarta entera. La ocultación de elementos es solo por sitio: `BrowserTab` pone el CSS del sitio en un script de la vista al empezar cada carga (`MitisEngine.cosmeticCss`). Para probar el motor sin compilar Mitis, basta con compilar `filterengine.cpp` con un `main` que lo use (solo necesita Qt Core).
- Dónde se aplica cada preferencia: las de la página (JavaScript, imágenes, emergentes, modo oscuro, zoom, permisos bloqueados) en `BrowserTab`; las del perfil (idiomas, carpeta, borrar al cerrar) en `BrowserProfile`; las que van petición a petición (cookies de terceros, No rastrear, conexiones seguras, bloqueador y parámetros de rastreo) en C++, en `EngineBridge`/`RequestInterceptor`, enlazadas desde `BrowserProfile`.

### C++
- Lógica pesada, persistencia y todo lo que toque el motor a bajo nivel va en C++, expuesto a QML con `QML_ELEMENT` / `QML_SINGLETON`.
- Los tipos de C++ para QML van en el módulo `Mitis.Core` (biblioteca `mitiscore` en `CMakeLists.txt`, enlazada estática con `Q_IMPORT_QML_PLUGIN` en `main.cpp`): el modo `--dev` no ve los tipos del módulo `Mitis`, pero sí puede importar este. Lo que dependa del motor sigue en `EngineBridge` (`MitisEngine`).
- Cada clase nueva se añade a `qt_add_executable` (o a `mitiscore` si es un tipo de QML) en `CMakeLists.txt`.
- Si se usa un módulo Qt nuevo, añadirlo a `find_package` y a `target_link_libraries`.

### Instalador de Windows (`installer/`)
- No usa Qt (se ejecuta antes de que esté instalado): Win32, GDI+ y miniz (se descarga al configurar, con su hash). CRT estático.
- Sus colores son los de Nocturno copiados en `src/main.cpp`: si cambia el tema, cambiarlos también allí. Medidas a 100 % de escala, multiplicadas por los DPI.
- Formato: `[MitisInstalador.exe][ZIP][desplazamiento 8 bytes][«MITISPAQ»]`. El desinstalador es el mismo `.exe` sin el paquete, con `--desinstalar`.
- Solo se compila en Windows (GitHub Actions); aquí no hay compilador para probarlo.

### General
- Comentarios y mensajes en español, breves, explicando el porqué cuando no es obvio.
- Textos de la interfaz en español.
- Mensajes de commit en español, en imperativo ("Añade...", "Corrige...").
- Un componente de terceros nuevo (biblioteca, fuente, iconos, lista descargada): añadirlo a `licencias/AVISOS.md` con su licencia y, si se distribuye, su texto en `licencias/`. Qt siempre enlazado dinámicamente (LGPL).
- **Versiones y cambios:** la versión solo se cambia en `project(VERSION)` de `CMakeLists.txt`. Todo cambio que note el usuario se apunta en `CHANGELOG.md`, sección «Sin publicar», en el mismo commit y redactado para usuarios. Para publicar: `docs/versiones.md`.

## Cómo verificar cambios

1. `cmake --build build` sin errores ni advertencias nuevas.
2. `qmllint -I ../build` desde `qml/` sobre los QML modificados (está en `/usr/lib/qt6/bin`; `-I ../build` para que encuentre `Mitis.Core`, que se genera al compilar).
3. Ejecutar y comprobar que no hay errores de QML en la salida:
   - En modo normal y en `--dev`: el modo `--dev` carga los QML de otra forma y puede fallar aunque el normal funcione. El modo normal usa los QML de la última compilación: recompilar antes de probarlo.
   - Si la salida no es una terminal, Qt manda los mensajes a journald: `journalctl --user --since "-1min" | grep Mitis`.
4. Sin pantalla se puede verificar visualmente (no hay Xvfb ni xdotool; sí Xvnc y ffmpeg). Usar una pantalla distinta de `:1`, que es la del usuario:
   ```bash
   Xvnc :7 -geometry 1400x900 -depth 24 -SecurityTypes None -localhost & export DISPLAY=:7
   ./build/bin/Mitis &
   sleep 15; ffmpeg -loglevel error -y -f x11grab -video_size 1400x900 -i :7 -frames:v 1 captura.png
   ```
   WebEngine tarda en pintar la primera página: esperar al menos 15 s.
   Para medir memoria con muchas páginas (y comparar con Chrome y Firefox): `tools/medir_ram.py` (ver su ayuda).
   Para probar hover y animaciones, lanzar con `QT_QUICK_BACKEND=software`: con OpenGL, en Xvnc la ventana no se repinta al pasar el ratón y las capturas salen sin el efecto. El puntero se mueve con XTest desde Python:
   ```bash
   python3 -c 'import ctypes as c,sys; x=c.CDLL("libX11.so.6"); t=c.CDLL("libXtst.so.6"); x.XOpenDisplay.restype=c.c_void_p; d=c.c_void_p(x.XOpenDisplay(b":7")); t.XTestFakeMotionEvent(d,-1,int(sys.argv[1]),int(sys.argv[2]),0); x.XFlush(d)' 1252 20
   ``` Para probar estados (varias pestañas, listas abiertas) sin xdotool, cambiar temporalmente el `Component.onCompleted` de `Main.qml` en `--dev` y restaurarlo después.
5. Si se toca `devreloader.*`, probar: editar un QML con la app abierta, introducir un error a propósito (la app no debe cerrarse) y corregirlo, y cambiar un valor de `Theme.qml`.

## Problemas conocidos ya resueltos (no reintroducir)

- Ejecutable y módulo QML con el mismo nombre en `build/` → por eso existe `RUNTIME_OUTPUT_DIRECTORY bin`.
- Los singletons no se recargan con `clearComponentCache()` → `DevReloader` crea un `QQmlApplicationEngine` nuevo en cada recarga.
- Al destruir la ventana en una recarga la app se cerraba → `setQuitOnLastWindowClosed(false)` durante la recarga.
- En `--dev` el `qmldir` solo necesita los singletons; los demás tipos se resuelven por la carpeta.
- Atajos con varias ventanas (la privada es otra `Main`): son `Qt.ApplicationShortcut` (con `WindowShortcut` dejan de funcionar si ninguna ventana queda activa, como en Xvnc sin gestor de ventanas, y F12 debe llegar desde la de DevTools), así que dos ventanas tendrían los mismos atajos a la vez y Qt los da por ambiguos. Cada `Shortcut` de `Main.qml` lleva `enabled: win.ownsShortcuts && …`: los atiende la ventana activa o, si no hay ninguna, la principal. Las privadas se quitan de `privateWindows` de su ventana al cerrarse: una referencia a una ventana destruida dejaba `ownsShortcuts` en falso para siempre.
- Ctrl+Mayús+Tab no hacía nada: un `Shortcut` con varias secuencias equivalentes (`Ctrl+Shift+Tab`, `Ctrl+Backtab`…) es **ambiguo** consigo mismo y Qt emite `activatedAmbiguously`, no `activated`. Usar una sola secuencia por pulsación (y, si hay riesgo, atender también `onActivatedAmbiguously`).
- Una descarga cortada por el servidor mostraba "Download canceled by the user": Chromium envía motivos de interrupción que Qt no tiene en su enumeración (p. ej. 38, la descarga llegó incompleta) y para ellos `interruptReasonString` miente. `BrowserProfile` los traduce por número y nunca usa ese texto.
- Google no dejaba iniciar sesión ("Es posible que el navegador o la aplicación no sean seguros", página `/signin/rejected`): rechaza los navegadores con motor embebido. Lo que delataba a Mitis era `window.chrome` vacío (Chrome trae `app`, `csi`, `loadTimes`). Solución, solo en `accounts.google.com`: `assets/scripts/google.js` (inyectado desde `BrowserProfile`) los completa. **No disfrazarse** de otra versión ni de Google Chrome (User-Agent, Client Hints, `userAgentData`): se probó y con la incoherencia con el motor Google también rechaza; Chrome for Testing 140, con solo la marca "Chromium", pasa. Se conserva la versión real de Chromium. `BrowserTab` activa los complementos (visor de PDF), como Chrome.
- El panel de DevTools salía claro aunque se eligiera el tema oscuro: Chromium solo aplica el tema tras cargar `devtools://theme/colors.css`, que Qt WebEngine no incluye. `devtools.js` desactiva su ajuste `chrome-theme-colors` y entonces el tema se aplica al momento. Sus variables de color (`--sys-color-*`) se sobrescriben con `!important`: el panel las define con selectores más específicos. La vista del panel debe recibir `inspectedView` **después** de crearse: pasado en `createObject()` el panel se queda en blanco.
- Al cerrar la ventana, Mitis desaparecía pero el proceso seguía vivo: el motor QML era hijo de `app` y se destruía a mitad del cierre de esta, y Qt WebEngine se quedaba bloqueado. `main.cpp` destruye la interfaz a mano tras `app.exec()`.
- WhatsApp Web (y otros sitios) rechazaban a Mitis: el User-Agent de Qt WebEngine incluye `QtWebEngine/x.y.z` → `BrowserProfile.qml` lo quita al arrancar. Se conserva la versión real de Chromium: no inventar una más nueva.

# Mitis: guía para Claude Code

Mitis es un navegador web personal, ligero y multiplataforma (Linux, Windows, macOS).
Chromium (vía Qt WebEngine) **solo renderiza páginas**. Toda la interfaz y sus funciones son propias.

Tareas pendientes, por área (interfaz, identidad visual, motor web, distribución): `docs/PLAN.md`. Lo ya hecho (Fases 0–6, versión 0.5.0) está en `CHANGELOG.md`. Al terminar una tarea, se quita del plan y se apunta en el CHANGELOG.
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
                memorymonitor.*: memoria, CPU y GPU de Mitis y de sus procesos del motor (singleton `MemoryMonitor`; GPU solo en Linux),
                filterengine.*: motor de filtros de anuncios (sintaxis EasyList/uBlock y hosts de Pi-hole), sin dependencias del motor web,
                contentblocker.*: bloqueador: descarga, guarda, renueva y compila las listas; lo consulta RequestInterceptor,
                notifier.*: notificaciones de las páginas como notificaciones del sistema (D-Bus en Linux, Shell_NotifyIcon en Windows, notifier_mac.mm en macOS); lo crea EngineBridge,
                screenshot.*: junta, guarda y copia las capturas de pantalla (singleton `Screenshot`; los trozos los da ScreenshotOverlay),
                windowstyle.*: esquinas redondeadas de la ventana sin marco (DWM en Windows 11, windowstyle_mac.mm en macOS),
                captureindicator.*: aviso de micrófono/cámara en el icono de la ventana (singleton `CaptureIndicator`; cada BrowserTab informa con report()),
                updater.*: busca versiones nuevas en el servidor de descargas y abre el instalador para actualizar (singleton `Updates`),
                crashreporter.*: registro de la sesión e informes de cierres inesperados (singleton `CrashReports`; carpeta de datos `informes/`; pila y, en Windows, minidump),
                links.*: enlaces que el sistema pide abrir (navegador predeterminado) y un solo Mitis por perfil (singleton `Links`),
                navigationgestures.*: atrás/adelante con los botones laterales del ratón y los gestos de macOS (tres dedos; dos dedos con «Deslizar entre páginas», navigationgestures_mac.mm), filtro de eventos que solo observa (singleton `NavigationGestures`),
                themecolors.*: `Colors`, propiedad adjunta con los colores de la ventana de cada elemento (paleta del tema o, en las privadas, «privado»); las paletas se las da Theme.qml,
                printing.*: imprimir y guardar como PDF: PDF temporal de la vista previa, copia y envío a la impresora (Qt PDF + Print Support, en un hilo; singleton `Printing`))
qml/            Interfaz. Todos los archivos planos en esta carpeta.
  Main.qml            Ventana (tamaño recordado en Settings, «Window/geometry»), modelo de pestañas, navegación, atajos, sesión (no conoce el motor). La ventana privada es otra instancia (privateMode)
  BrowserTab.qml      Una pestaña: envuelve WebEngineView y ofrece solo lo que usa la interfaz
  BrowserProfile.qml  Singleton: completa y atiende el perfil que crea C++ (scripts inyectados, User-Agent, descargas, permisos) y el de las ventanas privadas
  Theme.qml           Singleton: paletas (tres temas: Nocturno, Oscuro, Claro; Settings.theme; y «privado», la de las ventanas privadas, que lee Colors), medidas, animaciones
  TitleBar.qml        Barra superior: nombre de Mitis (logo sin icono, según el tema) y controles de ventana
  BottomBar.qml       Controles inferiores flotantes: navegación, dirección, pestañas, marcadores, opciones
  AddressBar.qml      Campo de dirección/búsqueda, con sugerencias (pestañas abiertas de la ventana: «Ir a la pestaña»; marcadores; historial) y el botón del sitio (candado)
  Surface.qml         Fondo de todos los controles y tarjetas (relleno del tema, color o degradado, y borde); con el vidrio experimental, Glass en su lugar. Un fondo nuevo de control o tarjeta debe ser un Surface
  SurfaceShape.qml    Como Surface, con una forma propia (trazado SVG) y sin borde: los relieves de ControlsTab y SwipeIndicator
  Glass.qml           Vidrio esmerilado (experimental, Settings.glassEffect): lo de detrás (el GlassBackdrop más cercano: fondo de la página propia, la web o las páginas de Main; si no, Main.glassBackdrop) difuminado con velo morado (ShaderEffectSource + MultiEffect). Solo lo usan Surface y SurfaceShape
  GlassBackdrop.qml   Marca el fondo que difumina el vidrio (`glassBackdrop: true`; también la capa `pages` de Main y la vista de BrowserTab)
  GlassAurora.qml     Manchas de color de la marca en ThemeBackground, solo con el vidrio. Todo lo del vidrio lleva «Glass» en el nombre: para quitarlo, ver DESIGN.md → Glass. Hijo z:-1 del fondo del control, que deja su relleno transparente con `glass.active`. Se apaga sin GPU, dentro de las páginas y dentro de algo con `glassOpaque: true` (Configuración)
  ScreenshotOverlay.qml Captura de pantalla (Ctrl+Shift+S): secciones de la página, área libre, ampliar desplazando; copia la capa de las páginas (grabToImage) por trozos
  SiteInfoPopup.qml   Panel del sitio (candado): conexión y certificado, rastreadores del sitio, marcadores, copiar enlace, captura, permisos
  TabsPopup.qml       Lista desplegable de pestañas
  OptionsPopup.qml    Menú de opciones (ventana privada, historial, descargas, perfil, configuración; imprimir no: Ctrl+P y clic derecho)
  BookmarksPopup.qml  Lista de marcadores: guardar la página actual (Ctrl+D), buscar, abrir, quitar
  HistoryPopup.qml    Historial (Opciones → Historial): lo visitado, reabrir la última cerrada, ir a Configuración
  PageRow.qml         Fila de una página guardada (favicon, título, detalle, quitar)
  DownloadsPopup.qml  Listado de descargas (menú de opciones → Descargas)
  ContextMenu.qml     Menú contextual de la página (clic derecho)
  DevToolsWindow.qml  Ventana de herramientas de desarrollo (F12), una por pestaña; paleta propia negra
  ProtectedContentNotice.qml Aviso (PageDialog) de que falta Widevine en una página con contenido protegido
  PopupBackground.qml Fondo común de las listas desplegables
  LazyPopup.qml       Lista desplegable que solo existe abierta (Loader): se crea al abrirla y se destruye al cerrarse
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
  ControlsTab.qml     Pestaña del borde inferior con los controles ocultos (título de la página; al pulsarla, los muestra)
  MediaTab.qml        Pestaña del reproductor: cúpula pequeña en el borde derecho, centrada, solo con el icono, mientras algo suena (sale con un rebote; solo anima al cambiar); al pulsarla, MediaPlayerPopup a su izquierda
  MediaPlayerPopup.qml Reproductor desplegado (LazyPopup en Main): carátula (Canvas: esquinas redondeadas también sin GPU), título, artista, barra de progreso (pulsar o arrastrar) y botones
  FindBar.qml         Buscar en la página (Ctrl+F)
  ZoomIndicator.qml   Indicador de zoom (arriba a la derecha, se cierra solo)
  SwipeIndicator.qml  Deslizar entre páginas con dos dedos (macOS): relieve con la flecha que sale del borde hacia el que se va
  PrintDialog.qml     Imprimir y guardar como PDF (Ctrl+P, menú contextual, window.print(); no en Opciones): ventana propia sobre la página de su pestaña, con vista previa (QtQuick.Pdf) y opciones
  Avatar.qml          Avatar del perfil: foto recortada en círculo (Canvas) o inicial sobre su color
  MemoryPanel.qml     Monitor de rendimiento (Settings.performanceMonitor, Shift+Esc): CPU y memoria con gráfica, GPU, por tipo de proceso y por pestaña
  News.qml            Singleton: noticias de tecnología (RSS), compartidas por todas las pestañas
  TextButton.qml      Botón con texto (primary = degradado de marca; danger = acción arriesgada)
  FormField.qml       Campo de texto de formulario
  urls.js             Texto escrito → URL o búsqueda (con la plantilla que recibe); dominio y favicon de una URL; ruta local ↔ file://. Sin estado: el buscador lo pone SearchEngines
  ResizeHandles.qml   Bordes para redimensionar la ventana sin marco
  FullscreenHint.qml  Aviso «Pulsa Esc/F11 para salir de la pantalla completa»
  Notice.qml          Aviso arriba en el centro con sus botones (cierre inesperado de la sesión anterior: copiar el informe)
  UpdateButton.qml    Botón de actualizar de la barra inferior (tras Opciones, con una versión nueva): anillo con el degradado de la marca y pulso
  UpdatePopup.qml     Confirmación de la actualización («Actualizar ahora»: Confirmar / Cancelar) y avance de la descarga
  ReleaseNotesPage.qml Novedades tras actualizar (título, versión y cambios de CHANGELOG.md), sobre su pestaña (`special: "notes"`); solo la primera vez
  CertificateDialog.qml Aviso de certificado inválido (PageDialog): volver o continuar
  PermissionDialog.qml Permisos de un sitio (PageDialog): cámara, micrófono, ubicación… en cola
  JsDialog.qml        alert, confirm, prompt y aviso de salir de la página (PageDialog), en cola
  FilePicker.qml      Selector de archivos de las páginas (<input type=file>): diálogo del sistema, uno por ventana
  qmldir              Solo para --dev: declara los singletons
assets/         icons/ (SVG de Lucide, nombrados por uso), fonts/ (Nunito), dictionaries/ (es.bdic: corrector, ver su LEEME.md),
                scripts/ (JS que Mitis inyecta: media.js, puente multimedia en las páginas para el reproductor (título, artista, carátula de la Media Session o portada del vídeo, posición y duración; reproducir/pausa, anterior, siguiente y «seek:<segundos>»; ignora llamadas: cámara/micrófono o WebRTC con medios) y aviso de micrófono/cámara ("mitis:capture" por consola);
                devtools.js, tema negro del panel de DevTools; drm.js, detecta páginas que
                piden Widevine cuando falta; swipe.js, solo en macOS y en el mundo de Mitis: si el
                gesto horizontal es de la página; preload.js, con «Precargar páginas»: precarga el
                enlace bajo el ratón)
docs/           Documentación y plan (rendimiento.md: comparativa de memoria; versiones.md: esquema y cómo publicar)
licencias/      LEEME.md (GPL-3.0 de Mitis y cómo se cumple la LGPL de Qt), AVISOS.md (terceros) y textos de licencia; viaja en cada paquete. LICENSE (raíz): GPL-3.0
CHANGELOG.md    Cambios de cada versión, para usuarios («Sin publicar» arriba)
tools/codecs/   Compilar Qt WebEngine con códecs propietarios (H.264, AAC) para Windows y macOS, y página de prueba; guía en docs/codecs.md
tools/          medir_ram.py: mide la RAM de Mitis, Chrome o Firefox con las páginas de paginas.txt
installer/      Instalador de Windows (proyecto CMake aparte, Win32 + GDI+, sin Qt): src/main.cpp (ventana),
                src/instalacion.* (extraer, accesos, registro, desinstalar), empaquetar.ps1 (pega el ZIP al .exe)
assets/branding/ Icono de Mitis (mitis-icon.svg → mitis.png, mitis.ico, mitis.icns; mitis.rc.in lo pone en Mitis.exe con los datos de la versión, que dan el nombre «Mitis» en las notificaciones; el .icns, en Mitis.app), logo completo (mitis-logo-dark/light.svg → .png, Configuración y nueva pestaña), solo el nombre (mitis-wordmark-dark/light.svg → .png, barra de título) y logo de StartCode (startcode.png; startcode-light.png para el tema Claro)
packaging/macos/ Info.plist.in (abre http/https y HTML: navegador predeterminado)
packaging/linux/ PKGBUILD (Arch, mitis-git), appimage.sh (+ apprun-sandbox.sh), mitis.desktop, mitis.svg (copia de mitis-icon.svg)
.github/workflows/compilar.yml  En cada push, Windows (instalador) y macOS (.dmg universal arm64 + x86_64, firma ad hoc, ventana con fondo assets/branding/dmg-fondo.svg vía create-dmg, icono assets/branding/mitis.icns); Linux a mano («todos»); release con etiqueta v* (instalador y .dmg)
```

## Diseño de la interfaz

- **Arriba:** barra de título (en macOS, con los botones de ventana del sistema a la izquierda: círculos de cerrar, minimizar y zoom, y el nombre centrado) con el nombre de Mitis (el del logo, sin icono; versión clara u oscura según el tema) a la izquierda, y a la derecha el avatar del perfil (abre Configuración → Perfil; no en ventanas privadas) y minimizar/maximizar/cerrar. Nada más. Se arrastra para mover y con doble clic maximiza. **Se oculta sola** (oculta desde que se abre Mitis): flota sobre la página, aparece al pasar el ratón por el borde superior (sin maximizar, una franja de tolerancia bajo el borde de redimensionar) y se queda `titleBarHold` (1,5 s) tras quitarlo; con Configuración abierta, siempre visible.
- **Abajo:** controles independientes que flotan sobre la página, **sin barra ni fondo**: atrás, adelante, recargar, campo de dirección, pestañas, marcadores y opciones (y, con una versión nueva, actualizar). La página llega hasta el borde inferior de la ventana y cada control lleva su propio fondo y borde, sin sombra. El progreso de carga va dentro del campo de dirección. **Se ocultan solos** `controlsHold` (1 s) después de dejar de usarlos, para no tapar lo que las páginas fijan abajo; no vuelven al pasar por el borde ni al desplazar: solo al pulsar la pestaña del borde inferior (`ControlsTab`, con el título de la página; pasar el ratón por ella no basta). En la nueva pestaña no se ocultan.
- Botones redondeados y flotantes (`IconButton`). Las listas desplegables de la barra inferior se abren hacia arriba.

## Reglas de código

### QML
- **Colores desde `Colors`; medidas, radios y duraciones desde `Theme`.** Nada de colores escritos a mano en los componentes. `Colors.ink`, `Colors.bgBase`… (propiedad adjunta de `Mitis.Core`, `src/themecolors.*`) dan el color de la ventana del elemento: el tema elegido o, en las ventanas privadas, la paleta `privado` (negro mate). `Theme` es uno para todas las ventanas: un color leído de `Theme` saldría con el tema normal en la ventana privada. Qué token usar en cada caso: `DESIGN.md`.
- Un componente por archivo, en `qml/`, con nombre en PascalCase.
- **Atajo de teclado nuevo** (`Shortcut` de `Main.qml`): añadirlo también a `shortcutGroups` de `SettingsPage.qml` (Configuración → Atajos de teclado), en su grupo; cada grupo es una página de como mucho 6 atajos.
- **Al crear un archivo QML nuevo:** añadirlo a `MITIS_QML_FILES` en `CMakeLists.txt`. Si es singleton, además marcarlo con `QT_QML_SINGLETON_TYPE` y declararlo en `qml/qmldir`.
- Los componentes reciben datos por propiedades (`required property` cuando son obligatorias) y comunican hacia arriba con señales. No acceder a ids de otros archivos.
- Las inline components (`component X: ...`) no ven los ids del archivo que las contiene.
- Para hover en elementos con hijos interactivos, usar `HoverHandler`, no `MouseArea.containsMouse`.
- **Paneles que se abren a demanda: solo existen abiertos** (bajo consumo de RAM; cada ventana, también las privadas, tendría los suyos). Una lista desplegable nueva va dentro de un `LazyPopup` (`popup: Component { … }`; desde fuera: `open()`, `close()`, `opened`, `item`); un panel o una página que se abre y se cierra, en un `Loader` que se activa al abrirlo y se desactiva al terminar de cerrarse (Configuración, captura de pantalla, ventana de imprimir de cada pestaña). Lo que deba durar más que el panel (estado, selección) va fuera de él. Al llamar a algo del panel recién activado, guardarlo antes en una variable (`const menu = loader.item as ContextMenu`): una línea que empieza por `(` se une a la anterior en JavaScript.
- Controles de Qt Quick Controls: importar `QtQuick.Controls.Basic` y estilizar todo (background, contentItem) para que no dependa del estilo del sistema.

### Motor web
- **Solo `BrowserTab.qml` y `BrowserProfile.qml` importan `QtWebEngine`.** El resto de la interfaz habla con las pestañas a través de la API de `BrowserTab` (propiedades `url`, `title`, `icon`, `loading`, `muted`…; funciones `navigate()`, `goBack()`, `mediaState()`…; señales `newTabRequested`, `closeRequested`). Así, cambiar de motor es reescribir esos dos archivos.
- Si la interfaz necesita algo nuevo del motor, se añade a `BrowserTab` (como alias cuando sea una propiedad: no cuesta nada), nunca usando `WebEngineView` desde fuera.
- En C++, el motor aparece en `QtWebEngineQuick::initialize()` de `main.cpp`, en `RequestInterceptor` (ve cada petición de las páginas: bloqueador, parámetros de rastreo, https) y en `EngineBridge` (lo publica en QML como la propiedad de contexto `MitisEngine`, porque los tipos del módulo no existen en `--dev`).
- **Certificado del sitio** (panel del sitio): Qt WebEngine no da el certificado de una conexión válida, así que `EngineBridge::requestCertificate()` abre su propia conexión TLS (`QSslSocket`) al sitio solo cuando se despliega, y responde con `certificateReady` (datos en español, guardados durante la sesión). Una función nueva de `MitisEngine` que QML use antes de recompilar se comprueba con `typeof … === "function"` en `BrowserProfile` (en `--dev` el ejecutable puede ser anterior).
- **Perfiles:** los crea `EngineBridge` en C++: el normal con su nombre de almacenamiento desde el constructor (creado en QML, Qt avisa de que quedará obsoleto y arranca un instante sin disco) y el privado con nombre vacío (`createPrivateProfile()`/`destroyPrivateProfile()`). Viven toda la app, también entre recargas de `--dev`: lo que `BrowserProfile` les pone (scripts, enlaces) debe poder repetirse sin duplicar. `main.cpp` crea el puente antes de la interfaz y lo destruye después de ella y antes de la aplicación.
- **Navegador predeterminado:** los enlaces llegan como argumentos (`Mitis https://…`) o, en macOS, como evento FileOpen. `Links` (C++) deja un solo Mitis por perfil: el que arranca con otro abierto le pasa sus enlaces por `QLocalServer` (canal que depende de la carpeta de datos: un perfil de pruebas con otra carpeta XDG no se los manda al Mitis del usuario) y termina. `Main.qml` (solo la ventana principal) los abre en pestañas nuevas. Registro: `mitis.desktop` (Linux), `Info.plist.in` (macOS) y el instalador (Windows: ProgID `MitisHTML`, `RegisteredApplications`).
- **Opciones de Chromium** (`setupChromiumFlags()` en `main.cpp`, antes de iniciar el motor): sin peticiones en segundo plano, sin `<a ping>`, sin las APIs publicitarias de Privacy Sandbox, y `prefers-color-scheme` según el tema guardado (solo al arrancar: Qt WebEngine no deja cambiarlo en marcha). Las de `QTWEBENGINE_CHROMIUM_FLAGS` van detrás y ganan; un `--disable-features` propio sustituye la lista entera. Límite de procesos, `--process-per-site` y `--enable-low-end-device-mode` se midieron y no ahorran memoria (docs/rendimiento.md).
- **Notificaciones: siempre del sistema, nunca dentro de Mitis.** `SystemNotifier` (`src/notifier.*`) atiende `presentNotification` de los dos perfiles y las manda al sistema; al pulsarlas, `MitisEngine.notificationActivated(origin)` y `Main.qml` trae al frente la pestaña del sitio. Las notificaciones push (sitio cerrado, `pushManager.subscribe`) no existen en Qt WebEngine: no hay servicio push («push service not available»); no fingirlo. Para probar en Linux sin escritorio: un servidor `org.freedesktop.Notifications` falso en un bus de sesión propio (`dbus-daemon --session --fork --print-address`).
- **Atrás y adelante sin la barra:** Qt WebEngine pasa a la página los botones laterales del ratón y los gestos de deslizar, pero no navega. `NavigationGestures` (C++) los observa con un filtro de eventos de la aplicación (solo en las ventanas, sin quedárselos) y `Main.qml` navega (`historyStep()`). Deslizar con dos dedos es desplazamiento con fases (`QWheelEvent::phase()`; la rueda del ratón no tiene): avance → `swipeUpdated`, al soltar → `swipeFinished`; con algo de recorrido, `Main` pregunta a `BrowserTab.swipeAllowed()` (que usa `swipe.js`) si el gesto es de la página: algo que se desplaza hacia ese lado al empezar, `preventDefault` (mapas) o un marco de otra página → no navega. Respeta el ajuste del sistema (`NSEvent.isSwipeTrackingFromScrollEventsEnabled`); con «tres dedos» llega como `SwipeNativeGesture`. Fuera de macOS, solo los botones del ratón (Windows no da fases). Se apagan con `Settings.navigationGestures` (Configuración → Contenido): lo mira `Main.qml`; el filtro sigue observando, que no cuesta nada. *Sin probar en un Mac real*: si cuesta o se dispara solo, ajustar las distancias de `navigationgestures.cpp`.
- **Corrector ortográfico:** solo español (`profile.spellCheckLanguages = ["es"]` en `BrowserProfile`, encendido con `Settings.spellCheck`); no se pueden añadir idiomas ni palabras. El motor lee el diccionario de un archivo: `assets/dictionaries/es.bdic` va en `qtwebengine_dictionaries` junto al ejecutable (compilación y Windows: `installer/empaquetar.ps1`), en `Mitis.app/Contents/Resources` o en `share/mitis` (PKGBUILD, AppImage), y `setupDictionaries()` de `main.cpp` le pasa al motor la que exista (`QTWEBENGINE_DICTIONARIES_PATH`). Las sugerencias salen en el menú contextual (`misspelledWord`, `replace:<palabra>` → `BrowserTab.replaceMisspelledWord`).
- **Precargar páginas** (`Settings.preloadPages`, apagada por defecto; nunca en el perfil privado): `BrowserProfile` inyecta `assets/scripts/preload.js` (mundo de Mitis) y `BrowserTab` activa `dnsPrefetchEnabled`. Con el ratón 65 ms sobre un enlace (o al pulsarlo) precarga la página si es del mismo sitio, con una regla `<script type=speculationrules>` (`prefetch`), y de otro sitio solo abre la conexión (`preconnect`). **No usar `<link rel=prefetch>`**: va a la caché normal y la mayoría de páginas (`no-cache`, `max-age=0`) se vuelven a descargar enteras al navegar; las reglas de precarga guardan la respuesta aparte y la navegación la usa igual (medidas en `docs/rendimiento.md`). La «precarga» de Chrome (predicción de red) no existe en Qt WebEngine.
- **Ventana privada: privada del todo.** Perfil solo en memoria (`EngineBridge::createPrivateProfile`) con su propio `RequestInterceptor` *estricto*: bloqueador (aunque esté apagado, sin sitios permitidos; `ContentBlocker` carga las listas mientras haya una privada), sin parámetros de rastreo, DNT/Sec-GPC y https siempre, y cookies de terceros bloqueadas (filtro del perfil); `BrowserTab` le pone siempre el CSS del bloqueador y oculta la IP local. El interceptor se crea y se destruye con el perfil (se olvidan los hosts sin https). No guarda historial, sesión, descargas en la lista ni permisos de cámara/micrófono (ni usa los guardados), y no se puede entrar en Configuración (`Main.openSettings` no hace nada; Opciones, panel del sitio y nueva pestaña sin esos caminos). Sus colores son los de la paleta `privado` (`Colors`).
- **Caché de las páginas:** en disco (perfil normal; el privado, en memoria) con tope `Settings.cacheSize` en MB (250 de serie; 0 = lo decide Chromium según el disco libre). `EngineBridge` lo pone al crear el perfil, antes de la primera petición, y `BrowserProfile` lo enlaza a `profile.httpCacheMaximumSize` para los cambios. Lo que ocupa (`BrowserProfile.cacheUsage`) lo mide `EngineBridge::requestCacheUsage()` en un hilo, solo al abrir Configuración y tras vaciarla (`clearHttpCacheCompleted`). Los datos que guardan los sitios (Service Worker, IndexedDB) van en la carpeta de datos y no cuentan.
- **DNS cifrado** (`Settings.secureDns`: `off`/`auto`/`secure`, y `secureDnsProvider`; Configuración → Privacidad): `setupSecureDns()` de `main.cpp` lo pasa al motor con `QWebEngineGlobalSettings::setDnsMode` antes de crear los perfiles: solo cambia al volver a arrancar (`Settings.secureDnsPending` lo avisa) y vale para todos los perfiles, también el privado. Los servidores (plantillas DoH) están en `settings.cpp` (`DnsProviders`). Solo las páginas: la red de la interfaz (`NetworkFactory`, actualizaciones, listas del bloqueador) usa el DNS del sistema. De serie, `auto` (con respaldo) y Cloudflare. En «Siempre», los nombres de la red local (MagicDNS de Tailscale, DNS de empresa) dejan de resolver.
- **Imprimir:** nunca la ventana de impresión del motor. `BrowserTab.requestPrint()` (y `window.print()` de la página) emite `printRequested` y `PrintDialog` (en el delegado de Main, en un Loader: solo existe abierta) pide el PDF con `BrowserTab.printToPdf()` a cada cambio de diseño (orientación, papel, fondos), en un archivo temporal de `Printing` (C++, `nextPath`/`useDocument`), que lo usa para la vista previa, lo copia (Guardar) o lo dibuja página a página en la impresora del sistema en un hilo. El motor no admite márgenes ni rango de páginas en `printToPdf` de QML.
- **Descargas:** motor → `BrowserProfile` (`onDownloadRequested`: acepta, registra con `Downloads.add()` y mantiene el modelo con `Downloads.update()` desde las señales del objeto, sin sondeo) → `Downloads.qml` (singleton sin motor: modelo `items`, acciones, y listado de terminadas guardado en `Settings`, categoría `Downloads`) → interfaz, que solo usa `Downloads`. El nombre repetido lo resuelve el propio motor (`archivo (1).ext`).

### Ajustes
- **Todo lo que se guarda entre sesiones va por el singleton `Settings`** (`src/settings.*`, `import Mitis.Core`), nunca por `Settings` de `QtCore`. Las preferencias son propiedades (enlazables, con su clave fija en `settings.cpp`); los datos internos usan `Settings.value("Categoría/clave", porDefecto)` / `Settings.setValue()`.
- Un archivo que necesite además `StandardPaths` importa `QtCore as Core` (`Core.StandardPaths…`): así su `Settings` no choca con el de Mitis.
- Una preferencia nueva que se elija en la interfaz: propiedad en `Settings`, fila en `SettingsPage.qml` y su clave en `resetPreferences()` (`settings.cpp`).
- **Suspensión de pestañas** (Fase 5): `Main.qml` decide cuándo (temporizador: congelar a los 5 min oculta, descargar a los `Settings.suspendAfter`; nunca fijadas ni la del reproductor) y `BrowserTab.suspend()` aplica el estado del motor (`lifecycleState`) con sus excepciones (suena, DevTools, `recommendedState`, permiso de notificaciones, formulario con datos). Al volver a verse, la pestaña se reactiva sola.
- **Memoria del equipo justa** (`Settings.memorySaver`, encendido de serie): cada 10 s `Main.relieveMemory()` pregunta a `MemoryMonitor.systemMemory()` (Linux `/proc/meminfo` MemAvailable; Windows `GlobalMemoryStatusEx`; macOS el nivel de presión `kern.memorystatus_vm_pressure_level`, porque su memoria «libre» engaña). «Justa»: menos del 15 % o de 1 GB; «recuperada»: más del 20 % y de 1,5 GB (el margen evita descargar y recargar en bucle). Mientras está justa, suspende una pestaña oculta por vez (la que lleva más tiempo sin verse, con las excepciones de siempre; se saltan las restauradas sin cargar). El motor va por pasos (`recommendedState`: a una activa solo deja congelarla y, ya congelada, descargarla), así que una pestaña se reintenta si cambió de estado desde el último intento y se descarga en dos ciclos; la que no cambia no se reintenta mientras dure la falta de memoria. Medido (4 pestañas de Wikipedia, `docs/rendimiento.md`): páginas 265 → 146 MB, Mitis 574 → 468 MB. Para probar: `MITIS_MEMORIA_LIBRE=<MB>` en el entorno finge la memoria disponible.
- **Bloqueador de anuncios** (Fase 5): `ContentBlocker` guarda las listas en la carpeta de datos (`filtros/`), las renueva cada 4 días y las compila en un hilo con `FilterEngine` (~335 000 reglas, <1 s, ~4 MB, ~10 µs por petición). Para no romper páginas: la página principal solo se bloquea con reglas `$document`; si el usuario visita un dominio de las listas, sus propios recursos no se bloquean; una regla con opciones que no se entienden (`redirect`, `csp`…) se descarta entera. La ocultación de elementos es solo por sitio: `BrowserTab` pone el CSS del sitio en un script de la vista al empezar cada carga (`MitisEngine.cosmeticCss`). Para probar el motor sin compilar Mitis, basta con compilar `filterengine.cpp` con un `main` que lo use (solo necesita Qt Core).
- Dónde se aplica cada preferencia: las de la página (JavaScript, imágenes, emergentes, modo oscuro, ocultar la barra de desplazamiento, zoom, permisos bloqueados) en `BrowserTab`; las del perfil (idiomas, carpeta, borrar al cerrar) en `BrowserProfile`; las que van petición a petición (cookies de terceros, No rastrear, conexiones seguras, bloqueador y parámetros de rastreo) en C++, en `EngineBridge`/`RequestInterceptor`, enlazadas desde `BrowserProfile`.

### C++
- Lógica pesada, persistencia y todo lo que toque el motor a bajo nivel va en C++, expuesto a QML con `QML_ELEMENT` / `QML_SINGLETON`.
- Los tipos de C++ para QML van en el módulo `Mitis.Core` (biblioteca `mitiscore` en `CMakeLists.txt`, enlazada estática con `Q_IMPORT_QML_PLUGIN` en `main.cpp`): el modo `--dev` no ve los tipos del módulo `Mitis`, pero sí puede importar este. Lo que dependa del motor sigue en `EngineBridge` (`MitisEngine`).
- Cada clase nueva se añade a `qt_add_executable` (o a `mitiscore` si es un tipo de QML) en `CMakeLists.txt`.
- Si se usa un módulo Qt nuevo, añadirlo a `find_package` y a `target_link_libraries`.

### Instalador de Windows (`installer/`)
- No usa Qt (se ejecuta antes de que esté instalado): Win32, GDI+ y miniz (se descarga al configurar, con su hash). CRT estático.
- Sus colores son los de Nocturno copiados en `src/main.cpp`: si cambia el tema, cambiarlos también allí. Medidas a 100 % de escala, multiplicadas por los DPI.
- Si Mitis ya está instalado (clave de desinstalación o `Mitis.exe` en su carpeta), pregunta antes: desinstalar, reinstalar/actualizar o cancelar.
- Formato: `[MitisInstalador.exe][ZIP][desplazamiento 8 bytes][«MITISPAQ»]`. El desinstalador es el mismo `.exe` sin el paquete, con `--desinstalar`. **Lleva Mitis dentro a propósito:** un instalador pequeño que descarga Mitis se probó y Windows Defender lo borraba como virus (sin firma).
- `--actualizar <pid>` (lo usa Mitis al actualizarse): espera a que ese proceso termine, instala sin preguntar y vuelve a abrir Mitis.
- **Actualizaciones** (`src/updater.*`, singleton `Updates`): Mitis lee `version.txt` a los 15 s de arrancar y cada 6 h (`MITIS_SERVIDOR` en el entorno lo sustituye, para pruebas). Con una versión más nueva aparece `UpdateButton` tras Opciones (`BottomBar`) y su confirmación `UpdatePopup`; al confirmar, `Updates.install()` lo prepara y emite `readyToRestart`, y `Main.qml` se cierra como con la ✕ (guarda la sesión y deja `Session/restoreOnce` para restaurarla al volver). Windows: descarga el instalador completo de la versión nueva (clave `windows`) a la carpeta temporal y lo abre con `--actualizar <pid>`, que espera, instala y lo vuelve a abrir (la carpeta temporal la borra Mitis en el siguiente arranque). macOS (`Mitis.app` comprimido con `ditto`, clave `macos`) y Linux solo como AppImage (clave `linux`, variable `APPIMAGE`): Mitis descarga el paquete, comprueba su SHA-256 y un script (`ReplacerScript` en `updater.cpp`) espera a que termine, cambia la app y la abre. Tras actualizarse, la primera vez que arranca, `Updates.takeReleaseNotes()` (versión del arranque anterior en `Updates/lastVersion` o, si no la hay, `Session/restoreOnce`) da la sección de su versión de `CHANGELOG.md` (en los recursos, `:/CHANGELOG.md`; título en la línea `> …`) y `Main.qml` la abre en una pestaña propia (`ReleaseNotesPage` sobre una pestaña con `special: "notes"`, que no se guarda en la sesión ni en las cerradas: no se puede volver a ver). Servidor: `/srv/docker/mitis-releases` (nginx en Docker, `releases/`; ver su LEEME.md).
- Solo se compila en Windows (GitHub Actions); aquí no hay compilador para probarlo.

### General
- Comentarios y mensajes en español, breves, explicando el porqué cuando no es obvio.
- Textos de la interfaz en español.
- Mensajes de commit en español, en imperativo ("Añade...", "Corrige...").
- Un componente de terceros nuevo (biblioteca, fuente, iconos, lista descargada): añadirlo a `licencias/AVISOS.md` con su licencia y, si se distribuye, su texto en `licencias/`. Qt siempre enlazado dinámicamente (LGPL).
- **Versiones y cambios:** la versión solo se cambia en `project(VERSION)` de `CMakeLists.txt`; la etapa, en `MITIS_VERSION_SUFFIX` (`-beta`: versión 0.5.0-beta y «Beta» en la barra de título y el instalador; vacío en las versiones finales). Todo cambio que note el usuario se apunta en `CHANGELOG.md`, sección «Sin publicar», en el mismo commit y redactado para usuarios. Para publicar: `docs/versiones.md`.
- **Regla de versiones: todo se documenta y lo que ya tiene commit ya está publicado.** Cada cambio, corrección o modificación se documenta (CHANGELOG y, si toca, CLAUDE.md, DESIGN.md o `docs/`). Una versión que ya tiene commit se considera desplegada: no se le añaden cambios. Antes de documentar algo nuevo, mirar si la versión de `CMakeLists.txt` ya está en un commit (`git log -p -- CMakeLists.txt`) y, si lo está, subirla según lo que se implementa (funciones nuevas: MENOR; solo correcciones: PARCHE; ver `docs/versiones.md`), cerrar su sección del CHANGELOG con número y fecha, abrir otra «Sin publicar» y apuntar la versión anterior en la tabla de `docs/versiones.md` con su commit.
- **El CHANGELOG lo lee cualquiera:** es lo que sale en la pestaña de novedades al actualizar. Escribirlo en lenguaje claro para quien no sabe de tecnología: qué cambia para quien usa Mitis y dónde lo encuentra, sin nombres de archivos, componentes, librerías ni jerga (nada de «QML», «shader», «favicon», «caché», «proceso»…). Los detalles técnicos van en CLAUDE.md, DESIGN.md o `docs/`.

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
5. GitHub Actions compila con **Qt 6.11.3** (en desarrollo, la de Arch: 6.11.2, con códecs propietarios). Se elige por los parches de seguridad de su Chromium, no por ser la más alta: Qt 6.12.0 tiene el mismo Chromium 140 con parches más antiguos (ver `CHROMIUM_VERSION` de qtwebengine en cada etiqueta). Con códecs propietarios en Windows y macOS es la **6.11.2** (`QT_VERSION`; release `qt-codecs-6.11.2` del repositorio privado `mitis-qt`): el código de Qt WebEngine 6.11.3 no está publicado y no se puede compilar (`docs/codecs.md`). Una versión de Qt distinta puede rechazar QML que la local acepta (p. ej. Qt 6.10 no admite `short` como nombre de variable). Para comprobar con otra versión: instalar su `qmlcachegen` con aqtinstall (`aqt install-qt linux desktop <versión> linux_gcc_64 --archives qtbase qtdeclarative icu`; desde la 6.11 hace falta aqtinstall en desarrollo, ver `AQT_SOURCE` en el workflow) y compilar cada QML con `--only-bytecode --resource-path /qt/qml/Mitis/<archivo>`.
6. Si se toca `devreloader.*`, probar: editar un QML con la app abierta, introducir un error a propósito (la app no debe cerrarse) y corregirlo, y cambiar un valor de `Theme.qml`.

## Cierres inesperados

`CrashReporter` (`src/crashreporter.*`) escribe cada sesión en `informes/sesion.log` de la carpeta de datos (versión, sistema, Chromium y todos los mensajes de Qt y de la interfaz) y termina con «== Cierre normal ==». Una caída añade «== Caída: motivo» y la pila (módulo+desplazamiento) y, en Windows, `sesion.dmp`. Un registro sin cierre normal pasa al arrancar a `cierre-AAAAMMDD-HHMMSS.txt` y Mitis avisa (`Notice` en `Main.qml`, Configuración → Desarrollo). Para leer la pila: los símbolos de esa compilación están en los artefactos `mitis-windows-simbolos` (`Mitis.pdb`; el `.dmp` se abre con WinDbg o Visual Studio) y `mitis-macos-simbolos` (`Mitis.dSYM`: `atos -o Mitis.dSYM/Contents/Resources/DWARF/Mitis -arch arm64 -l 0x100000000 0x100000000+desplazamiento`). En Linux, `addr2line -e build/bin/Mitis desplazamiento` (compilado con símbolos). Los procesos de las páginas (QtWebEngineProcess) no entran: su caída solo deja una línea «Terminó el proceso de una página».

## Problemas conocidos ya resueltos (no reintroducir)

- Mitis se caía tras horas abierto (`WebContentsAdapter::icon()` ← `FaviconProviderHelper::handleImageRequest`, puntero nulo): Qt WebEngine sirve `image://favicon/…` con la **primera** vista que tenga ese icono y le pide el dibujo a su `FaviconDriverQt`; `WebContentsAdapter::discard()` cambia la página interna por otra **sin** ese gestor y `undiscard()` no lo recrea (ni al recargarse), así que una pestaña que se **descargó alguna vez** (suspensión de pestañas, y las restauradas sin cargar, que se descargan al arrancar) tumba a Mitis cuando se pide su icono, aunque ya esté activa, o el de cualquier pestaña de cualquier ventana con el mismo icono. Por eso `BrowserTab.iconRetired` queda en verdadero para siempre tras descargarse (`_everDiscarded`), registra su icono en `BrowserProfile.retiredIcons` (global, solo crece), la interfaz nunca pide un icono retirado (`displayIcon()` en `Main.qml` usa entonces `Urls.favicon`), `BrowserTab` espera 2 s antes de descargar (`_applyState`) y la sesión no guarda direcciones `image://favicon`. Cualquier sitio nuevo que muestre el icono de una pestaña debe pasar por `displayIcon()`. (La 0.9.1 solo lo retiraba mientras estaba descargada y se seguía cayendo al reactivarla.)

- Mitis se caía al cambiar una opción de la ventana de imprimir mientras preparaba la vista previa de una página grande (`ExecutionEngine::fromData` ← `QJSEngine::create` ← `WebContentsAdapter::didPrintPage`): el motor rechaza un PDF nuevo mientras hace otro y entrega un resultado vacío, y `WebEngineView.printToPdf(callback, …)` de Qt 6.11 lo usa sin comprobarlo (`*result`). **Nunca usar la versión con función:** `BrowserTab.printToPdf()` usa la que escribe un archivo (`printToPdf(filePath, …)` + `pdfPrintingFinished(filePath, success)`, que falla con `success` falso) y hace uno a la vez por pestaña (el que llega mientras tanto espera; solo el último).
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

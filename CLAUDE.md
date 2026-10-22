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

- Qt 6.8+ (desarrollo en Arch Linux con Qt 6.11), Qt Quick/QML, Qt WebEngine, Qt SVG, C++17, CMake 3.21+, Ninja.
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
                widevine.*: localiza Widevine (contenido protegido) y se lo pasa al motor)
qml/            Interfaz. Todos los archivos planos en esta carpeta.
  Main.qml            Ventana, modelo de pestañas, navegación, atajos (no conoce el motor)
  BrowserTab.qml      Una pestaña: envuelve WebEngineView y ofrece solo lo que usa la interfaz
  BrowserProfile.qml  Singleton: el perfil (cookies, caché, User-Agent, scripts inyectados)
  Theme.qml           Singleton: colores, medidas, animaciones
  TitleBar.qml        Barra superior: marca (icono + "Mitis") y controles de ventana
  BottomBar.qml       Controles inferiores flotantes: navegación, dirección, pestañas, marcadores, opciones
  AddressBar.qml      Campo de dirección/búsqueda
  TabsPopup.qml       Lista desplegable de pestañas
  OptionsPopup.qml    Lista de opciones; se usa para el menú de opciones y el de marcadores
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
  SearchEngineDialog.qml Diálogo para elegir el motor de búsqueda (menú de opciones)
  NewsCard.qml        Tarjeta de noticia
  MiniPlayer.qml      Mini reproductor sobre la barra de búsqueda
  FindBar.qml         Buscar en la página (Ctrl+F)
  ZoomIndicator.qml   Indicador de zoom (arriba a la derecha, se cierra solo)
  News.qml            Singleton: noticias de tecnología (RSS), compartidas por todas las pestañas
  TextButton.qml      Botón con texto (primary = degradado de marca; danger = acción arriesgada)
  FormField.qml       Campo de texto de formulario
  urls.js             Texto escrito → URL o búsqueda (con la plantilla que recibe); dominio y favicon de una URL. Sin estado: el buscador lo pone SearchEngines
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
docs/           Documentación y plan
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
- En C++, el motor aparece en `QtWebEngineQuick::initialize()` de `main.cpp`, en `RequestInterceptor` (ve cada petición de las páginas; base del futuro bloqueador de anuncios) y en `EngineBridge` (lo publica en QML como la propiedad de contexto `MitisEngine`, porque los tipos del módulo no existen en `--dev`).
- **Descargas:** motor → `BrowserProfile` (`onDownloadRequested`: acepta, registra con `Downloads.add()` y mantiene el modelo con `Downloads.update()` desde las señales del objeto, sin sondeo) → `Downloads.qml` (singleton sin motor: modelo `items`, acciones, y listado de terminadas guardado en `Settings`, categoría `Downloads`) → interfaz, que solo usa `Downloads`. El nombre repetido lo resuelve el propio motor (`archivo (1).ext`).

### C++
- Lógica pesada, persistencia y todo lo que toque el motor a bajo nivel va en C++, expuesto a QML con `QML_ELEMENT` / `QML_SINGLETON`.
- Cada clase nueva se añade a `qt_add_executable` en `CMakeLists.txt`.
- Si se usa un módulo Qt nuevo, añadirlo a `find_package` y a `target_link_libraries`.

### General
- Comentarios y mensajes en español, breves, explicando el porqué cuando no es obvio.
- Textos de la interfaz en español.
- Mensajes de commit en español, en imperativo ("Añade...", "Corrige...").

## Cómo verificar cambios

1. `cmake --build build` sin errores ni advertencias nuevas.
2. `qmllint` sobre los QML modificados (está en `/usr/lib/qt6/bin`).
3. Ejecutar y comprobar que no hay errores de QML en la salida:
   - En modo normal y en `--dev`: el modo `--dev` carga los QML de otra forma y puede fallar aunque el normal funcione.
   - Si la salida no es una terminal, Qt manda los mensajes a journald: `journalctl --user --since "-1min" | grep Mitis`.
4. Sin pantalla se puede verificar visualmente (no hay Xvfb ni xdotool; sí Xvnc y ffmpeg). Usar una pantalla distinta de `:1`, que es la del usuario:
   ```bash
   Xvnc :7 -geometry 1400x900 -depth 24 -SecurityTypes None -localhost & export DISPLAY=:7
   ./build/bin/Mitis &
   sleep 15; ffmpeg -loglevel error -y -f x11grab -video_size 1400x900 -i :7 -frames:v 1 captura.png
   ```
   WebEngine tarda en pintar la primera página: esperar al menos 15 s.
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
- Ctrl+Mayús+Tab no hacía nada: un `Shortcut` con varias secuencias equivalentes (`Ctrl+Shift+Tab`, `Ctrl+Backtab`…) es **ambiguo** consigo mismo y Qt emite `activatedAmbiguously`, no `activated`. Usar una sola secuencia por pulsación (y, si hay riesgo, atender también `onActivatedAmbiguously`).
- Una descarga cortada por el servidor mostraba "Download canceled by the user": Chromium envía motivos de interrupción que Qt no tiene en su enumeración (p. ej. 38, la descarga llegó incompleta) y para ellos `interruptReasonString` miente. `BrowserProfile` los traduce por número y nunca usa ese texto.
- Google no dejaba iniciar sesión ("Es posible que el navegador o la aplicación no sean seguros", página `/signin/rejected`): rechaza los navegadores con motor embebido y las versiones de Chrome viejas. Los delataban las Client Hints (`sec-ch-ua`) y `navigator.userAgentData` (solo "Chromium", sin "Google Chrome"), la versión del motor (140, cuando Chrome estable va por la 153) y `navigator.plugins` vacío. Solución, solo en `accounts.google.com`: `RequestInterceptor` (C++) declara el Chrome vigente en `User-Agent`, `sec-ch-ua` y `sec-ch-ua-full-version-list`, y un script inyectado desde `BrowserProfile` hace lo mismo con `navigator.userAgent`/`userAgentData`; `BrowserTab` activa los complementos (visor de PDF). Si Google vuelve a rechazar, subir `CurrentChromeVersion` en `requestinterceptor.cpp`. No disfrazarse de Firefox: la conexión (TLS, HTTP/2) es de Chromium y no casa. Las Client Hints las añade el motor: el interceptor puede reemplazarlas, no quitarlas.
- El panel de DevTools salía claro aunque se eligiera el tema oscuro: Chromium solo aplica el tema tras cargar `devtools://theme/colors.css`, que Qt WebEngine no incluye. `devtools.js` desactiva su ajuste `chrome-theme-colors` y entonces el tema se aplica al momento. Sus variables de color (`--sys-color-*`) se sobrescriben con `!important`: el panel las define con selectores más específicos. La vista del panel debe recibir `inspectedView` **después** de crearse: pasado en `createObject()` el panel se queda en blanco.
- Al cerrar la ventana, Mitis desaparecía pero el proceso seguía vivo: el motor QML era hijo de `app` y se destruía a mitad del cierre de esta, y Qt WebEngine se quedaba bloqueado. `main.cpp` destruye la interfaz a mano tras `app.exec()`.
- WhatsApp Web (y otros sitios) rechazaban a Mitis: el User-Agent de Qt WebEngine incluye `QtWebEngine/x.y.z` → `BrowserProfile.qml` lo quita al arrancar. Se conserva la versión real de Chromium: no inventar una más nueva.

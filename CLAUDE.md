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

- Qt 6.5+ (desarrollo en Arch Linux con Qt 6.11), Qt Quick/QML, Qt WebEngine, Qt SVG, C++17, CMake 3.21+, Ninja.
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
                networkfactory.*: red de la interfaz QML con caché en disco)
qml/            Interfaz. Todos los archivos planos en esta carpeta.
  Main.qml            Ventana, modelo de pestañas, navegación, atajos
  Theme.qml           Singleton: colores, medidas, animaciones
  TitleBar.qml        Barra superior: marca (icono + "Mitis") y controles de ventana
  BottomBar.qml       Controles inferiores flotantes: navegación, dirección, pestañas, marcadores, opciones
  AddressBar.qml      Campo de dirección/búsqueda
  TabsPopup.qml       Lista desplegable de pestañas
  OptionsPopup.qml    Lista de opciones; se usa para el menú de opciones y el de marcadores
  PopupBackground.qml Fondo común de las listas desplegables
  PopupAction.qml     Fila de acción de una lista: icono, texto y atajo
  IconButton.qml      Botón base, flotante y redondeado
  Icon.qml            Icono SVG de assets/icons/ coloreado con el tema
  Tooltip.qml         Tooltip propio: acción y atajo de teclado
  NewTabPage.qml      Página de nueva pestaña (una sola, sobre la pestaña sin dirección)
  QuickLinkTile.qml   Acceso rápido de la página de nueva pestaña
  QuickLinkEditor.qml Diálogo para añadir un acceso rápido
  NewsCard.qml        Tarjeta de noticia
  MiniPlayer.qml      Mini reproductor sobre la barra de búsqueda
  News.qml            Singleton: noticias de tecnología (RSS), compartidas por todas las pestañas
  TextButton.qml      Botón con texto (primary = degradado de marca)
  FormField.qml       Campo de texto de formulario
  urls.js             Texto escrito → URL o búsqueda; dominio de una URL
  ResizeHandles.qml   Bordes para redimensionar la ventana sin marco
  qmldir              Solo para --dev: declara los singletons
assets/         icons/ (SVG de Lucide, nombrados por uso), fonts/ (Nunito),
                scripts/ (JS que Mitis inyecta en las páginas: media.js, puente multimedia)
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
- WhatsApp Web (y otros sitios) rechazaban a Mitis: el User-Agent de Qt WebEngine incluye `QtWebEngine/x.y.z` → `Main.qml` lo quita al arrancar. Se conserva la versión real de Chromium: no inventar una más nueva.

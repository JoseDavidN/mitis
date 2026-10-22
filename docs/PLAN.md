# Plan de desarrollo de Mitis

Cada fase deja el navegador usable. No empezar una fase sin cerrar los criterios de la anterior.
Al completar una tarea, marcarla con `[x]`.

---

## Fase 0 · Base ✅

- [x] Proyecto CMake con Qt 6 WebEngine, multiplataforma.
- [x] Modo desarrollo `--dev` con recarga en caliente (incluye singletons y recuperación ante errores).
- [x] Ventana sin marco del sistema, redimensionable por bordes y esquinas.
- [x] Barra de título superior: icono y nombre "Mitis", minimizar/maximizar/cerrar.
- [x] Controles inferiores flotantes sobre la página, sin barra de fondo: atrás, adelante, recargar/detener, dirección, botón de pestañas, botón de opciones.
- [x] Menú de opciones con las entradas futuras (historial, descargas, perfil, configuración) como "Próximamente".
- [x] Botón de marcadores (☆) junto al de opciones, con su lista ("Añadir esta página", "Ver marcadores") como "Próximamente".
- [x] Arrastrar ventana desde la barra de título; doble clic maximiza.
- [x] Pestañas: abrir, cerrar, cambiar; lista desplegable con favicon y título.
- [x] Barra de dirección: distingue URL de búsqueda (DuckDuckGo).
- [x] Barra de progreso de carga.
- [x] Perfil persistente (cookies, sesiones, caché).
- [x] Tema oscuro centralizado en `Theme.qml`: Nocturno (violeta/rosa), documentado en `DESIGN.md`.
- [x] Atajos: Ctrl+T, Ctrl+W, Ctrl+L, Ctrl+Tab, Ctrl+Shift+Tab, Ctrl+Shift+A, Ctrl+R/F5, Alt+←/→.

---

## Fase 1 · Identidad visual

Objetivo: que Mitis se vea como un producto propio y no como un prototipo.

- [x] Iconos SVG propios en `assets/icons/` (atrás, adelante, recargar, detener, pestañas, minimizar, maximizar, restaurar, cerrar, nueva pestaña). Componente `Icon.qml` que los colorea según `Theme`.
- [x] Reemplazar los caracteres Unicode de `TitleBar`, `BottomBar` y `TabsPopup` por `Icon`.
- [ ] Icono de Mitis en la barra de título (hoy es un cuadrado con degradado provisional). *Pospuesta: el icono está en diseño.*
- [x] Fuente propia empaquetada en `assets/fonts/` (Nunito), registrada en `main.cpp` como fuente de toda la interfaz; tamaños en `Theme`.
- [x] Tooltips propios (componente `Tooltip.qml`) en los botones, con el atajo de teclado.
- [ ] Icono de la aplicación (ventana, barra de tareas, `.ico` para Windows, `.icns` para macOS). *Pospuesta: el icono está en diseño.*
- [ ] Tema claro y cambio de tema en caliente (`Theme.dark: bool`). *Pospuesta.*

**Criterios:** ningún carácter Unicode como icono, todo se ve nítido a 100 % y 200 % de escala, el cambio de tema no requiere reiniciar.

> **Fase abierta a propósito (2026-10-20).** Se pasa a la Fase 2 con las tareas marcadas *Pospuesta* sin hacer: el icono de Mitis aún se está diseñando y el tema claro se deja para más adelante. Se retoman cuando el icono esté listo.

---

## Fase 2 · Pestañas completas

- [x] Reabrir pestaña cerrada (Ctrl+Shift+T), con una pila de las últimas 20. Reabre la dirección; el historial atrás/adelante de esa pestaña no se conserva.
- [x] Reordenar pestañas arrastrando dentro de la lista.
- [x] Fijar pestañas (quedan arriba en la lista, no se cierran con Ctrl+W).
- [x] Buscar entre pestañas: campo de filtro al abrir la lista.
- [x] Navegar la lista con teclado (flechas, Enter, Supr).
- [x] Abrir enlace en nueva pestaña con clic central y Ctrl+clic.
- [x] Indicador de pestaña con audio, y silenciar desde la lista.
- [x] Mini reproductor sobre la barra de búsqueda: título de lo que suena, anterior, play/pausa y siguiente. Lee y controla la página con `assets/scripts/media.js` (Media Session y elementos `<video>`/`<audio>` del marco principal).
- [x] Página de nueva pestaña propia en QML (no HTML): buscador central, accesos rápidos manuales, noticias de tecnología (RSS de Google Noticias) y fondo del tema o imagen propia. Preferencias con `QtCore.Settings` (pasarán al `Settings` de la Fase 4).

**Criterios:** con 50 pestañas abiertas, la lista sigue fluida y cada acción funciona con teclado y ratón.

---

## Fase 3 · Navegación completa

- [x] **Separar la conexión con el motor** antes de añadir más: un componente `BrowserTab.qml` que envuelva `WebEngineView` y ofrezca a la interfaz solo lo que usa (`url`, `title`, `icon`, `loading`, `loadProgress`, `canGoBack/Forward`, `goBack()`, `reload()`, `muted`, `audible`, estado y control multimedia, ventanas nuevas), y el perfil (`WebEngineProfile`, User-Agent, scripts inyectados) en un solo sitio. Ningún otro archivo debe usar tipos de `QtWebEngine`. Así, cambiar de motor en el futuro es reescribir ese componente sin tocar la interfaz.
- [x] Buscar en la página (Ctrl+F) con barra propia: siguiente, anterior, contador de coincidencias. Barra flotante centrada bajo la barra de título; F3/Ctrl+G y Mayús+F3/Ctrl+Mayús+G.
- [x] Zoom por pestaña (Ctrl+ +/-/0), con indicador arriba a la derecha que se cierra solo a los 2 s. Se mantiene al navegar dentro de la pestaña.
- [x] Pantalla completa de páginas (vídeos) y F11 para la ventana. Se oculta toda la interfaz con un aviso de cómo salir (Esc / F11); en F11 los controles aparecen al acercar el ratón al borde inferior.
- [x] Menú contextual propio (clic derecho): enlace, imagen, vídeo/audio, texto seleccionado, campo editable y página. «Inspeccionar» abre las herramientas de desarrollo.
- [x] Descargas: gestionar `downloadRequested`, panel de descargas con progreso, abrir carpeta. Botón que aparece solo al descargar (con anillo de progreso), panel de la descarga actual (se queda 10 s al terminar) y listado en Opciones → Descargas, guardado entre sesiones.
- [x] Permisos (cámara, micrófono, ubicación, notificaciones) con diálogo propio. `PermissionDialog` sobre la página de la pestaña («ejemplo.com quiere usar tu cámara», Bloquear/Permitir), con cola; la respuesta la guarda el motor por sitio (`persistentPermissionsPolicy` en disco) y, para cámara y micrófono, que el motor no guarda, `BrowserProfile` (Settings, categoría `Permissions`). Bloquear el ratón se concede sin preguntar. Sube el mínimo a Qt 6.8 (`permissionRequested`).
- [x] Diálogos JavaScript propios (alert, confirm, prompt) y selector de archivos. `JsDialog` sobre la página de la pestaña («ejemplo.com dice»), en cola, con el aviso de salir con cambios sin guardar (`beforeunload`); se cancelan al cargar otra página. `<input type=file>` abre el diálogo del sistema (`FilePicker`) con el filtro de tipos de la página.
- [x] Certificados inválidos: aviso propio antes de continuar. `CertificateDialog` sobre la página de la pestaña, con el host y el motivo en español; «Volver» (la opción segura, vuelve a la página anterior) o «Continuar de todos modos» si se puede. Un host aceptado no vuelve a preguntar en la sesión y `BrowserTab.certificateBypassed` lo indica.
- [x] DevTools (F12) en ventana aparte. `DevToolsWindow`, una por pestaña, sin marco, redondeada y con paleta propia (negro, blanco y acento cian, letra gruesa), también para el panel de Chromium (`assets/scripts/devtools.js`). F12 abre y cierra; «Inspeccionar» en el menú contextual.
- [x] Motor de búsqueda configurable. Singleton `SearchEngines` (DuckDuckGo por defecto, Google, Bing, Brave Search, Ecosia, Startpage y uno personalizado con `%s`), guardado entre sesiones; se elige en Configuración → Búsqueda (en la Fase 3, de forma provisional, en Opciones → Motor de búsqueda) y lo usan la barra de dirección, la nueva pestaña y el menú contextual.
- [x] Contenido protegido (DRM) con **Widevine**, para Netflix, Spotify web, Disney+, Prime Video, etc. Qt WebEngine lo admite pero no lo incluye: la biblioteca de Widevine (`libwidevinecdm`) es de Google y no se puede redistribuir con Mitis.
  - Qt WebEngine de Arch: compilado con Widevine y códecs propietarios (H.264, AAC). Windows y macOS: ver *Códecs propietarios* en la Fase 6.
  - `src/widevine.*` busca la biblioteca que dejaron Google Chrome, Chromium (`chromium-widevine` en Arch) o Firefox en Linux, Windows y macOS, elige la de versión más alta y se la pasa al motor con `--widevine-path` antes de iniciarlo (respeta una ruta puesta a mano en `QTWEBENGINE_CHROMIUM_FLAGS`).
  - Sin ella, `assets/scripts/drm.js` detecta la página que pide Widevine y `ProtectedContentNotice` explica cómo instalarlo (una vez por sitio y sesión).
  - Probado con el módulo oficial (4.10.2891.0): un vídeo cifrado con Widevine se descifra y reproduce. En Linux el módulo es de nivel L3 (por software): los servicios limitan la calidad (Netflix, 720p).
  - [ ] Pendiente: probar con Spotify web y el mini reproductor (hace falta una cuenta y un equipo con Widevine instalado).

**Criterios:** se puede usar Mitis como navegador principal un día completo sin abrir otro.

---

## Fase 4 · Persistencia (C++)

- [x] Ajustes con `QSettings`, expuestos a QML como singleton `Settings` (`src/settings.*`, módulo `Mitis.Core`, que también funciona en `--dev`). Usan las mismas claves que `Settings` de `QtCore`: lo ya guardado se conserva. Migradas la página de nueva pestaña (`NewTab`), el buscador (`Search`), el listado de descargas (`Downloads`) y los permisos de cámara y micrófono (`Permissions`).
- [ ] Crear el perfil en C++ (hoy es un `WebEngineProfile` en `Main.qml`, que desde Qt 6.9 avisa de que quedará obsoleto y arranca un instante en modo incógnito antes de pasar a disco). Debe seguir accesible en `--dev`.
- [x] Restaurar sesión al abrir: pestañas y pestaña activa. Las pestañas restauradas **no cargan** hasta que se seleccionan. Se guarda en `Settings` (`Session/tabs`: dirección, título, icono, fijada y la activa) un segundo después de cada cambio y al cerrar; `BrowserTab.deferred` + `load()`. Se puede desactivar en Configuración → Al iniciar.
- [x] Historial en SQLite (Qt SQL), con escritura en segundo plano. Singleton `History` (`src/history.*`): una fila por dirección (título, última visita, visitas) en `history.sqlite`; escribe en un hilo propio (WAL) y lee en el de la interfaz. Cuenta cada página a la que se llega (`BrowserTab.pageLoaded`, también los cambios de dirección sin recarga). Nunca desde una ventana privada.
  - Opciones → Historial (`HistoryPopup`, también Ctrl+H): solo el listado de lo visitado (abrir, quitar), «Reabrir la última pestaña cerrada» y «Historial en Configuración».
  - Configuración → Borrar datos de navegación (historial y listado de descargas por periodo; cookies, caché y permisos de sitios, enteros).
- [x] Sugerencias en la barra de dirección a partir del historial y los marcadores: al escribir, hasta 6 (marcadores primero; del historial, primero las que empiezan por lo escrito y las más visitadas). Flechas para elegir, Enter para abrir, Esc para cerrarlas. Pendiente: no distingue acentos («pag» no encuentra «Página»).
- [x] Marcadores: añadir (Ctrl+D), listar, buscar, eliminar. Singleton `Bookmarks` (`src/bookmarks.*`, `bookmarks.sqlite`) y `BookmarksPopup` en el botón de marcadores, que se ilumina si la página está guardada.
- [x] Ventana privada (perfil `offTheRecord`): Opciones → Nueva ventana privada o Ctrl+Shift+N. Otra ventana `Main` con «Privada» en la barra de título; su perfil (`BrowserProfile.privateProfile`, en memoria) se crea con la primera y se descarta al cerrar la última. No guarda historial, sesión ni sus descargas en el listado.
- [x] Página de ajustes en QML. `SettingsPage`: Opciones → Configuración; página propia sobre las pestañas (no es una pestaña), con índice de secciones, en el estilo del tema. Se cierra con Esc, con la ✕ o al cambiar de pestaña.
  - [x] Elección del **motor de búsqueda** en la sección Búsqueda (lista y buscador personalizado). Quitados `SearchEngineDialog` y su entrada del menú de opciones; la categoría `Search` pasa al singleton `Settings`.
  - [x] Opción **«Herramientas de desarrollo»** (sección Desarrollo, desactivada por defecto): solo con ella activa aparecen «Inspeccionar» en el menú contextual y funciona F12. Al desactivarla se cierran las ventanas de DevTools abiertas.
  - [x] Además: imagen de fondo de la nueva pestaña, carpeta de descargas y «Acerca de Mitis» (versión, Chromium, si hay Widevine).
  - [x] Al iniciar (continuar donde lo dejaste) e Historial y privacidad (borrar datos de navegación por periodo), con las tareas de sesión e historial.
  - [x] Ajustes básicos de un navegador, aplicados al momento y sin coste de memoria (los aplica el motor o el interceptor):
    - Al iniciar: continuar donde lo dejaste, pestaña nueva o una página concreta.
    - Apariencia e idioma: zoom predeterminado (Ctrl+0 vuelve a él), modo oscuro en las páginas (`forceDarkMode`), idiomas de las páginas (`Accept-Language`). El tamaño de letra no: `WebEngineSettings` no lo ofrece en QML.
    - Privacidad: bloquear cookies de terceros (filtro del almacén de cookies), borrar cookies y caché al cerrar (y al abrir, por si el cierre no terminó), No rastrear (`DNT` y `Sec-GPC`), ocultar la IP local en WebRTC.
    - Seguridad: conexiones seguras (`RequestInterceptor` pide por https las páginas http; si falla la conexión o el certificado, vuelve a http para ese host en la sesión; no en la red local), bloquear ventanas emergentes sin clic, JavaScript.
    - Permisos de sitios: bloquear por tipo sin preguntar (ubicación, cámara, micrófono, notificaciones, portapapeles, pantalla) y lista de lo decidido para cada sitio, con «olvidar».
    - Contenido: imágenes y reproducción automática. Descargas: preguntar en qué carpeta guardar. Acerca de: restablecer la configuración (se conservan los datos).
    - Suspender pestañas y los flags de Chromium quedan para la Fase 5.

**Criterios:** cerrar y abrir Mitis deja todo como estaba, y el arranque con 30 pestañas restauradas usa casi la misma RAM que con una.

---

## Fase 5 · Consumo de RAM

El diferencial de Mitis. Medir antes y después de cada cambio.

- [ ] Herramienta de medición: RAM total de Mitis y por pestaña (procesos del renderer), visible en un panel de desarrollo.
- [ ] Suspensión de pestañas: inactivas más de N minutos pasan a `Frozen`, luego a `Discarded` (`WebEngineView.lifecycleState`). No suspender si reproducen audio, tienen formularios con datos o están fijadas.
- [ ] Indicador visual de pestaña suspendida en la lista.
- [ ] Bloqueador de anuncios y rastreadores en C++ con `QWebEngineUrlRequestInterceptor` y listas tipo EasyList, compiladas a una estructura rápida al arrancar.
- [ ] Ajustar flags de Chromium (`QTWEBENGINE_CHROMIUM_FLAGS`): límite de procesos de renderizado, desactivar servicios en segundo plano que no se usan.
- [ ] Comparativa documentada en `docs/rendimiento.md`: Mitis frente a Chrome y Firefox con el mismo conjunto de páginas.

**Criterios:** con 20 pestañas (5 activas), Mitis usa claramente menos RAM que Chrome en el mismo equipo.

---

## Fase 6 · Distribución

- [ ] GitHub Actions: compilar en Linux, Windows y macOS en cada push.
- [ ] Empaquetado: `windeployqt` + instalador en Windows, `macdeployqt` + `.dmg` en macOS, AppImage y `PKGBUILD` para Arch. El usuario final no instala Qt: va dentro del paquete (unos 150–250 MB instalado, por Chromium).
- [ ] **Códecs propietarios (H.264, AAC):** el Qt WebEngine oficial de Windows y macOS no los incluye. Sin ellos no funcionan Spotify, Netflix ni muchos vídeos. Hay que compilar Qt WebEngine con `-DFEATURE_webengine_proprietary_codecs=ON` (varias horas) y revisar el licenciamiento de patentes de esos códecs para los países de distribución. En Arch no hace falta: el paquete de la distribución ya los trae.
- [ ] Cumplir la LGPL de Qt: enlazar Qt de forma dinámica, incluir su licencia y permitir sustituir sus bibliotecas.
- [ ] **Inicio de sesión de Google** (Gmail, YouTube…): Google lo rechaza ("Es posible que el navegador o la aplicación no sean seguros", página `/signin/rejected`). *Pendiente.* Ya probado sin éxito, solo en `accounts.google.com`:
  - Quitar `QtWebEngine/x.y.z` del User-Agent (se hace en todas las páginas; arregló WhatsApp Web, no Google).
  - Presentarse como Firefox (User-Agent y JavaScript): incoherente, la conexión es de Chromium y las Client Hints siguen diciendo "Chromium".
  - Presentarse como Google Chrome: marca "Google Chrome" en `sec-ch-ua`/`sec-ch-ua-full-version-list` (interceptor) y en `navigator.userAgentData` (script), visor de PDF activo (`navigator.plugins` = 5) y versión declarada 153 (el motor es 140). Es lo que hay ahora en el código (`RequestInterceptor`, `BrowserProfile`).
  - Próximos pasos: comprobar si un Chromium real es rechazado en el mismo entorno (servidor por VNC, sin GPU ni audio): si lo es, la causa es el entorno y no Mitis; probar desde un escritorio normal; probar con Qt WebEngine más reciente (motor ≥ versión que Google admita); revisar otras señales (`window.chrome.*`, WebGL, `navigator.credentials`/FedCM).
- [ ] Versionado y changelog.
- [ ] Licencia.

**Criterios:** alguien sin Qt instalado puede descargar Mitis y usarlo en cualquiera de los tres sistemas.

---

## Ideas para después

- Paneles laterales opcionales (notas, lector).
- Modo lectura.
- Sincronización entre equipos.
- Extensiones (evaluar costo en RAM antes de considerarlo).

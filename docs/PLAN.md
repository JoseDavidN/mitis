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

- [ ] **Separar la conexión con el motor** antes de añadir más: un componente `BrowserTab.qml` que envuelva `WebEngineView` y ofrezca a la interfaz solo lo que usa (`url`, `title`, `icon`, `loading`, `loadProgress`, `canGoBack/Forward`, `goBack()`, `reload()`, `muted`, `audible`, estado y control multimedia, ventanas nuevas), y el perfil (`WebEngineProfile`, User-Agent, scripts inyectados) en un solo sitio. Ningún otro archivo debe usar tipos de `QtWebEngine`. Así, cambiar de motor en el futuro es reescribir ese componente sin tocar la interfaz.
- [ ] Buscar en la página (Ctrl+F) con barra propia: siguiente, anterior, contador de coincidencias.
- [ ] Zoom por pestaña (Ctrl+ +/-/0), con indicador en la barra.
- [ ] Pantalla completa de páginas (vídeos) y F11 para la ventana.
- [ ] Menú contextual propio (clic derecho): abrir en pestaña nueva, copiar enlace, guardar imagen, inspeccionar.
- [ ] Descargas: gestionar `downloadRequested`, panel de descargas con progreso, abrir carpeta.
- [ ] Permisos (cámara, micrófono, ubicación, notificaciones) con diálogo propio.
- [ ] Diálogos JavaScript propios (alert, confirm, prompt) y selector de archivos.
- [ ] Certificados inválidos: aviso propio antes de continuar.
- [ ] DevTools (F12) en ventana aparte.
- [ ] Motor de búsqueda configurable.
- [ ] Contenido protegido (DRM) con **Widevine**, para Netflix, Spotify web, Disney+, Prime Video, etc. Qt WebEngine lo admite pero no lo incluye: la biblioteca de Widevine (`libwidevinecdm`) es de Google y no se puede redistribuir con Mitis. Hay que:
  - Comprobar que el Qt WebEngine de cada plataforma está compilado con soporte de Widevine y con códecs propietarios (H.264, AAC); si no, Spotify y Netflix no reproducen aunque esté la biblioteca.
  - Localizar la biblioteca ya instalada (la de Google Chrome, o en Arch el paquete `chromium-widevine` de AUR) y pasarla al motor con `--widevine-path` en `QTWEBENGINE_CHROMIUM_FLAGS` antes de iniciar WebEngine.
  - Si no se encuentra, avisar con un mensaje propio en la página que lo pide, explicando cómo instalarlo.
  - Probar con Spotify web y el mini reproductor.

**Criterios:** se puede usar Mitis como navegador principal un día completo sin abrir otro.

---

## Fase 4 · Persistencia (C++)

- [ ] Ajustes con `QSettings`, expuestos a QML como singleton `Settings`. Migrar las preferencias de la página de nueva pestaña (`NewTabPage.qml`, categoría `NewTab`).
- [ ] Crear el perfil en C++ (hoy es un `WebEngineProfile` en `Main.qml`, que desde Qt 6.9 avisa de que quedará obsoleto y arranca un instante en modo incógnito antes de pasar a disco). Debe seguir accesible en `--dev`.
- [ ] Restaurar sesión al abrir: pestañas y pestaña activa. Las pestañas restauradas **no cargan** hasta que se seleccionan.
- [ ] Historial en SQLite (Qt SQL), con escritura en segundo plano.
- [ ] Sugerencias en la barra de dirección a partir del historial y los marcadores.
- [ ] Marcadores: añadir (Ctrl+D), listar, buscar, eliminar. Se conectan al botón ☆ y a su lista (`bookmarksPopup` en `Main.qml`).
- [ ] Ventana privada (perfil `offTheRecord`).
- [ ] Página de ajustes en QML.

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
- [ ] Versionado y changelog.
- [ ] Licencia.

**Criterios:** alguien sin Qt instalado puede descargar Mitis y usarlo en cualquiera de los tres sistemas.

---

## Ideas para después

- Paneles laterales opcionales (notas, lector).
- Modo lectura.
- Sincronización entre equipos.
- Extensiones (evaluar costo en RAM antes de considerarlo).

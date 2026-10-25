# Plan de desarrollo de Mitis

Solo lo pendiente, agrupado por área. Lo ya hecho (Fases 0–6, hasta la
versión 0.5.0) está en [CHANGELOG.md](../CHANGELOG.md) y en el historial de git.

Al terminar una tarea, quitarla de aquí y apuntar el cambio en `CHANGELOG.md`
(sección «Sin publicar»). Una tarea nueva va en el área que le corresponda.

---

## Interfaz

- [x] **Redimensionar la ventana sin parpadeos.** Al cambiar el tamaño, el contenido aparece y desaparece buscando acomodarse al nuevo tamaño; debe ser fluido.
  - Corregido (2026-10-22): el campo de dirección animaba su ancho con cada cambio de tamaño y siempre iba por detrás; ahora solo se anima al empezar o dejar de escribir. **Pendiente: comprobarlo en Windows** (en el servidor, sin gestor de ventanas, no se puede reproducir un redimensionado real) y, si sigue, ver qué parpadea.
  A investigar si sigue:
  - Qué parpadea: la página (WebEngineView, que el motor vuelve a pintar a cada tamaño y deja huecos mientras tanto) o la interfaz QML (barra inferior, página de nueva pestaña, Configuración).
  - El redimensionado de la ventana sin marco ya usa el del sistema (`startSystemResize`): no es la causa.
  - Mientras dura el redimensionado: rellenar con el color de fondo del tema lo que la página aún no ha pintado (en lugar de negro o restos del tamaño anterior), y evitar que los elementos anclados se recoloquen a saltos (animaciones o `Behavior` que se disparen con cada cambio de tamaño).
  - Probarlo en Windows (donde se vio) y en Linux.

## Funcionalidad

- [x] **Transparencia con desenfoque: probarla en Windows y macOS** (Configuración → Apariencia, experimental; ya en todos los controles, con velo gris). La fila de la opción dice si se dibuja con la GPU y con qué API. En el servidor de desarrollo Qt no puede copiar lo que pinta Chromium (sin GPU) y los controles se ven grises. Si con GPU real se ve la página difuminada, se queda como está: **opción que se activa a mano, nunca encendida por defecto**, con el velo gris (oscuro en Nocturno y Oscuro, claro en el Claro); el aspecto normal y sus colores no cambian. Si sale transparente sin difuminar o gris: arreglarlo o quitar la opción. Medir también el gasto de GPU con un vídeo detrás.


- [ ] **Gestor de contraseñas: Proton Pass integrado** (pedido 2026-10-23). Solo Proton Pass; el llavero de iCloud se descartó (su extensión depende de la app de Apple por *native messaging* y es código privado: no se puede incluir). La idea: su extensión de Chrome (código abierto, GPL-3, Manifest V3) **dentro de Mitis, cargada y activa siempre** desde `EngineBridge` (`profile->extensionManager()->loadExtension()` + `setExtensionEnabled()`), con su botón y su ventana en la interfaz de Mitis (`actionPopupUrl`) y **sin sección de extensiones**: el navegador sigue cerrado, no se pueden instalar otras.
  - **Bloqueado por el motor.** Probado con Qt WebEngine 6.11.2 (Proton Pass 1.42.0): carga y se activa sin errores, pero dentro de la extensión no existe ninguna API de Chrome (`chrome.runtime`, `storage`, `tabs`… salen `undefined`) y su *service worker* no arranca; su ventana sale en blanco. La documentación de Qt (desde 6.10) no dice qué APIs admite.
  - **Comprobar con cada versión nueva de Qt:** descargar la extensión (`https://clients2.google.com/service/update2/crx?response=redirect&prodversion=140.0&acceptformat=crx3&x=id%3Dghmbeldphafepmbegfdlkpapadhbakde%26uc`), quitar la cabecera del `.crx` (es un zip detrás de `Cr24` + longitud de la cabecera), cargarla con `loadExtension()` en una prueba, abrir `chrome-extension://<id>/popup.html` con `QTWEBENGINE_REMOTE_DEBUGGING` y mirar si `typeof chrome.runtime` deja de ser `undefined` y si aparece su *service worker* en `/json`. Necesita al menos: `runtime`, `storage`, `scripting`, `tabs`/`activeTab`, `webNavigation`, `webRequest`, `alarms`, `offscreen` y la ventana de la acción.
  - Si llega a funcionar: incluir la extensión en los paquetes (y su licencia en `licencias/AVISOS.md`), cargarla al arrancar (no en ventanas privadas: el motor no lo permite), y decidir cómo se actualiza (con cada versión de Mitis).

## Motor web

- [x] **Contenido protegido en Windows: HBO Max y Apple Music no reproducen** (2026-10-22; el sonido y el resto de vídeos sí). HBO Max: «Código de error: 1k-0003». Apple Music: no suena; en la consola solo aparece el informe de error que la página intenta mandar a `xp.apple.com` (bloqueado por ser telemetría, `ERR_ACCESS_DENIED`), que es consecuencia del fallo y no su causa. A investigar; causas probables, que pueden sumarse:
  - Bloqueador descartado en Apple Music: con «Permitir en apple.com» tampoco suena (sale el aviso propio de Apple Music de que no puede reproducir el contenido). Con el bloqueador activo ese aviso no aparecía: revisar si alguna regla impide que la página muestre sus errores. En HBO Max, falta probarlo con «Permitir en».
  - **Siguiente paso:** probar los dos servicios con la 0.11.0, que ya lleva los códecs propietarios (H.264, AAC; el contenido de los servicios de streaming suele ir en esos formatos y Apple Music transmite la música en AAC), antes de investigar más.
  - Widevine: comprobar que Mitis lo encuentra en ese equipo (Configuración → Acerca de Mitis) y que la licencia se concede. Servicios como HBO Max, Netflix o Disney+ exigen además que el navegador esté firmado para Widevine (VMP, *Verified Media Path*): Chrome, Edge y Firefox lo están; un navegador con Qt WebEngine no. Investigar si se puede firmar (por ejemplo, el servicio EVS de castlabs, que lo hace para Electron) y qué exige.
- [x] **Códecs propietarios (H.264, AAC) en Windows y macOS: queda comprobarlo en los paquetes.** Compilados (2026-10-24) con Qt **6.11.2** en Windows y en macOS (universal), probados en el Mac con `prueba-codecs.html` y publicados en el release `qt-codecs-6.11.2` del repositorio privado `mitis-qt`, con las variables del workflow puestas (`docs/codecs.md`). Pendiente:
  - Ver en la primera compilación de GitHub que el paso «Qt WebEngine con códecs propietarios» se ejecuta (no *skipped*) en Windows y macOS, e instalar el instalador y el `.dmg` en equipos **sin** Qt para repetir la prueba (paso 4 de «Comprobar que funcionan»).
  - Revisar las patentes de esos códecs para los países de distribución (nota en `docs/codecs.md`).

## Distribución

- [x] **Servidor de descargas y actualizaciones** (desde 2026-10-23). De momento, por IP y sin cifrar: `http://100.67.58.55/mitis` (`/srv/docker/mitis-releases`, en la red de Tailscale: solo llega a los equipos de esa red, y Tailscale cifra el tráfico).
  - Pendiente: subir a `releases/` el artefacto `mitis-servidor` de la versión (ver `docs/versiones.md`, «Publicar una versión»).
  - Probar en Windows: actualizar desde Mitis (que descargue el instalador, se cierre, se actualice y se vuelva a abrir con sus pestañas) y que no quede nada en la carpeta temporal tras el siguiente arranque.
  - Probar en macOS: actualizar desde Mitis con la app en Aplicaciones (que se cierre, se cambie y se abra sin el aviso de Gatekeeper).
  - Linux: se actualiza solo el AppImage; instalado con el `PKGBUILD`, lo actualiza el sistema de paquetes (Mitis solo avisa).
  - **Antes de publicarlo fuera de Tailscale:** dominio con HTTPS y paquetes firmados. Hoy el SHA-256 solo detecta descargas dañadas: quien controle la red o el servidor podría servir otro programa.

- [ ] Probar en GitHub Actions la compilación de Linux (AppImage): solo a mano (Run workflow → «todos»).
- [ ] Probar el AppImage en una distribución distinta de Arch y el `PKGBUILD` con `makepkg`.
- [ ] Firmar el instalador de Windows y la app de macOS (y notarizarla): sin firma, SmartScreen y Gatekeeper avisan al abrirlos. Requiere certificados de pago.

---

## Propuestas por elegir (2026-10-24)

Mejoras propuestas tras revisar el código; se irán eligiendo. Al elegir una, pasarla a su
área de arriba. En el orden de cada grupo: primero lo que más rinde para lo que cuesta.

### Rendimiento y memoria

- [ ] **Tope a la caché de disco** del perfil (`httpCacheMaximumSize`, ahora sin poner:
  decide Chromium), p. ej. 250 MB, y un botón en Configuración para vaciarla.
- [ ] **Dormir pestañas según la memoria libre del equipo:** con la memoria justa,
  descargar antes las pestañas más antiguas (además del tiempo de `suspendAfter`), con
  lo que ya mide `MemoryMonitor`.
- [ ] **Vidrio experimental más barato:** cada `Glass` redibuja lo de detrás en cada
  fotograma (`live: true`). Si se queda, actualizarlo solo cuando cambie la página o el
  control se mueva; si no, gasta GPU y batería en portátiles.
- [ ] **Atrás y adelante al instante:** medir si al volver la página se recarga o sale de
  la caché de páginas anteriores (*back-forward cache*) y, si se recarga, ver si Qt
  WebEngine permite activarla.

### Funciones

- [ ] **Importar desde Chrome y Firefox** marcadores e historial (sus archivos SQLite y
  JSON en la carpeta del perfil de cada uno).
- [ ] **Ajustes por sitio** en Configuración: el zoom, los permisos y los sitios
  permitidos en el bloqueador, en una lista para revisarlos y quitarlos.
- [ ] **Buscar entre las pestañas abiertas** desde la lista de pestañas.

### Ajustes

- [ ] **Aceleración por hardware** (activar o desactivar; `--disable-gpu` al arrancar, como
  las demás opciones de `setupChromiumFlags()`): para pantallas negras o parpadeos con
  controladores de gráficos problemáticos.

---

## Ideas para después

- Paneles laterales opcionales (notas, lector).
- Modo lectura.
- Sincronización entre equipos (y cuenta en el perfil).
- Extensiones (evaluar costo en RAM antes de considerarlo).

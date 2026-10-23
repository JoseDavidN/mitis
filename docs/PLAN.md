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

- [ ] **Transparencia con desenfoque: probarla en Windows y macOS** (Configuración → Apariencia, experimental; ya en todos los controles, con velo gris). La fila de la opción dice si se dibuja con la GPU y con qué API. En el servidor de desarrollo Qt no puede copiar lo que pinta Chromium (sin GPU) y los controles se ven grises. Si con GPU real se ve la página difuminada, se queda como está: **opción que se activa a mano, nunca encendida por defecto**, con el velo gris (oscuro en Nocturno y Oscuro, claro en el Claro); el aspecto normal y sus colores no cambian. Si sale transparente sin difuminar o gris: arreglarlo o quitar la opción. Medir también el gasto de GPU con un vídeo detrás.

- [ ] **Captura de pantalla** de la página, desde el panel del sitio (candado del campo de dirección), como en Zen: la parte visible o la página entera, y guardarla (carpeta de descargas) o copiarla al portapapeles. Una acción más en `SiteInfoPopup`, bajo «Copiar enlace»; la imagen la da el motor (`WebEngineView.grabToImage` para lo visible; para la página entera, por partes desplazando o con el protocolo de DevTools).

## Identidad visual

- [ ] Icono de macOS: el workflow de macOS ya genera `mitis.icns` y lo sube como artefacto «icono-macos»; descargarlo y guardarlo en `assets/branding/mitis.icns` (CMake lo usa si está).
- [ ] Versión simplificada del icono para 16–32 px (barra de tareas, pestañas): a ese tamaño las ondas se empastan y la gota casi no se ve.

## Motor web

- [ ] **Contenido protegido en Windows: HBO Max y Apple Music no reproducen** (2026-10-22; el sonido y el resto de vídeos sí). HBO Max: «Código de error: 1k-0003». Apple Music: no suena; en la consola solo aparece el informe de error que la página intenta mandar a `xp.apple.com` (bloqueado por ser telemetría, `ERR_ACCESS_DENIED`), que es consecuencia del fallo y no su causa. A investigar; causas probables, que pueden sumarse:
  - Bloqueador descartado en Apple Music: con «Permitir en apple.com» tampoco suena (sale el aviso propio de Apple Music de que no puede reproducir el contenido). Con el bloqueador activo ese aviso no aparecía: revisar si alguna regla impide que la página muestre sus errores. En HBO Max, falta probarlo con «Permitir en».
  - **Siguiente paso:** probar los dos servicios con un Qt WebEngine compilado con códecs (tarea siguiente) antes de investigar más.
  - Faltan los códecs propietarios (H.264, AAC) en el Qt WebEngine oficial de Windows: el contenido de los servicios de streaming suele ir en esos formatos; Apple Music transmite la música en AAC (ver la tarea siguiente).
  - Widevine: comprobar que Mitis lo encuentra en ese equipo (Configuración → Acerca de Mitis) y que la licencia se concede. Servicios como HBO Max, Netflix o Disney+ exigen además que el navegador esté firmado para Widevine (VMP, *Verified Media Path*): Chrome, Edge y Firefox lo están; un navegador con Qt WebEngine no. Investigar si se puede firmar (por ejemplo, el servicio EVS de castlabs, que lo hace para Electron) y qué exige.
- [ ] **Códecs propietarios (H.264, AAC) en Windows y macOS:** el Qt WebEngine oficial no los incluye; sin ellos no funcionan Spotify, Netflix ni muchos vídeos. En Arch no hace falta: el paquete de la distribución ya los trae.
  - Preparado (`docs/codecs.md`, `tools/codecs/`): scripts para compilar Qt WebEngine con `-DFEATURE_webengine_proprietary_codecs=ON` en un equipo propio (varias horas: más que el límite de GitHub Actions) y página de prueba (`prueba-codecs.html`). El workflow lo usa en lugar del Qt oficial si se definen las variables del repositorio `QT_VERSION` y `QT_CODECS_RELEASE`.
  - Pendiente: compilarlo, publicarlo y revisar las patentes de esos códecs para los países de distribución (nota en `docs/codecs.md`).

## Distribución

- [ ] **macOS en GitHub Actions** (desde 2026-10-22, en cada push: `.dmg` universal, Apple Silicon e Intel, con firma ad hoc): comprobar que el primer run pasa y probar el `.dmg` en un Mac de cada tipo (Gatekeeper avisará: sin firma de Apple). Con códecs, el archivo de Qt WebEngine también tiene que ser universal (`compilar-macos.sh --arquitecturas "arm64;x86_64"`).
- [ ] Probar en GitHub Actions la compilación de Linux (AppImage): solo a mano (Run workflow → «todos»).
- [ ] Probar el AppImage en una distribución distinta de Arch y el `PKGBUILD` con `makepkg`.
- [ ] Firmar el instalador de Windows y la app de macOS (y notarizarla): sin firma, SmartScreen y Gatekeeper avisan al abrirlos. Requiere certificados de pago.

---

## Ideas para después

- Paneles laterales opcionales (notas, lector).
- Modo lectura.
- Sincronización entre equipos (y cuenta en el perfil).
- Extensiones (evaluar costo en RAM antes de considerarlo).

# Versiones de Mitis

## Esquema

[Semantic Versioning](https://semver.org/lang/es/) (`MAYOR.MENOR.PARCHE`), adaptado a la etapa del proyecto:

- **Mientras sea 0.x**, la interfaz y los datos aún pueden cambiar sin aviso.
  - **MENOR** sube con cada conjunto de funciones nuevas que merezca publicarse (tareas del [plan](PLAN.md)). Hasta la 0.5.0 coincidió con las fases del plan original (Fase 5 → `0.5.0`).
  - **PARCHE** sube con versiones que solo corrigen errores (o cambios menores sin funciones nuevas): `0.5.1`, `0.5.2`…
- **1.0.0** llegará cuando alguien sin Qt instalado pueda descargar Mitis y usarlo de verdad en Linux, Windows y macOS: con los paquetes de los tres probados, firmados y con contenido protegido funcionando (ver el [plan](PLAN.md)).
- **A partir de 1.0**, SemVer normal: MAYOR si se pierden datos o ajustes al actualizar o desaparece algo que se usaba, MENOR con funciones nuevas, PARCHE con correcciones.

Historial con este esquema (ver [CHANGELOG.md](../CHANGELOG.md)):

| Versión | Contenido | Commit |
|---|---|---|
| 0.1.0 | Esqueleto del proyecto (no publicada) | `f5d23db` |
| 0.2.0 | Fases 0, 1 (parcial) y 2: interfaz propia y pestañas completas | `12afc15` |
| 0.3.0 | Fase 3: navegación completa | `d2fa2ac` |
| 0.4.0 | Fase 4: persistencia y Configuración | `d6cfa89` |
| 0.5.0 | Fase 5 y casi toda la 6: memoria, suspensión, bloqueador, temas, instalador y paquetes | el de «Publica la versión 0.5.0» |
| 0.6.0 | Interfaz que se oculta sola, perfil, icono y logo, mini reproductor nuevo, monitor de rendimiento, notificaciones del sistema, aviso de micrófono y cámara, instalador que también desinstala, panel del sitio, tonos de Configuración en toda la interfaz y transparencia con desenfoque (experimental) | `51bf4ba` |
| 0.7.0 | Monitor de rendimiento con la API de dibujo, transparencia con desenfoque (experimental) en toda la interfaz, .dmg universal de macOS con su ventana y botones de macOS, GPU en macOS, pestaña vacía al descargar, rueda en Configuración | `c673816` |
| 0.8.0 | Captura de pantalla, tonos morados de la transparencia, esquinas redondeadas (Windows 11 y macOS), listas plegadas en Configuración, nombre centrado y .dmg corregido en macOS, barras que se ocultan antes | `1f9f412` |
| 0.9.0 | Actualizaciones desde el servidor de descargas (botón tras Opciones), informes de cierres inesperados, logo en la nueva pestaña, «Mitis» en vez de «Mitis.exe» en Windows, memoria real en el monitor de Windows | `0e8f5eb` |
| 0.9.1 | Corrige la caída con pestañas suspendidas (iconos de pestañas descargadas) | `e22e038` |
| 0.10.0 | Pestaña de novedades tras actualizar, vidrio experimental en toda la interfaz, controles sin bordes, pestaña de relieve, panel con todas las descargas | `be4392a` |
| 0.10.1 | Corrige la caída al volver a una pestaña que se había descargado (iconos de pestañas que se descargaron alguna vez) | `0d25aba` |
| 0.11.0 | Atrás y adelante con gestos de macOS y botones del ratón, corrector en español, imprimir y guardar como PDF con ventana propia, códecs propietarios en Windows y macOS | `6fa68b2` |
| 0.12.0 | Precargar páginas, paneles creados al abrirlos, relieve redondo del gesto, corrige la caída al cambiar opciones de impresión | `be19b71` |
| 0.13.0 | Ventana privada negro mate con privacidad siempre activa y sin Configuración, DNS cifrado (automático de serie), lista de atajos de teclado | `eec1a98` |

Las fases 0–2 van juntas en 0.2.0 porque entraron en un solo commit. Esas versiones no tienen etiqueta ni release: son anteriores al workflow de publicación. Si se quieren marcar, basta con etiquetas ligeras (`git tag v0.4.0 d6cfa89`); al subirlas no se publica nada porque esos commits no tienen `.github/workflows/`.

**Versión actual: 0.14.0-beta** (en desarrollo, en la rama `ajustes`; la 0.13.0 ya tiene commit y se da por publicada). Cambia el reproductor (pestaña en el borde derecho y reproductor desplegable con carátula y barra de progreso), los controles de abajo salen al pulsar su pestaña y trae el tope de la caché (250 MB de serie) la descarga de pestañas con la memoria del equipo justa e «Ir a la pestaña» en las sugerencias de la dirección: sube MENOR. Se publica al subir la etiqueta `v0.14.0`.

**Regla:** una versión con commit ya está desplegada. Lo siguiente que se haga va en una versión nueva, subida según lo que traiga (MENOR con funciones nuevas, PARCHE con solo correcciones), y su sección del CHANGELOG se escribe en lenguaje claro para quien no sabe de tecnología: es lo que se ve en la pestaña de novedades.

## Dónde vive la versión

Una sola fuente: `project(Mitis VERSION x.y.z)` en `CMakeLists.txt`. Nunca se escribe en otro sitio; todo lo demás sale de ahí:

- `MITIS_VERSION` (definición del compilador) → `QGuiApplication::setApplicationVersion()` en `src/main.cpp` → `Qt.application.version` en Configuración → Acerca de Mitis.
- `MACOSX_BUNDLE_*_VERSION` → versión de `Mitis.app` en macOS.
- El workflow (`.github/workflows/compilar.yml`) la lee de `CMakeLists.txt` y se la pasa al instalador de Windows (`-DMITIS_VERSION`, que la muestra en «Aplicaciones instaladas») y a los nombres de los paquetes: `Mitis-x.y.z-Instalador.exe`, `Mitis-x.y.z-macOS.dmg`, `Mitis-x.y.z-macOS.zip`. El trabajo «Servidor de descargas» la escribe en `version.txt`, la que Mitis compara para actualizarse.
- La etiqueta de git (`vx.y.z`) debe coincidir; el workflow lo comprueba antes de publicar.

`qt_add_qml_module(... VERSION 1.0)` es la versión de los módulos QML (`Mitis`, `Mitis.Core`), no la de Mitis: no se toca.

## Registro de cambios

`CHANGELOG.md`, formato [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/):

- Cada cambio que note quien usa Mitis se apunta en **«Sin publicar»** en el mismo commit que lo introduce, en la sección que toque: **Añadido**, **Cambiado**, **Corregido**, **Eliminado**.
- Se escribe para usuarios: qué cambia al usar Mitis, no cómo está hecho. Los cambios internos sin efecto visible no se apuntan.
- Las notas de cada release de GitHub son la sección de su versión en `CHANGELOG.md`.
- **Pestaña de novedades:** al arrancar por primera vez tras actualizarse, Mitis abre una pestaña con la sección de su versión (la de «Sin publicar» si aún no tiene la suya): un título, la versión y los cambios. El título es una línea `> Título` justo debajo del encabezado de la versión (si falta, «Mitis se ha actualizado»). Es la única vez que se ve: escribir los cambios pensando en esa pestaña.

## Publicar una versión

1. Comprobar que `main` compila en las tres plataformas (último run de GitHub Actions en verde).
2. Subir la versión en `CMakeLists.txt`: `project(Mitis VERSION 0.5.0 ...)`.
3. En `CHANGELOG.md`, renombrar `## [Sin publicar]` a `## [0.5.0] - AAAA-MM-DD` y dejar encima un `## [Sin publicar]` vacío.
4. Si la versión cierra una fase, marcarla en `docs/PLAN.md`.
5. Commit: `git commit -am "Publica la versión 0.5.0"`.
6. Etiqueta anotada: `git tag -a v0.5.0 -m "Mitis 0.5.0"`.
7. Subir el commit y la etiqueta: `git push origin main v0.5.0`.
8. El workflow compila, comprueba que la etiqueta coincide con `project(VERSION)`, extrae las notas de `CHANGELOG.md` y publica el release con el instalador, el `.dmg`, el `.zip` de macOS y `version.txt`.
9. **Servidor de descargas** (`MITIS_SERVIDOR`, de momento `http://100.67.58.55/mitis`, servido por `/srv/docker/mitis-releases`): copiar en su carpeta `releases/` el contenido del artefacto `mitis-servidor` (el instalador de Windows, el `.dmg` y el `.zip` de macOS, el AppImage si se compiló y `version.txt`), reemplazando los anteriores. `version.txt` va el último: en cuanto cambia, los Mitis instalados avisan para actualizarse. Los paquetes de la versión anterior se pueden borrar después.
10. Revisar el release en GitHub. Si algo falla, corregir en `main`, borrar la etiqueta (`git push --delete origin v0.5.0`, `git tag -d v0.5.0`) y volver a etiquetar; si el release ya se descargó, mejor publicar `0.5.1`.

# Plan de desarrollo de Mitis

Solo lo pendiente, agrupado por área (revisado el 2026-11-12, versión 0.24.0;
lo anterior se descartó o quedó dentro de esto). Lo ya hecho está en
[CHANGELOG.md](../CHANGELOG.md) y en el historial de git. Prioridad: Linux con
Wayland y Hyprland; Windows y macOS siguen funcionando, pero no van primero.

Al terminar una tarea, quitarla de aquí y apuntar el cambio en `CHANGELOG.md`
(sección «Sin publicar»). Una tarea nueva va en el área que le corresponda. En
cada área, primero lo que más rinde para lo que cuesta.

---

## Rendimiento y memoria

- [ ] **Vidrio experimental más barato.** `Glass` redibuja lo de detrás en cada
  fotograma (`live: true` en `qml/Glass.qml`) aunque no cambie nada: con el vidrio
  encendido gasta GPU sin parar. Actualizarlo solo cuando cambie la página o se
  mueva el control, o quitar la opción si no compensa.
- [ ] **Mitis en reposo en Hyprland.** Medir con una página quieta y Mitis nativo
  en Wayland si la interfaz redibuja sin motivo (animaciones o temporizadores que
  siguen con los controles ocultos, `QSG_RENDER_LOOP`, fotogramas por segundo
  con nada en movimiento). Lo que gasta CPU sin hacer nada es lo que más pesa en
  un equipo lento (Celeron N2840).
- [ ] **Opción para apagar la aceleración gráfica** (`--disable-gpu` en
  `setupChromiumFlags()`, con «Reiniciar ahora»): para pantallas negras o
  parpadeos con controladores de gráficos problemáticos.

## Bloqueador de anuncios

- [ ] **Lista de avisos de cookies** (EasyList Cookie o «Annoyances – Cookie
  notices» de uBlock): quita los carteles de «aceptar cookies». El bloqueador ya
  lee ese formato; falta añadir la lista a `ContentBlocker` y una opción para
  apagarla (Configuración → Privacidad).
- [ ] **«Ocultar este elemento»** desde el menú contextual: elegir con el ratón lo
  que se escapó (banners, avisos fijos) y guardarlo como regla del sitio, con una
  lista en Ajustes por sitio para quitarlas.

## Linux y Hyprland

- [ ] **Probar en el equipo real** (aquí solo hay Xvnc, sin GPU ni portal):
  - El AppImage de GitHub Actions en Hyprland: que use el plugin `wayland` y no
    XWayland (`QT_DEBUG_PLUGINS=1`).
  - Vídeo por la GPU: `chrome://media-internals` con un vídeo
    («kVideoDecoderName»: VaapiVideoDecoder) o `intel_gpu_top`; Bay Trail solo
    decodifica H.264 (con «Vídeos de YouTube en un formato más ligero»).
  - Llaves de acceso con el iPhone (`src/hybrid.*`): entrar y crear una llave en
    Google y GitHub. Si no conecta, el registro dice en qué paso («Llave de acceso
    con el móvil: …»). También con un Android y con una llave USB.
  - Compartir pantalla propio: en una llamada real de Meet, Teams o Discord, y con
    una pantalla girada (`WaylandCapture::frameReady`).
  - Pantalla encendida con un vídeo y `hypridle`; al pausar, que vuelva a
    bloquearse.
  - Diálogos de archivos por el portal al subir un archivo.
  - El AppImage en otra distribución y el `PKGBUILD` con `makepkg`.

## Navegación y funciones nuevas

- [ ] **Modo lectura con interfaz propia:** sacar el artículo con Readability (la
  biblioteca de Firefox, Apache-2.0) en el mundo de Mitis y mostrarlo en QML con
  la letra y los colores de Mitis. Sin nada de la página: incluso se puede
  descargar la pestaña mientras se lee.
- [ ] **Paleta de órdenes (Ctrl+K):** un campo que busca en pestañas, marcadores,
  historial y acciones («ventana privada», «captura», «perfil 2»…). Todo con el
  teclado, como en Hyprland.
- [ ] **Espacios o grupos de pestañas** (como Zen): separar trabajo y ocio en la
  misma ventana sin abrir otro perfil (cada perfil cuesta ~310 MB).
- [ ] **Importar desde Chrome y Firefox** marcadores e historial (sus archivos
  SQLite y JSON en la carpeta de cada perfil).

---

## Descartado (2026-11-12)

- **Imagen dentro de imagen (vídeo flotante):** Qt WebEngine no la trae; hacerla
  a mano obliga a sacar el vídeo de la página fotograma a fotograma.
- **Traducir páginas:** Qt no lo trae y obligaría a mandar el texto a un servicio
  de fuera.
- **Pestañas divididas:** en Hyprland se colocan dos ventanas lado a lado.
- **Aviso de falta de memoria a las páginas (parche de Qt WebEngine):** medido el
  2026-11-12, la limpieza a fondo de JavaScript ahorra 10–25 MB entre todas las
  pestañas (más solo en páginas que acumulan basura) y el aviso de Chromium no
  llega a las páginas. No compensa compilar y mantener un Qt WebEngine propio en
  Linux (`docs/rendimiento.md`).
- **Vulkan:** Qt WebEngine dibuja las páginas por su cuenta y no lo usaría; en
  gráficas Intel antiguas (Bay Trail) el controlador de Vulkan está incompleto.

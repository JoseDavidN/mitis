# Cambios en Mitis

Todos los cambios que notará quien usa Mitis, versión a versión.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/); las versiones siguen el esquema de [docs/versiones.md](docs/versiones.md).

## [Sin publicar]

## [0.5.0] - 2026-10-22

### Añadido

- Mitis se puede elegir como navegador predeterminado en Windows, macOS y Linux: los enlaces de otras aplicaciones se abren en una pestaña nueva de la ventana que ya está abierta.
- **Suspensión de pestañas.** Las pestañas que no usas dejan de gastar memoria: se congelan a los 5 minutos ocultas y se descargan pasado el tiempo que elijas en Configuración → Rendimiento (15 min, 30 min, 1 h, 2 h o nunca). Al volver a una, se recupera sola. Nunca se suspenden las fijadas, las que suenan, las del mini reproductor, las que tienen un formulario a medio rellenar ni las que pueden avisarte con notificaciones (un chat, por ejemplo).
- La lista de pestañas muestra las suspendidas atenuadas y con una luna; al pasar el ratón dice si está congelada o descargada.
- **Bloqueador de anuncios y rastreadores**, integrado y sin extensiones: usa EasyList, EasyPrivacy, EasyList en español, HaGeZi Pro y las excepciones de uBlock Origin, que se descargan solas y se renuevan cada 4 días. Además quita de los enlaces los parámetros de rastreo (`utm_*`, `fbclid`, `gclid`…). En Configuración → Anuncios y rastreadores: activarlo, actualizar las listas y permitir anuncios en un sitio concreto. En páginas con mucha publicidad ahorra cientos de MB.
- **Temas Claro y Oscuro**, además del Nocturno de siempre, en Configuración → Apariencia e idioma. El cambio es inmediato; las páginas que tienen versión oscura siguen al tema desde el siguiente arranque.
- Panel de uso de memoria (Mayús+Esc u Opciones → Uso de memoria, con las herramientas de desarrollo activadas): memoria total de Mitis, reparto por tipo de proceso y lo que gasta cada pestaña.
- **Instalador para Windows**: un solo `.exe` que funciona sin conexión y sin permisos de administrador, crea accesos en el menú Inicio y el escritorio, aparece en «Aplicaciones instaladas» con su desinstalador (que conserva tus datos) y actualiza encima una versión ya instalada. Aún sin firma digital: Windows SmartScreen avisará al abrirlo.
- Paquete `.dmg` para macOS (sin firmar: Gatekeeper avisará al abrirlo).
- Cada versión publicada incluye el instalador de Windows y el `.dmg` de macOS, generados automáticamente.

### Cambiado

- Mitis hace menos cosas por su cuenta: sin peticiones de red en segundo plano, sin los avisos de rastreo al pulsar enlaces (`<a ping>`) y sin las funciones publicitarias de Chromium (Topics, Protected Audience y similares), que desaparecen de las páginas.
- Las pestañas restauradas al abrir Mitis ya no ocupan memoria hasta que las abres (antes cada una gastaba unos 18 MB).
- El perfil del navegador se crea de otra forma por dentro: Mitis arranca directamente con tus datos y la ventana privada se abre sin avisos. Se conservan cookies, sesiones y permisos.

### Corregido

- Ya se puede iniciar sesión en Google (Gmail, YouTube…): antes Google rechazaba a Mitis por «navegador no seguro».

- Un clic en la lista de pestañas llegaba también a la página de debajo (por ejemplo, abría una noticia de la nueva pestaña).
- Mover una pestaña en la lista por encima de la activa la cargaba o la despertaba sin necesidad.

## [0.4.0] - 2026-10-22

### Añadido

- **Configuración** propia (Opciones → Configuración): página con índice de secciones para el arranque, apariencia e idioma, búsqueda, privacidad, seguridad, permisos de sitios, contenido, descargas, desarrollo y «Acerca de Mitis».
- **Historial** (Ctrl+H u Opciones → Historial): lo visitado, con opción de quitar entradas, y «Reabrir la última pestaña cerrada». Nunca se guarda desde una ventana privada.
- Borrar datos de navegación: historial y descargas por periodo; cookies, caché y permisos de sitios.
- **Marcadores**: guardar la página (Ctrl+D), buscar, abrir y quitar. La estrella se ilumina si la página ya está guardada.
- Sugerencias en la barra de dirección a partir de los marcadores y el historial, elegibles con las flechas.
- **Ventana privada** (Ctrl+Mayús+N u Opciones → Nueva ventana privada): no guarda historial, sesión ni descargas, y lo olvida todo al cerrar la última.
- **Continuar donde lo dejaste**: al abrir, vuelven las pestañas de la última vez (sin cargarse hasta que las eliges). También se puede empezar con una pestaña nueva o con una página concreta.
- Ajustes de navegador: zoom predeterminado, modo oscuro forzado en las páginas, idiomas de las páginas, bloquear cookies de terceros, borrar cookies y caché al cerrar, «No rastrear», ocultar la IP local en WebRTC, conexiones seguras (https siempre que se pueda), bloquear ventanas emergentes, JavaScript, imágenes, reproducción automática y preguntar dónde guardar cada descarga.
- Permisos de sitios: bloquear por tipo sin preguntar (ubicación, cámara, micrófono, notificaciones, portapapeles, pantalla) y ver u olvidar lo decidido para cada sitio.
- Opción «Herramientas de desarrollo» (desactivada de serie): solo con ella aparecen «Inspeccionar» y F12.
- «Acerca de Mitis»: versión, versión de Chromium y si hay Widevine. Restablecer la configuración sin perder los datos.

### Cambiado

- El buscador se elige en Configuración → Búsqueda; desaparece del menú de opciones.

## [0.3.0] - 2026-10-21

### Añadido

- **Buscar en la página** (Ctrl+F), con anterior/siguiente (F3, Mayús+F3) y contador de coincidencias.
- **Zoom** por pestaña (Ctrl + +/−/0), con un indicador que se oculta solo.
- **Pantalla completa** para vídeos y para la ventana (F11), con aviso de cómo salir.
- **Menú contextual** propio (clic derecho) para enlaces, imágenes, vídeo y audio, texto, campos de texto y la página.
- **Descargas**: botón con el progreso mientras descargas, panel de la descarga actual y listado en Opciones → Descargas que se conserva entre sesiones.
- Diálogos propios para **permisos** de los sitios (cámara, micrófono, ubicación, notificaciones), recordando lo que respondes.
- Diálogos propios para los avisos de las páginas (alert, confirm, prompt, salir con cambios sin guardar) y selector de archivos del sistema.
- Aviso de **certificado no válido** antes de entrar en una página, con la opción segura de volver.
- **Herramientas de desarrollo** (F12) en ventana aparte, con tema oscuro.
- **Motor de búsqueda** a elegir: DuckDuckGo (de serie), Google, Bing, Brave Search, Ecosia, Startpage o uno personalizado.
- **Contenido protegido** (Netflix, Spotify, Disney+, Prime Video…): Mitis usa el módulo Widevine que hayan instalado Chrome, Chromium o Firefox. Si falta, lo explica en la propia página.

### Corregido

- Ctrl+Mayús+Tab no cambiaba a la pestaña anterior.
- Una descarga cortada por el servidor aparecía como «cancelada por el usuario».
- Al cerrar la ventana, Mitis seguía funcionando en segundo plano.

## [0.2.0] - 2026-10-21

### Añadido

- Interfaz propia: barra de título con minimizar, maximizar y cerrar, y controles flotantes abajo (atrás, adelante, recargar, dirección, pestañas, marcadores y opciones). La ventana se mueve desde la barra de título y se redimensiona por los bordes.
- Tema **Nocturno** (violeta y rosa), iconos propios, letra Nunito y tooltips con el atajo de cada botón.
- Barra de dirección que distingue direcciones de búsquedas, con el progreso de carga dentro.
- **Pestañas**: abrir, cerrar, cambiar, reordenar arrastrando, fijar, filtrar escribiendo y manejar la lista con el teclado.
- Reabrir pestaña cerrada (Ctrl+Mayús+T), hasta las últimas 20.
- Abrir enlaces en otra pestaña con clic central o Ctrl+clic.
- Indicador de pestaña con sonido y silenciarla desde la lista.
- **Mini reproductor** sobre la barra de dirección: lo que suena, anterior, reproducir/pausa y siguiente.
- **Página de nueva pestaña** propia: buscador, accesos rápidos, noticias de tecnología y fondo del tema o imagen propia.
- Perfil persistente: cookies, sesiones y caché se conservan entre arranques.
- Compatibilidad con WhatsApp Web y otros sitios que rechazaban la identificación de navegador de Qt WebEngine.
- Atajos: Ctrl+T, Ctrl+W, Ctrl+L, Ctrl+Tab, Ctrl+Mayús+Tab, Ctrl+Mayús+A, Ctrl+R/F5, Alt+←/→.

## [0.1.0] - 2026-10-20

### Añadido

- Primer esqueleto del proyecto: una ventana que muestra páginas web con Qt WebEngine. Sin publicar.

# Cambios en Mitis

Todos los cambios que notará quien usa Mitis, versión a versión.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/); las versiones siguen el esquema de [docs/versiones.md](docs/versiones.md). La línea `> …` bajo una versión es el título de su pestaña de novedades.

## [Sin publicar]

> Tus pestañas esenciales, siempre a mano

### Añadido

- Pestañas esenciales: hasta 4 páginas que usas a diario, siempre a un clic. Para añadir una, pasa el ratón por ella en la lista de pestañas y pulsa el botón de los cuadritos (o, con el panel abierto, «Añadir esta pestaña a esenciales»). Salen de la lista de pestañas y quedan en una pestaña pequeña en el borde izquierdo: al pulsarla aparecen como botones con el icono de cada página. Ve a ellas al instante con Ctrl+1, Ctrl+2, Ctrl+3 y Ctrl+4 (en Mac, Cmd). Para quitar una, pasa el ratón por su botón y pulsa la ✕: vuelve a la lista. No se cierran por accidente, siguen ahí al volver a abrir Mitis y nunca se suspenden.

## [0.16.0] - 2026-10-30

> Ajustes por sitio, atrás al instante y tus búsquedas a mano

### Añadido

- El buscador de la página de nueva pestaña recuerda lo que buscaste: al pulsarlo aparecen tus búsquedas recientes y, mientras escribes, las que coinciden junto con páginas de tus marcadores y tu historial. Se eligen con el ratón o con las flechas y Intro. En la ventana privada solo aparecen al escribir.
- Atrás al instante: al volver con Atrás a la página anterior, aparece al momento, tal como la dejaste (sin volver a cargarse y con lo que hubieras escrito). Mitis la guarda durante 3 minutos. En Configuración → Rendimiento, «Atrás y adelante al instante», puedes guardar solo la anterior (de serie), las 3 anteriores o ninguna. Si al equipo le queda poca memoria, deja de guardarlas. Como hasta ahora, al cerrar Mitis no se guarda nada de esto.
- Ajustes por sitio, en Configuración: cada sitio con lo que Mitis recuerda de él (el zoom, los permisos que decidiste y si le permites los anuncios) en un solo sitio, para revisarlo y quitar lo que quieras. Desde el candado de la barra de búsqueda, «Ajustes del sitio» lleva directo al de la página.
- El zoom ahora se recuerda por sitio: si agrandas una página, el sitio se verá así cada vez que vuelvas, en cualquier pestaña. Ctrl+0 lo devuelve al de siempre. En la ventana privada no se recuerda.
- Puedes hacer más grandes los controles de abajo (atrás, adelante, la barra de búsqueda, pestañas, marcadores y opciones): en Configuración → Apariencia e idioma, «Tamaño de los controles de abajo», elige entre Normal (el de siempre), Grande o Más grande.

### Cambiado

- Los controles de abajo vuelven siempre al pulsar la pestaña del borde inferior. Ya no está la opción de que vuelvan solo con pasar el ratón por ella.

### Corregido

- Después de una descarga, el botón de descargas de abajo se quedaba para siempre. Ahora, como antes, desaparece solo unos segundos después de que terminen todas las descargas.
- En Opciones → Descargas, el botón «Limpiar» no borraba la lista. Ya funciona.

## [0.15.0] - 2026-10-28

> Un reproductor más ligero

### Añadido

- Puedes elegir cómo vuelven los controles de abajo (atrás, adelante, la barra de búsqueda…) cuando se esconden: al pulsar la pestaña del borde inferior o solo con pasar el ratón por ella. En Configuración → Apariencia e idioma, «Mostrar los controles de abajo».

### Cambiado

- La pestaña del reproductor del borde derecho ya no aparece cuando estás en la pestaña que está sonando (ahí ya tienes el reproductor de la propia página) ni con Configuración abierta.
- La pestaña del reproductor se ve mejor: ahora lleva los colores de Mitis (en el tema Nocturno, de violeta a rosa) en lugar del tono oscuro de los controles, que casi no se distinguía.
- El reproductor que se despliega es más ligero y compacto: arriba, una imagen pequeña de lo que suena con el título y el artista; abajo, el tiempo («1:23 / 3:34») y los botones. Ya no tiene barra de progreso.

### Corregido

- En algunos sitios de música, como Apple Music, el reproductor de Mitis funcionaba a ratos: después de pausar no volvía a reproducir, y el tiempo de la canción salía mal (unos pocos segundos). Ahora usa los controles y el tiempo del propio sitio, como las teclas de música del teclado.

## [0.14.0] - 2026-10-26

> El reproductor, arriba y más grande

### Añadido

- Al escribir en la barra de búsqueda, si lo que buscas ya está abierto en otra pestaña, aparece primero en las sugerencias con «Ir a la pestaña»: al elegirlo, Mitis te lleva a esa pestaña en vez de abrir la página otra vez. En la ventana privada solo salen sus propias pestañas.
- En Configuración → Rendimiento ya puedes elegir cuánto espacio del disco usa Mitis para guardar imágenes y archivos de las páginas que visitas (lo que hace que vuelvan a abrirse antes): 100, 250 o 500 MB, o que lo decida Mitis según el espacio libre. Viene en 250 MB. Ahí mismo ves cuánto ocupa ahora y puedes vaciarlo con un botón.
- Mitis cuida la memoria de tu equipo: si le queda poca (por ejemplo, con muchas pestañas abiertas en un portátil), descarga antes las pestañas que llevas más tiempo sin ver, una a una, hasta que se recupera; al volver a una, se carga de nuevo. Las fijadas, la que suena y las que tienen algo a medio escribir no se tocan. Viene activado y se puede apagar en Configuración → Rendimiento, «Liberar memoria cuando el equipo va justo».

### Cambiado

- El reproductor se muda al borde derecho: mientras algo suena en cualquier pestaña, asoma en el lado derecho de la ventana una pestaña pequeña y redonda con el icono del sitio que suena (más tenue si está en pausa). Al pulsarla se despliega un reproductor más grande, con la imagen de lo que suena (la portada del disco o la del vídeo), el título y el artista, una barra de progreso que puedes pulsar o arrastrar para ir a otro momento, y los botones de anterior, reproducir o pausar y siguiente. Pulsa el título para ir a la pestaña que suena.
- El botón de pestañas de abajo muestra ahora un icono de pestañas en lugar del número; cuántas tienes abiertas lo ves al pasar el ratón por encima.
- Los controles de abajo (atrás, adelante, la barra de búsqueda…) ya no aparecen solo con pasar el ratón por la pestaña del borde inferior: ahora hay que pulsarla, así no salen sin querer. Y se esconden antes cuando dejas de usarlos (en un segundo, antes dos).

### Corregido

- Con Configuración abierta, al pasar el ratón por encima podían asomar los avisos de los enlaces de la página que había debajo. Ya no.

## [0.13.0] - 2026-10-25

> Una ventana privada de verdad y DNS cifrado

### Añadido

- Nueva sección «Atajos de teclado» en Configuración: todas las combinaciones de teclas de Mitis, agrupadas en Pestañas, Navegar, Buscar y zoom, y Ventana y herramientas. Se ve un grupo cada vez; pasas de uno a otro con sus botones o con las flechas.
- DNS cifrado (Configuración → Privacidad): al abrir un sitio, Mitis pregunta su dirección de forma cifrada a un servidor que eliges (Cloudflare, Quad9, Mullvad o AdGuard), en lugar de hacerlo a la vista de tu proveedor de internet y de la red a la que estás conectado, por ejemplo una wifi pública. Viene en «Automático» con Cloudflare: si el servidor no responde, usa el de tu red como siempre. Con «Siempre» no vuelve nunca al de tu red, y con «Desactivado» se apaga. Los cambios se aplican al volver a abrir Mitis.

### Cambiado

- La ventana privada estrena aspecto: negro mate de arriba abajo (barra de arriba, botones, listas y nueva pestaña), para que sepas a simple vista que estás en ella.
- En la ventana privada, todas las protecciones están siempre activas, aunque las hayas apagado en Configuración: el bloqueo de anuncios y rastreadores, quitar el rastreo de los enlaces, pedir a los sitios que no te rastreen, bloquear las cookies de otros sitios, ocultar tu dirección de red local y usar conexiones seguras.
- Desde la ventana privada ya no se puede entrar en Configuración, en tu perfil ni en tu historial, ni cambiar el fondo o los accesos rápidos de la nueva pestaña. La nueva pestaña privada te recuerda que todo se borra al cerrarla.
- «Imprimir…» sale del menú de opciones para dejarlo más corto. Sigue a mano con Ctrl+P (Cmd+P en Mac) o con clic derecho sobre la página → «Imprimir…».
- El panel del sitio (el candado del campo de dirección) ya no tiene «Enviar por correo». Para compartir una página, usa «Copiar enlace».

### Corregido

- Si dabas permiso a un sitio para usar la cámara o el micrófono en una ventana privada, Mitis lo recordaba también fuera de ella. Ahora ese permiso se olvida al cerrar la ventana privada.
- «Restablecer la configuración» no refrescaba en pantalla el tema, el bloqueo de anuncios, quitar el rastreo de los enlaces, la suspensión de pestañas ni la precarga de páginas hasta volver a abrir Mitis.

## [0.12.0] - 2026-10-25

> Más ligero y más rápido al navegar

### Añadido

- Nueva opción «Precargar páginas» (Configuración → Rendimiento): cuando dejas el ratón un momento sobre un enlace, Mitis empieza a cargar esa página y, al pulsarlo, se abre mucho antes (en nuestras pruebas con una conexión lenta, en menos de la mitad de tiempo). Gasta algo más de datos y el sitio sabe sobre qué enlaces pasas el ratón, por eso viene apagada y nunca se usa en las ventanas privadas.

### Corregido

- Mitis podía cerrarse de golpe en la ventana de imprimir si cambiabas una opción (por ejemplo, la orientación de la hoja) mientras aún preparaba la vista previa de una página grande. Ya no ocurre.

### Cambiado

- Mitis arranca más rápido y gasta menos memoria: Configuración, las listas de abajo (pestañas, marcadores, historial, descargas…), el menú del clic derecho, la captura de pantalla y la ventana de imprimir ya no se preparan al abrir Mitis, sino cuando los abres, y se liberan al cerrarlos. Cada ventana privada también gasta mucho menos.
- En Mac, al deslizar para ir a la página anterior o a la siguiente, la flecha ya no es un círculo: ahora es un relieve largo y redondeado, con los colores de tu tema, que va saliendo del borde de la ventana mientras deslizas. Dentro aparece poco a poco una flecha gruesa y redondeada; cuando cambia de color, suelta y cambias de página.

## [0.11.0] - 2026-10-24

> Imprimir, corrector y gestos para ir atrás

### Añadido

- En Mac puedes ir a la página anterior o a la siguiente deslizando el dedo, como en Safari: con dos dedos en el panel táctil (o uno en el Magic Mouse) aparece una flecha en el borde; cuando se rellena de color, suelta y cambias de página. Si lo tienes configurado con tres dedos en Ajustes del Sistema, también funciona. Mitis respeta lo que hayas elegido allí («Deslizar entre páginas») y no cambia de página si lo que deslizas es algo de la propia página, como una galería de fotos o un mapa.
- En todos los sistemas, los botones laterales del ratón (los de atrás y adelante que traen muchos ratones) ya sirven para ir a la página anterior y a la siguiente.
- Si prefieres que los gestos y los botones del ratón no cambien de página, puedes apagarlos en Configuración → Contenido, «Atrás y adelante con gestos y botones del ratón».
- Corrector ortográfico en español: al escribir en una página (un correo, un formulario, un comentario), las palabras mal escritas se subrayan en rojo y, con clic derecho sobre una, Mitis te propone cómo escribirla bien. Se puede apagar en Configuración → Apariencia e idioma, «Revisar la ortografía».
- Ya puedes imprimir páginas o guardarlas como PDF (Ctrl+P, o Opciones → «Imprimir…», o clic derecho → «Imprimir…»). Se abre una ventana de Mitis con la vista previa de las hojas, donde eliges la impresora o «Guardar como PDF», el número de copias, color o blanco y negro, hoja vertical u horizontal, el tamaño del papel y si imprimir también los fondos de la página.
- En Windows y Mac, Mitis ya puede reproducir los formatos de vídeo y audio más usados en internet (como el MP4). Antes muchos vídeos no se veían y algunos servicios de música o películas no funcionaban; ahora sí.

## [0.10.1] - 2026-10-24

> Mitis, más estable

### Corregido

- Mitis aún podía cerrarse de golpe tras llevar un rato abierto, sobre todo en Mac. Pasaba al volver a una pestaña que se había dormido para ahorrar memoria (o a otra del mismo sitio). La corrección anterior no cubría ese caso; ahora sí.

## [0.10.0] - 2026-10-24

> Novedades a la vista y un Mitis de cristal

### Añadido

- Cada vez que Mitis se actualice, la primera vez que lo abras verás una pestaña como esta, con lo nuevo de la versión. Solo aparece esa vez; ciérrala con «Entendido».

### Cambiado

- El aspecto de cristal (Configuración → Apariencia, «Transparencia con desenfoque», en pruebas) llega a todo Mitis: además de los botones y la barra de arriba, ahora también los avisos, las ventanas que piden permiso o confirmación, el buscador, los accesos rápidos y las noticias de la nueva pestaña, y las tarjetas de Configuración. Los fondos ganan unos toques de color para que el efecto luzca. Sigue siendo opcional y viene apagado.
- La pestañita que queda abajo cuando los botones se esconden tiene ahora forma de relieve: sale del borde con curvas suaves, sin esquinas ni bordes marcados.
- Los botones, el buscador, el reproductor, los avisos, las listas y las tarjetas ya no tienen borde: se ven más limpios. Al escribir una dirección o buscar dentro de una página sigue apareciendo un contorno de color para que sepas dónde estás escribiendo; el buscador de la nueva pestaña va sin él.
- En Configuración, los ajustes de la derecha se desvanecen más suavemente arriba y abajo al desplazarlos, como si salieran del fondo.

### Corregido

- Si empezabas una descarga mientras otra seguía bajando, la anterior desaparecía del panel de descargas y no había forma de saber cuándo terminaba. Ahora el panel muestra todas a la vez, cada una con su avance; las que terminan se quedan en la lista como «Completada», con sus botones para abrir el archivo o la carpeta, y el círculo del botón de descargas muestra el avance de todas juntas.

## [0.9.1] - 2026-10-23

> Mitis, más estable

### Corregido

- Mitis podía cerrarse de golpe después de llevar un rato abierto, sobre todo en Mac, cuando tenías muchas pestañas abiertas. Ya no ocurre.

## [0.9.0] - 2026-10-23

### Añadido

- **Actualizaciones.** Mitis busca versiones nuevas al abrirse y cada 6 horas. Si hay una, aparece un botón animado después del de Opciones; al pulsarlo, «Actualizar ahora» con «Confirmar» y «Cancelar». Al confirmar, Mitis se cierra, se actualiza y vuelve a abrirse con tus pestañas: en Windows, Mitis descarga el instalador de la versión nueva y lo abre en su ventana; en macOS (si Mitis está en una carpeta donde puedes escribir, como Aplicaciones) y en Linux con el AppImage, descargando antes la versión nueva. También en Configuración → Acerca de Mitis («Buscar ahora»).
- **Informes de cierres inesperados.** Si Mitis se cierra de golpe, al volver a abrirlo avisa y guarda un informe (qué estaba pasando y, si fue una caída, dónde falló) que puedes copiar con un clic para enviarlo. También en Configuración → Desarrollo. Todo queda en tu equipo: no se envía nada.

### Cambiado

- La página de nueva pestaña muestra el logo completo de Mitis sobre el buscador.

### Corregido

- Windows: las notificaciones, el Administrador de tareas y el mezclador de volumen muestran «Mitis» en lugar de «Mitis.exe».
- Monitor de rendimiento en Windows: la memoria es ahora la que de verdad ocupan Mitis y sus procesos en RAM (la columna «Memoria» del Administrador de tareas). Antes contaba también la memoria reservada sin usar y salía mucho mayor que en macOS.

## [0.8.0] - 2026-10-23

### Añadido

- **Captura de pantalla**, como en Zen: Ctrl+Mayús+S o «Hacer captura de pantalla» en el panel del sitio. Al pasar el ratón, Mitis resalta la sección de la página que hay debajo y con un clic la eliges; también puedes arrastrar para marcar un área, o elegir la página visible o la página completa. La selección se ajusta con sus tiradores y, llevando el borde al de la ventana, crece hacia abajo (o hacia arriba) más allá de lo que se ve. Se copia al portapapeles o se guarda en la carpeta de descargas (y aparece en la lista de descargas).
- Transparencia con desenfoque (experimental): el velo pasa a ser morado, con tres tonos a elegir en Configuración → Apariencia (lavanda, violeta o profundo).
- Esquinas redondeadas de la ventana en Windows 11 y macOS, como las del sistema (rectas al maximizar o en pantalla completa).

### Cambiado

- La barra de título se oculta antes (1,5 s después de quitar el ratón) y los controles de abajo también (2 s después de dejar de usarlos).
- macOS: el nombre de Mitis va centrado en la barra de título, como en las ventanas del sistema.
- Configuración: la lista de sitios con anuncios permitidos y la de permisos guardados por sitio quedan plegadas en una fila («Sitios permitidos», «Sitios con permisos guardados») que dice cuántos hay y se despliega al pulsarla.
- macOS: la ventana del `.dmg` muestra el logo completo de Mitis y ya no se corta por abajo (se veía sin el logo de StartCode).

### Corregido

- Restablecer la configuración también vuelve a apagar la transparencia con desenfoque en la interfaz al momento.

## [0.7.0] - 2026-10-23

### Añadido

- Versión para macOS en cada compilación: un `.dmg` universal que funciona en los Mac con Apple Silicon y en los Intel. Al abrirlo, una ventana con el estilo del instalador de Windows indica arrastrar Mitis a Aplicaciones; Mitis tiene su icono en el Dock.
- En macOS, los botones de la ventana son los del sistema: los tres círculos de cerrar, minimizar y zoom, a la izquierda.

### Cambiado

- El monitor de rendimiento dice con qué dibuja Mitis (Metal, Direct3D, OpenGL…) aunque el uso de la GPU solo se mida en Linux; antes ponía «No disponible».
- Transparencia con desenfoque (experimental): ahora en toda la interfaz (barra de título, controles de abajo, listas, tooltips, mini reproductor…), con un velo gris neutro y bastante transparente (claro en el tema Claro). Sigue siendo opcional y viene apagada. La opción indica si Mitis se está dibujando con la tarjeta gráfica (y con cuál: Metal, Direct3D, OpenGL…) y, si no, no se puede activar. Corregido: en macOS decía que no había tarjeta gráfica.

### Corregido

- Configuración: la rueda del ratón sobre el índice de secciones ya no desplaza también los ajustes; cada columna se desplaza por su cuenta.
- Al descargar un archivo desde un enlace que se abre en otra pestaña, ya no queda una pestaña vacía: se cierra sola y vuelves a la página en la que estabas.

## [0.6.0] - 2026-10-22

### Corregido

- Las notificaciones de las páginas (WhatsApp Web, Gmail, chats…) no se mostraban. Ahora son notificaciones del sistema: en Windows, en Linux (cualquier escritorio) y en macOS. Al pulsarla, Mitis vuelve a la pestaña del sitio.
- Al cambiar el tamaño de la ventana, el campo de dirección ya no se queda atrás buscando su nuevo ancho.

### Cambiado

- Los controles de abajo se ocultan solos a los pocos segundos de dejar de usarlos, para no tapar lo que las páginas tienen abajo (avisos de cookies, reproductores…). Queda una pestaña pequeña con el título de la página: al pasar el ratón por ella, vuelven.
- La barra de título se oculta sola para dejar más espacio a la página: aparece al llevar el ratón al borde superior de la ventana y se queda unos segundos.
- La ventana se abre la primera vez con el 75 % del tamaño de la pantalla, centrada, y desde entonces recuerda cómo la dejaste: maximizada, o con su tamaño y posición. Si esa posición ya no está en ninguna pantalla, vuelve a lo de serie.
- Nuevo mini reproductor: negro, con botones que son solo el icono (relleno y redondeado); al pasar el ratón, el icono toma el degradado de Mitis y crece un poco. Ya no aparece si estás en la pestaña que está sonando, y las llamadas y reuniones (Meet, Zoom, Teams…) no lo usan: es solo para música, vídeos y plataformas de streaming.
- En la página de nueva pestaña, los controles de abajo (con el campo de búsqueda) ya no se ocultan.
- El instalador sabe si Mitis ya está instalado: entonces ofrece desinstalarlo (tu historial, marcadores y ajustes se conservan) o reinstalarlo/actualizarlo.
- Configuración: el índice de secciones ya no se corta. Ocupa como mucho el 40 % del alto, se desplaza solo para mostrar la sección en la que estás, y tanto el índice como los ajustes se desvanecen suavemente en los bordes al desplazarse.
- Toda la interfaz usa los tonos del fondo de Configuración: la barra de título (sin el rosa), los controles de abajo, los botones, el buscador de la nueva pestaña, los menús y los tooltips.
- El contador de pestañas es más pequeño, más grueso y está mejor centrado; lo que escribes en los buscadores se ve algo más grueso; el nombre de la barra de título y el icono de Configuración son algo más pequeños.

### Añadido

- Icono y logo de Mitis: la gota con sus ondas, en los colores de Mitis. En el ejecutable, la ventana y el instalador; el nombre, en la barra de título, y el logo completo, siempre visible al pie del índice de Configuración (versión clara u oscura según el tema). «Beta» en la barra de título mientras sea una versión de prueba.
- **Aviso de micrófono y cámara en el icono de Mitis** (barra de tareas en Windows y Linux, Dock en macOS): mientras una página usa el micrófono o la cámara, el icono lleva una marca roja que parpadea; si los silencias sin cerrarlos, la marca se queda fija, y al colgar desaparece. En la lista de pestañas, la que los usa lleva el mismo icono.
- **Monitor de rendimiento** (Configuración → Desarrollo, independiente de las herramientas de desarrollo): panel con el uso de CPU y de memoria de Mitis, con gráfica de los últimos 2 minutos, por tipo de proceso y por pestaña, y el de la gráfica donde el sistema lo permite (por ahora, Linux). Se oculta mientras Configuración está abierta. Shift+Esc lo muestra u oculta.
- Configuración → Apariencia: «Ocultar la barra de desplazamiento» de las páginas; se sigue pudiendo desplazar con la rueda, el teclado o el dedo.
- «by StartCode» al final de Configuración.
- **Perfil:** Opciones → Perfil (o tu avatar en la barra de título) abre Configuración → Perfil, donde pones tu nombre y una foto o un color. Tu avatar aparece en la barra de título y en el menú de opciones. Se guarda solo en tu equipo.
- **Panel del sitio**, como en Zen: el candado del campo de dirección abre un panel con lo importante de la página. Muestra si la conexión es segura y, al pulsarla, el certificado: quién lo verificó, para quién es y hasta cuándo vale. También si la protección contra rastreadores está activa en ese sitio, con un interruptor para quitarla solo ahí. Y acciones: añadir a marcadores, copiar el enlace, enviarlo por correo y los permisos del sitio.
- **Transparencia con desenfoque (experimental)**, en Configuración → Apariencia, apagada por defecto: el campo de dirección deja ver la página de detrás, difuminada, como el reproductor de Apple Music en la web. Necesita aceleración gráfica.

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

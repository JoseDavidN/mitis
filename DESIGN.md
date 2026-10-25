# Sistema de diseño — Mitis

Fuente de verdad del aspecto de Mitis. Toda pantalla, componente o cambio visual **debe** seguir estas reglas.

El tema por defecto, **Nocturno**, sale del tema oscuro de StartCode Panel (`/srv/proyectos/startcode_panel/FRONTEND/src/styles/themes/dark.css`): violeta y rosa sobre un negro con matiz morado. Mitis usa los mismos valores, adaptados a QML.

### Temas

Se eligen en Configuración → Apariencia e idioma (`Settings.theme`) y cambian al momento: cada token de color de `Theme` es un enlace a la paleta del tema en uso (`Theme.palettes`). Las tres paletas tienen las mismas claves. Las tablas de tokens de abajo dan los valores de Nocturno.

| Tema | Clave | Carácter | Fondo · tinta · acento |
|---|---|---|---|
| Nocturno (de serie) | `nocturno` | Violeta y rosa sobre negro morado | `#07050d` · `#f4f1ff` · `#a855f7 → #ec4899` |
| Oscuro | `oscuro` | Grises neutros y azul, como el modo oscuro de Chrome; barra de título y controles planos, sin degradado de color | `#202124` · `#e8eaed` · `#1a73e8` (marca), `#8ab4f8` (acento claro) |
| Claro | `claro` | Fondos claros con la marca violeta/rosa; bordes y tintes en negro con alfa | `#f7f5fb` · `#1d1631` · `#9333ea → #db2777`, acento `#7c3aed` |

- `Theme.dark` dice si el tema es oscuro. Con él se fija `Application.styleHints.colorScheme` (diálogos del sistema). Las páginas web con versión oscura (`prefers-color-scheme`) siguen al tema desde el próximo arranque: lo fija `main.cpp` con `--blink-settings=preferredColorScheme` (Qt WebEngine no deja cambiarlo en marcha ni hace caso de `colorScheme`).
- Un tema nuevo: otra entrada en `Theme.themes` y en `Theme.palettes`, con todas las claves. Nada más cambia.
- La paleta de DevTools, las medidas, la tipografía y el movimiento son iguales en todos los temas.

---

## Principios

- **Oscuro y morado de serie.** Nocturno: fondo casi negro (`#07050d`) con resplandor violeta; la marca es el degradado violeta → rosa (`#a855f7 → #ec4899`). Además hay un tema Oscuro neutro y uno Claro.
- **El color nunca se escribe en un componente.** Todo sale de `qml/Theme.qml`. Un `"#hex"` o un `Qt.rgba(...)` fuera de `Theme.qml` es un error.
- **La interfaz flota sobre la página.** Arriba, una barra de título fina que se oculta sola (aparece al llevar el ratón al borde superior); abajo, controles sueltos (botones y campo de dirección) sin barra de fondo. Cada control lleva su propia superficie y borde, sin sombra.
- **Ligero.** Nada de desenfoque (`blur`) ni efectos que obliguen a re-renderizar la página: Mitis prioriza RAM y GPU. Las superficies imitan el "glass" con alfa alto en lugar de borronear lo de detrás. (La única excepción es el vidrio experimental, opcional y apagado por defecto: ver `Glass`.)
- **Un tema = un juego de tokens.** Los componentes no saben qué tema está activo; solo leen `Theme`.

---

## Tokens (`qml/Theme.qml`)

### Fondo

| Token | Valor | Uso |
|---|---|---|
| `bgBase` | `#07050d` | Fondo de la ventana |
| `bgMid` | `#150a2e` | Transición de fondos con degradado (reservado) |
| `bgGlow` | `#2a1352` | Resplandor violeta de fondos (reservado) |
| `titleBarStart` → `titleBarEnd` | `#2a1352 → #150a2e` | Barra de título: los tonos del fondo de Configuración (`bgGlow → bgMid`), de izquierda a derecha. Barra, controles, botones sueltos y listas comparten estos tonos |
| `controlsStart` → `controlsEnd` | `#2a1352 → #150a2e` al 94 % | Controles inferiores (y búsqueda en la página, zoom, aviso de pantalla completa, pestaña del borde): los tonos del fondo de Configuración (`bgGlow → bgMid`), con un 6 % de transparencia, compartidos por todos los controles. En Oscuro `#2d2e31 → #202124`; en Claro `#e4d7fc → #f1ebfd` |

Los fondos de la interfaz usan siempre **tonos oscuros** de la marca. El degradado vivo `brand1 → brand2` se reserva para detalles pequeños (logo, progreso, marcas), nunca para superficies grandes.

### Superficies

| Token | Valor | Uso |
|---|---|---|
| `surfaceFloat` | `rgba(8,3,20,0.88)` | Todo lo que flota sobre la página: botones, campo de dirección, listas desplegables. Equivale a `glass-float` de StartCode, sin blur |
| `surfacePopup` | `#150a2e` opaco (`bgMid`) | Listas desplegables y tooltips. Opacas: sin blur, hasta un 3 % de transparencia deja ver el texto de la página de detrás |
| `selectBg` | `#2a1352` (`bgGlow`) | Fondo de selects y listas opacas (reservado): un escalón más claro que `surfacePopup` |

### Bordes y separadores

| Token | Valor | Uso |
|---|---|---|
| `hairline` | `white 13 %` | Borde normal de una superficie |
| `hairlineSoft` | `white 12 %` | Borde de superficies anidadas y separador de la barra de título |
| `hairlineStrong` | `white 20 %` | Borde acentuado: listas desplegables |
| `hairlineHover` | `white 18 %` | Borde al pasar por encima |
| `line` | `white 7 %` | Separadores dentro de una lista (se repite N veces: más suave) |

### Tintes de realce

| Token | Valor | Uso |
|---|---|---|
| `tintHover` | `white 6 %` | Realce al pasar por encima (botones, filas) |
| `tintActive` | `white 10 %` | Pulsado y elemento seleccionado (pestaña activa) |
| `tintSunken` | `white 4 %` | Fondos rehundidos (reservado) |

### Sombras

**Mitis no usa sombras ni bordes en sus superficies.** Controles, botones, campos, listas, tooltips, avisos y tarjetas se separan de la página solo por su relleno (`Surface`, sin borde); el hover se marca con tinte y escala, no con borde ni halo. El único borde de un control es el anillo de foco (`focusRing`) del campo de dirección y de buscar en la página mientras se escribe (el buscador de la nueva pestaña no lo lleva). Los `hairline*` quedan para separadores y detalles pequeños (casillas, interruptores, chips).

### Tinta (texto e iconos)

| Token | Valor | Uso |
|---|---|---|
| `ink` | `#f4f1ff` | Texto principal, icono al pasar por encima |
| `inkStrong` | `white 85 %` | Texto del campo de dirección sin foco |
| `inkSoft` | `white 75 %` | Iconos en reposo, nombre "Mitis" en la barra de título |
| `inkSecondary` | `white 65 %` | Texto secundario: pestañas no activas |
| `inkMuted` | `white 45 %` | Placeholder, opciones no disponibles |
| `inkFaint` | `white 35 %` | Atajos y "Próximamente" |
| `inkDisabled` | `white 30 %` | Iconos de botones desactivados |

### Marca

| Token | Valor | Uso |
|---|---|---|
| `brand1` → `brand2` | `#a855f7 → #ec4899` | Degradado de marca: logo, barra de progreso, marca de pestaña activa |
| `brandLight1`, `brandLight2` | `#c084fc`, `#f472b6` | Variante clara (texto con degradado, sliders) |
| `onBrand` | `#ffffff` | Tinta sobre superficies de marca o de peligro: icono de cerrar en hover |
| `focusRing` | `#c084fc` | Borde de foco (campo de dirección) |
| `selection` | `violeta 35 %` | Selección de texto |

### Semánticos

| Token | Valor | Uso |
|---|---|---|
| `ok` | `#34d399` | Correcto, en línea |
| `warn` | `#fbbf24` | Atención |
| `danger` | `#fb7185` | Errores, avisos |
| `dangerStrong` | `#f43f5e` | Fondo del botón cerrar al pasar por encima |

Los semánticos conservan su significado en todos los temas; no usarlos como acento.

### Tipografía

- **Fuente:** [Nunito](https://github.com/googlefonts/nunito) (SIL OFL, `assets/fonts/OFL.txt`): sans redondeada, moderna y legible en tamaños pequeños. Un solo archivo variable (`assets/fonts/Nunito.ttf`) con todos los pesos.
- Se registra en `src/main.cpp` y queda como fuente por defecto de la aplicación: todo `Text` y `TextField` la usa sin indicarlo. No escribir `font.family` en los componentes.
- Solo afecta a la interfaz: las páginas web usan sus propias fuentes.
- Tamaños desde `Theme`: `fontSizeHeading` (24) título de una página propia (Configuración), `fontSizeLarge` (16) buscador de la nueva pestaña y títulos de sección, `fontSizeTitle` (14) nombre de la app y títulos de diálogo, `fontSize` (13) texto general, `fontSizeSmall` (12) atajos y notas. Pesos: regular para texto, `fontWeightInput` (Medium) para lo que se escribe en los buscadores (dirección y nueva pestaña), `Font.DemiBold` para el nombre de la app, títulos de diálogo y de cada ajuste, `Font.Bold` para el título de una página y de sus secciones y para lo elegido en una lista.

### Medidas, tipografía y movimiento

Medidas, tamaños de letra y duraciones también viven en `Theme`. El movimiento es **igual en todos los temas**:

| Token | Valor | Uso |
|---|---|---|
| `durationFast` | 140 ms | Hover y cambios de estado |
| `durationBase` | 200 ms | Entrada de listas desplegables, progreso |
| `durationSlow` | 260 ms | Entradas de vista y paneles grandes |
| `easeOut` | `cubic-bezier(0.22,1,0.36,1)` | Entradas |
| `easeInOut` | `cubic-bezier(0.4,0,0.2,1)` | Hover y estado |
| `dragScrollInterval` | 16 ms | Paso del auto-scroll al arrastrar una fila cerca del borde |

En QML: `easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut`.

Alturas: botones inferiores `buttonSize` (32), campo de dirección `controlHeight` (34), barra de título `titleBarHeight` (30) con botones de `titleButtonSize` (24).

Pestaña suspendida: `suspendedOpacity` (0,45) opacidad de su favicon en la lista.
Arrastre de filas: `dragOpacity` (0,85) opacidad de la fila levantada, `dropIndicatorHeight` (2) grosor de la línea de destino, `dragScrollStep` (6 px por paso) velocidad del auto-scroll.

Descargas: `downloadRowHeight` (52) fila de dos líneas del listado, `durationIndeterminate` (1,2 s) vuelta de la barra de progreso sin total conocido, `relativeTimeRefresh` (30 s) refresco de «hace 5 min» en el listado.

Descarga actual: `downloadPanelWidth` (340) ancho del panel, `downloadBarHeight` (4) grosor de su barra, `progressRingWidth` (2) trazo del anillo del botón, `progressIndeterminateSpan` (0,3) fracción que ocupan el tramo de la barra y el arco del anillo sin total conocido, `durationSpin` (1 s) vuelta del anillo sin total, `downloadPanelHold` (10 s) lo que se quedan panel y botón al terminar.
Monitor de rendimiento: `memoryPanelWidth` (360) ancho, `memoryPanelRefresh` (2 s) cada cuánto vuelve a medir, `performanceChartHeight` (36) alto de cada gráfica, `performanceHistoryLength` (60 medidas, 2 min) lo que muestran, `performanceChartLineWidth` (1,5) trazo, `performanceChartFillOpacity` (0,16) relleno bajo la línea; colores `performanceCpu` (= `brandLight1`) y `performanceMemory` (= `ok`).

Filas de página (marcadores, historial): `pageRowHeight` (48). `CheckMark`: `checkRadius` (5); «Datos borrados» se queda `clearedNoticeHold` (3 s).

Configuración: `settingsMaxWidth` (680) ancho máximo de la columna, `settingsNavWidth` (220) índice de secciones, `settingsNavBreakpoint` (900) ancho por debajo del cual el índice se oculta, `settingsHeaderHeight` (64) cabecera, `settingsSectionSpacing` (32) entre secciones, `settingsRowHeight` (60) alto mínimo de una fila, `settingsIconBox` (36) círculo de los favicons, `settingsHeaderIconBox` (30) círculo del icono de la cabecera, con el icono de `settingsHeaderIconSize` (15). `Toggle`: `toggleWidth` × `toggleHeight` (38 × 22) y `toggleKnobInset` (3). `RadioMark`: `radioSize` (18) y `radioDotSize` (8).

Aviso de certificado: `certificateDialogWidth` (440) ancho de la tarjeta, algo más que `dialogWidth` (360) porque explica más.

Herramientas de desarrollo: `devtoolsTitleBarHeight` (44) barra de la ventana, `devtoolsRadius` (16) esquinas de la ventana, `devtoolsButtonSize` (28) botones y etiqueta, `devtoolsInset` (6) separación entre el borde y el panel, `devtoolsWidth` × `devtoolsHeight` (1000 × 680) tamaño inicial. Sus colores, en *Herramientas de desarrollo* (Componentes).

Pantalla completa: `fullscreenRevealEdge` (4) franja del borde inferior que muestra los controles en F11, `fullscreenHintHold` (3 s) lo que se queda el aviso «Pulsa Esc/F11 para salir».

Radios: `radius` (12) para listas y paneles, `radiusSmall` (8) para filas dentro de ellos. Botones y campo de dirección son totalmente redondos (`height / 2`).

---

## Layout

```
Window (bgBase, sin marco)
├── TitleBar      30 px · degradado oscuro titleBarStart → titleBarEnd · separador hairlineSoft
│                 logo (degradado de marca) + "Mitis" (inkSoft) · minimizar / maximizar / cerrar
├── páginas       WebEngineView, de la barra de título hasta el borde inferior
└── BottomBar     controles sueltos flotando sobre la página, sin fondo
                  un solo grupo centrado: [← → ⟳] · campo de dirección · [(descargas), pestañas, marcadores, opciones]
                  los botones van pegados al campo y se mueven con él al crecer o encogerse
                  un solo degradado controlsStart → controlsEnd repartido entre todos
```

---

## Componentes

### Iconos

- **Set:** [Lucide](https://lucide.dev) (licencia ISC, `assets/icons/LICENSE`): trazo de 2 px sobre 24, extremos y uniones redondeados, sin relleno.
- **Archivos:** `assets/icons/<nombre>.svg`, nombrados por su **uso en Mitis**, no por el de Lucide (`back`, no `arrow-left`), para poder cambiar un dibujo sin tocar el código. El SVG debe usar `stroke="currentColor"`.
- **Componente:** `Icon { name; color; size }`. Lo dibuja `IconProvider` (C++), que sustituye `currentColor` por el color pedido y pinta al tamaño exacto de la pantalla: nítido al 100 % y al 200 %, sin efectos de GPU.
- **Tamaños:** `iconSize` (16) en botones y listas; `iconSizeSmall` (14) en la barra de título, el campo de dirección y los botones pequeños.
- **Color:** siempre un `ink*` (o `brandLight1` en el icono de búsqueda con foco, `onBrand` sobre peligro). Nunca un color fijo.
- **Añadir un icono:** copiar el SVG de Lucide con el nombre de uso a `assets/icons/` y volver a ejecutar CMake (el `GLOB` lo empaqueta). En `--dev` se lee directamente de la carpeta.

| Nombre | Lucide | Dónde |
|---|---|---|
| `back`, `forward`, `reload` | `arrow-left`, `arrow-right`, `rotate-cw` | Navegación |
| `close` | `x` | Cerrar ventana o pestaña, detener la carga |
| `minimize`, `maximize`, `restore` | `minus`, `square`, `copy` | Controles de ventana |
| `search` | `search` | Campo de dirección al escribir; sección «Búsqueda» de Configuración (también en lugar del favicon de un buscador que no carga) |
| `screenshot` | `scan` | Captura de pantalla (panel del sitio y su barra) |
| `site-secure`, `site-insecure`, `share-mail`, `expand` | `lock`, `lock-open`, `mail`, `chevron-down` | Panel del sitio: conexión segura / no segura (también en el campo de dirección), enviar por correo y desplegar el certificado |
| `bookmarks`, `bookmark-add`, `bookmark` | `star`, `bookmark-plus`, `bookmark` | Botón y lista de marcadores (`bookmark`, también en las sugerencias de la barra de dirección) |
| `options` | `ellipsis` | Botón de opciones |
| `new-tab`, `reopen` | `plus`, `undo-2` | Lista de pestañas: nueva y reabrir cerrada (`reopen`, también en Historial y en «Al iniciar» de Configuración) |
| `history`, `downloads`, `profile`, `settings` | `history`, `download`, `circle-user-round`, `settings` | Menú de opciones (`settings`, también en la cabecera de Configuración; `downloads` e `history`, en sus secciones; `history`, en las sugerencias del historial) |
| `info` | `info` | Configuración: «Acerca de Mitis» |
| `blocker` | `shield-ban` | Configuración: sección «Anuncios y rastreadores» y sitios donde se permiten |
| `appearance`, `privacy`, `security`, `permissions` | `palette`, `eye-off`, `shield-check`, `sliders-horizontal` | Configuración: secciones Apariencia e idioma, Privacidad, Seguridad y Permisos de sitios (Contenido usa `open-image`) |
| `private` | `venetian-mask` | Ventana privada: menú de opciones y «Privada» en la barra de título |
| `check` | `check` | `CheckMark` marcada y «Datos borrados» |
| `background`, `background-reset`, `news` | `image`, `image-off`, `newspaper` | Página de nueva pestaña |
| `music`, `play`, `pause` | `music`, `play`, `pause` | Descargas (`play`, `pause`); `music` en el mini reproductor |
| `media-play`, `media-pause`, `media-previous`, `media-next` | `play`, `pause`, `skip-back`, `skip-forward`, rellenos (trazo 3) | Botones del mini reproductor |
| `sound`, `muted` | `volume-2`, `volume-x` | Pestaña que suena / silenciada |
| `find-previous`, `find-next` | `chevron-up`, `chevron-down` | Buscar en la página |
| `zoom-out`, `zoom-in` | `minus`, `plus` | Indicador de zoom |
| `pin`, `unpin` | `pin`, `pin-off` | Lista de pestañas: fijar / desfijar |
| `download-done`, `download-failed`, `download-cancel` | `circle-check`, `circle-alert`, `circle-x` | Panel de la descarga actual: terminada, fallida, cancelada (y botón cancelar) |
| `file`, `open-file`, `folder` | `file-down`, `external-link`, `folder-open` | Listado de descargas: archivo, abrirlo, mostrar en la carpeta |
| `open-link`, `open-image`, `copy-link`, `copy`, `save` | `external-link`, `image`, `link`, `copy`, `download` | Menú contextual: abrir enlace e imagen, copiar dirección, copiar, guardar (enlace, imagen, archivo, página) |
| `undo`, `redo`, `cut`, `paste`, `select-all` | `undo`, `redo`, `scissors`, `clipboard-paste`, `text-select` | Menú contextual de un campo editable |
| `not-secure` | `shield-alert` | Aviso de certificado inválido |
| `camera`, `microphone`, `camera-microphone`, `screen`, `location`, `notifications`, `clipboard`, `fonts` | `camera`, `mic`, `video`, `monitor`, `map-pin`, `bell`, `clipboard`, `type` | Diálogo de permisos: qué pide el sitio |
| `protected-content` | `monitor-play` | Aviso de que falta Widevine (contenido protegido) |
| `suspended` | `moon` | Lista de pestañas: pestaña suspendida |
| `memory`, `performance` | `memory-stick`, `gauge` | Monitor de rendimiento (y su entrada del menú de opciones); sección «Rendimiento» de Configuración |
| `devtools`, `inspect` | `code-xml`, `scan-search` | Ventana de herramientas de desarrollo (etiqueta «DevTools») y sección «Desarrollo» de Configuración; «Inspeccionar» del menú contextual |

### `IconButton` — botón flotante
- Relleno por defecto: el degradado `controlsStart → controlsEnd` (los tonos de Configuración), también en los botones sueltos (cerrar Configuración, fondo de la nueva pestaña…). La barra inferior le pasa a cada uno su tramo del degradado compartido.
- `icon` (nombre de `assets/icons/`, tamaño `iconSize`) o, si no, `glyph` (texto corto: el contador de pestañas) en `fontSizeIcon` (12) y `fontWeightIcon` (ExtraBold, redondeado en Nunito), centrado por la forma de los caracteres (`TextMetrics.tightBoundingRect`), no por su caja.
- Círculo de `buttonSize`, relleno degradado `fillStart → fillEnd` (por defecto `surfaceFloat` plano), sin borde.
- Hover: tinte `tintHover`, escala `hoverScale`, icono `ink`.
- Pulsado: tinte `tintActive`, escala `pressScale`.
- `danger: true` (cerrar): al pasar por encima el fondo pasa a `dangerStrong` y el icono a `onBrand`.
- `flat: true`: solo el icono en reposo; al pasar por encima aparece el círculo con `tintActive` (o `dangerStrong` si es `danger`). Se usa en la barra de título y dentro de las listas.
- Desactivado: icono `inkDisabled`.

### `Tooltip` — qué hace un control
- Fondo `surfacePopup`, sin borde, radio `radiusSmall`, relleno `tooltipPaddingX` × `tooltipPaddingY`, texto `fontSizeSmall`.
- Dos partes: la acción en `ink` y, si tiene, el atajo en `inkMuted` (`Atrás  Alt+←`).
- Siempre en una sola línea. Aparece tras `tooltipDelay` (1 s), con fundido `durationFast`; se oculta al pulsar. Encima del control; debajo en la barra de título (`below`). Nunca se sale de la ventana.
- **Todo botón de solo icono lleva tooltip.** En `IconButton`: `tooltip`, `shortcut` y `tooltipBelow`. El texto es un verbo o sustantivo corto en español; el atajo, el mismo que define `Main.qml`.

### `FindBar` — buscar en la página
- Píldora flotante de `findBarWidth` × `controlHeight`, **centrada bajo la barra de título** (a `floatingMargin`), con el degradado `controlsStart → controlsEnd` de los controles, sin borde (anillo `focusRing` con el foco en el campo).
- Contenido: icono de búsqueda (`brandLight1` con foco), campo sin fondo, contador en `inkMuted` ("2 de 7") o "Sin coincidencias" en `danger`, y tres `IconButton` planos: anterior, siguiente, cerrar. Sus tooltips salen hacia abajo.
- Aparece con fundido (`durationBase`) y un pequeño desplazamiento desde arriba.
- Busca mientras se escribe. Intro: siguiente; Mayús+Intro: anterior; Esc: cerrar (el teclado vuelve a la página y se quita el resaltado).
- Atajos globales: Ctrl+F abre (con el texto anterior seleccionado); F3/Ctrl+G siguiente; Mayús+F3/Ctrl+Mayús+G anterior. No se abre en la página de nueva pestaña. Se cierra al cambiar de pestaña.

### Etiqueta «Beta» (barra de título)
- Mientras la versión sea beta (`MITIS_VERSION_SUFFIX`), junto a «Mitis»: píldora de `logoSize` de alto, `tintActive`, borde `hairlineStrong` y «Beta» Bold `fontSizeSmall` `inkSecondary`. La ventana se titula «… Mitis Beta» y el instalador muestra «Mitis Beta».

### Icono y logo de Mitis
- `assets/branding/dmg-fondo.svg`: fondo de la ventana del `.dmg` de macOS (660 × 480, de los que la ventana enseña los 430 de arriba; a 1× y 2×): negro Nocturno con el resplandor `bgGlow` arriba a la izquierda, el logo completo de Mitis (icono y nombre), «Arrastra Mitis a la carpeta Aplicaciones para instalarlo», flecha con el degradado de marca entre Mitis.app (165, 225) y Aplicaciones (495, 225), y «by» + StartCode abajo, como el instalador de Windows.
- `assets/branding/mitis-icon.svg`: cuadrado redondeado con el degradado de la barra de título de Nocturno (`#2a1352 → #4a1438`, en diagonal), una gota con el degradado de la marca (`brand1 → brand2`, de arriba abajo) y tres ondas en la tinta de Nocturno (`#f4f1ff`, al 100, 60 y 30 %). De él salen, con `rsvg-convert`, `mitis.png` (256: ventana, barra de título, instalador y aviso de micrófono/cámara), `mitis.ico` (16–256, PNG dentro: ejecutable e instalador de Windows), `packaging/linux/mitis.svg` (copia) y `mitis.icns` (macOS, 16–1024 px; generado con `iconutil` en un Mac: la forma ocupa 824 de 1024 px, como la rejilla de iconos de macOS, con margen transparente).
- Logo completo (icono + «mitis»): `mitis-logo-dark.svg` para fondos oscuros (texto en la tinta de Nocturno, puntos de las «i» en `brandLight2` `#f472b6`, borde del icono blanco al 13 %) y `mitis-logo-light.svg` para fondos claros (texto en la tinta del Claro `#1d1631`, puntos en su `brand2` `#db2777`). De ellos, `mitis-logo-dark.png` y `mitis-logo-light.png` (600 px de ancho) para Configuración. Solo el nombre, sin icono: `mitis-wordmark-dark.svg` / `-light.svg` (el grupo del texto de los logos) → `.png` (88 px de alto), para la barra de título.

### `Avatar` — perfil
- Círculo con la foto del perfil recortada al centro (sin deformar) o, sin foto, la inicial del nombre en Bold `onBrand` (45 % del tamaño) sobre su color (`Theme.avatarColors`: violeta, rosa, azul, verde, naranja, gris; iguales en todos los temas). Sin nombre ni foto, el icono `profile` en `onBrand`.
- Tamaños: `logoSize` (18) en la barra de título y el menú de opciones; `avatarSizeLarge` (64) en Configuración → Perfil.
- Barra de título: a la derecha, delante de los controles de ventana (hueco de `titleButtonSize`); al pasar, escala `hoverScale` y tooltip «Nombre · Perfil». No en las ventanas privadas.
- Menú de opciones: «Perfil» es la primera opción, con el avatar en lugar del icono y el nombre como texto.
- Configuración → Perfil (primera sección): avatar grande con el campo «Nombre» (`FormField`, se guarda al terminar de escribir), fila «Foto» («Elegir foto…», «Quitar») y fila «Color» (círculos de `buttonSizeSmall` con anillo de `buttonSize`: `focusRing` el elegido, `hairlineHover` al pasar; tooltip con el nombre del color).

### `MemoryPanel` — monitor de rendimiento
- Con la opción «Monitor de rendimiento» (Configuración → Desarrollo; independiente de las herramientas de desarrollo): activarla lo muestra, y Shift+Esc u Opciones → «Monitor de rendimiento» lo muestran u ocultan. Flota **arriba a la izquierda**, bajo la barra de título (a `floatingMargin` de ella y `margin` del borde), ancho `memoryPanelWidth`, fondo `PopupBackground`. Aparece con fundido y desplazamiento (`durationBase`). No se cierra al usar la página: con su ✕ o el mismo atajo. Se oculta mientras Configuración está abierta y vuelve al salir. Solo mide mientras se ve (cada `memoryPanelRefresh`); al ocultarse, olvida lo medido.
- Cabecera de `popupRowHeight`: icono `memory` en `brandLight1`, «Rendimiento» Bold `ink`, ✕ plana. Debajo, el número de procesos en `fontSizeSmall` `inkMuted`.
- Dos gráficas lado a lado, CPU y Memoria: nombre en `fontSizeSmall` `inkSecondary`, cifra total Bold `ink` («…» hasta la segunda medición en la CPU) y, debajo, una línea de `performanceChartHeight` con las últimas `performanceHistoryLength` medidas (la más reciente a la derecha), trazo `performanceChartLineWidth`, relleno del mismo color a `performanceChartFillOpacity` y base `line`. Colores: `performanceCpu` (CPU) y `performanceMemory` (memoria). Escala: la CPU, hasta el máximo reciente con margen (mínimo 10 %, máximo 100 %); la memoria, hasta su máximo reciente con margen.
- Reparto por tipo (proceso principal, páginas de esta ventana, proceso de la GPU, otros) y filas de la GPU en `fontSizeSmall` `inkSecondary`, la cifra DemiBold a la derecha. GPU: «GPU de Mitis» (uso y memoria) y, si el sistema lo publica, «GPU del sistema» (uso y «usada de total»); sin datos, una sola fila «GPU · No disponible». Separador `line`.
- «Pestañas de esta ventana»: un `PageRow` por pestaña sin ✕ (`removable: false`), con la CPU y la memoria de su proceso a la derecha (`value`, DemiBold `inkSecondary`; «—» si no tiene) y el estado de detalle: Activa, Congelada, Descargada o Sin cargar, y «proceso compartido con N» si lo comparte. Pulsar una fila va a la pestaña.
- Cifras: «123 MB», o «1,2 GB» desde 1024 MB; «3 % · 120 MB» (CPU y memoria); porcentajes con un decimal por debajo de 10 («0,4 %»). La CPU es del equipo entero (100 % = todos los núcleos).

### `ZoomIndicator` — zoom de la pestaña
- Píldora de `controlHeight` **arriba a la derecha**, bajo la barra de título (a `floatingMargin` de ella y `margin` del borde), con el degradado de los controles, sin borde.
- Contenido: `IconButton` plano "−", el porcentaje (`ink`, DemiBold, ancho fijo `zoomLabelWidth` para que no baile), "+" y, si no está al 100 %, un separador `line` y "Restablecer" (`inkSecondary`, `ink` al pasar por encima).
- Aparece (fundido y desplazamiento, `durationBase`) con cada cambio de zoom de la pestaña activa; se queda `zoomIndicatorHold` (2 s) desde el último cambio y se cierra solo. Con el ratón encima no se cierra; al salir vuelve a contar. Cambiar de pestaña no lo muestra.
- Pasos de Chrome: 25, 33, 50, 67, 75, 80, 90, 100, 110, 125, 150, 175, 200, 250, 300, 400, 500 %. Atajos: Ctrl + `+` / `=` / `+` numérico, Ctrl + `-`, Ctrl + `0`. El zoom es de la pestaña y se mantiene al navegar dentro de ella.

### `SwipeIndicator` — deslizar entre páginas (macOS)
- Círculo de `swipeIndicatorSize` con la flecha `back` o `forward` (`iconSize`, `ink`), a media altura de la ventana, con el degradado de los controles, sin borde (`Surface`).
- Entra desde fuera del borde del lado hacia el que se va (izquierdo: atrás; derecho: adelante) al ritmo del gesto, con fundido, hasta quedar a `margin` del borde. Cuando soltar ya navega, se rellena con el degradado de la marca (`brand1` → `brand2`, flecha `onBrand`; con el vidrio, la flecha en `brandLight1`) y crece a `swipeIndicatorReadyScale` (`durationFast`). Al soltar desaparece.
- Solo aparece si se puede ir hacia ese lado y el gesto no es de la página (ver `NavigationGestures` en CLAUDE.md); nunca con Configuración ni en pantalla completa.

### `PrintDialog` — imprimir y guardar como PDF
- Sobre la página de su pestaña, como `PageDialog`: velo `backgroundScrim` y tarjeta `PopupBackground` de como mucho `printDialogWidth` × `printDialogHeight` (con `margin` a los bordes de la ventana), con su escala y fundido al abrir.
- Izquierda: vista previa en un fondo `tintHover` (`radius`), las hojas una bajo otra (separadas por `margin`) en blanco papel (`printPaper`, igual en todos los temas); mientras se prepara, a media opacidad y, la primera vez, «Preparando la vista previa…» en `inkSecondary`.
- Derecha, columna de `printOptionsWidth`: icono `print` en `brandLight1`, «Imprimir» (`fontSizeTitle`, DemiBold) y el número de hojas (`fontSizeSmall`, `inkMuted`). Debajo, desplazables, grupos con su título (`fontSizeSmall`, DemiBold, `inkSecondary`): **Destino** («Guardar como PDF» y cada impresora, la predeterminada marcada), **Copias** (− número +) y **En color** solo con impresora, **Orientación**, **Tamaño del papel** (A4, Carta, Oficio) y **Opciones** (colores e imágenes de fondo). Filas de `printRowHeight` con `RadioMark` o `Toggle`, `tintHover` al pasar.
- Abajo: el error (`danger`) o «Enviando a la impresora…» (`inkSecondary`) y los botones Cancelar y la principal, «Imprimir» o «Guardar» según el destino. Enter acepta y Esc cancela. Guardar abre el diálogo del sistema con el título de la página como nombre, en Documentos (o Descargas o la carpeta personal, la primera que exista).

### `ControlsTab` — controles inferiores ocultos
- Los controles inferiores se ocultan solos `controlsHold` (2 s) después de dejar de usarlos (ratón encima, escribiendo en la dirección o con una lista suya abierta los mantiene), con el fundido y desplazamiento de la pantalla completa. Al abrir Mitis se ven y se ocultan a los 2 s. No vuelven al pasar por el borde inferior ni al desplazar la página. En la página de nueva pestaña no se ocultan (no hay página que tapar).
- Ocultos, en el centro del borde inferior queda un **relieve** que sale del borde, de `controlsTabHeight` de alto y, en su parte plana, como mucho `controlsTabMaxWidth`: cada lado es una curva en S de `controlsTabSlope` de ancho (tensión `controlsTabCurve`), horizontal abajo, donde se funde con el borde, y horizontal arriba; sin borde, con el degradado de los controles (`SurfaceShape`, que también lleva el vidrio): el título de la página en `fontSizeSmall` `inkSecondary` (`ink` al pasar). Al pasar el ratón, los controles vuelven. No en pantalla completa ni con Configuración.

### Aviso de micrófono y cámara (icono de la ventana)
- Lo dibuja `CaptureIndicator` (C++), no QML: el icono de Mitis con un círculo rojo (`dangerStrong` de Nocturno, fijo en todos los temas) abajo a la derecha, del 62 % del icono, con el símbolo blanco `microphone`, `camera` o `camera-microphone` (desde 20 px; a 16 px solo el círculo).
- En uso: alterna con el icono normal cada 700 ms. Abierto pero silenciado: la marca fija. Sin uso: el icono normal.
- En la lista de pestañas, delante del de fijar: el mismo símbolo (`iconSizeSmall`) en `dangerStrong` si está en uso o `inkMuted` si está silenciado, con tooltip («Usando el micrófono · usando la cámara», «Micrófono silenciado»…).

### `MiniPlayer` — mini reproductor
- Solo para contenido para escuchar o ver (música, vídeos, streaming). Las llamadas y reuniones no lo usan: una página con cámara, micrófono o pantalla capturándose, o con una conexión WebRTC que recibe audio o vídeo, no informa de nada (`media.js`), y una pestaña que empieza a sonar solo se lleva el mini reproductor si tiene algo que reproducir.
- Solo cuando suena **otra** pestaña: en la que reproduce no hace falta (está su propio reproductor), salvo con Configuración abierta encima.
- **Tamaño fijo** (`miniPlayerWidth` × `miniPlayerHeight`: 270 × 34, el mismo alto que el campo de dirección): no crece con el título, que se acorta con "…".
- **Negro en todos los temas** (como la paleta de DevTools): píldora `miniPlayerBg` sin borde; título en `miniPlayerInkSoft` (`miniPlayerInk` al pasar por encima).
- A la izquierda, el **favicon de la plataforma** que suena (YouTube, Spotify, Apple Music…), atenuado en pausa. Si no hay favicon, el icono `music` (`miniPlayerInk` sonando, `miniPlayerInkSoft` en pausa). Título `título · artista` si la página da artista; clic en él: ir a la pestaña que suena.
- **Botones sin fondo ni borde** (anterior, reproducir/pausa, siguiente), de `miniPlayerButtonSize`: solo el icono, relleno y redondeado (`media-previous`, `media-play`, `media-pause`, `media-next`), de `miniPlayerIconSize` y blanco (`miniPlayerInk`). Al pasar el ratón, el icono se funde (`durationBase`) a un degradado diagonal `miniPlayerHoverStart → miniPlayerHoverEnd` (el de la marca, fijo en todos los temas) y crece suavemente a `miniPlayerHoverScale` (`durationBase`, `OutCubic`); al pulsar, `pressScale`. "Siguiente" se desactiva (35 % de opacidad) si la página no lo ofrece. El degradado lo pinta `IconProvider` (`Icon.colorEnd`), sin shaders.
### Pestaña con sonido
- En la lista de pestañas, un `IconButton` plano `sound` junto a la ✕ mientras la pestaña suena; `muted` si está silenciada (se ve aunque no suene). Pulsarlo alterna el silencio.

### Pestaña suspendida
- Congelada o descargada para ahorrar memoria (también la restaurada que aún no se ha abierto): en la lista de pestañas, favicon con opacidad `suspendedOpacity` (0,45), título en `inkMuted` y, delante de los botones, el icono `suspended` (`iconSizeSmall`, `inkMuted`) en un hueco de `buttonSizeSmall`. No es un botón: al pasar por encima, un tooltip dice «Congelada para ahorrar memoria» o «Descargada para ahorrar memoria: se recargará al abrirla». Al abrirla vuelve a verse normal.

### Pestaña fijada
- Las fijadas van siempre arriba en la lista, en el orden en que se fijaron. Entre ellas y el resto, un separador `line` en un hueco de `spacing`.
- Botones de la fila, de izquierda a derecha: fijar, sonido, cerrar (`IconButton` planos de `buttonSizeSmall`, icono `iconSizeSmall`).
- Fijar: icono `pin`, aparece al pasar por la fila ("Fijar pestaña"). En una fijada se ve siempre, como indicador, y al pasar por encima cambia a `unpin` ("Desfijar pestaña").
- Una fijada no muestra la ✕ ni se cierra con Ctrl+W ni desde la página: hay que desfijarla antes.

### Reordenar pestañas arrastrando
- Se arrastra cualquier fila en vertical (también desde sus botones). Hasta superar el umbral de arrastre del sistema es un clic normal: selecciona la pestaña o pulsa el botón.
- **Fila levantada:** sigue al puntero sobre las demás, con base `surfacePopup`, borde `hairline`, tinte `tintActive` y opacidad `dragOpacity`. Sin sombra ni escala. Cursor de mano cerrada.
- **Destino:** línea de `dropIndicatorHeight` con el degradado de marca (`brand1 → brand2`), redondeada y con `spacing` a cada lado, en el borde de la fila destino del lado hacia el que se mueve (abajo al bajar, arriba al subir). No se ve si la fila volvería a su sitio.
- **Grupos:** una fijada solo cae entre fijadas y una normal entre normales; la línea nunca pasa al otro lado del separador.
- Mientras se arrastra, las demás filas no muestran hover y la lista no se desplaza con el ratón. Si la fila llega a media altura del borde superior o inferior, la lista se desplaza sola (`dragScrollStep` cada `dragScrollInterval`).
- Al soltar, la fila queda en su sitio nuevo y las desplazadas se deslizan con `durationBase` y `easeOut`. Escape o cerrar la lista cancela.
- Con un filtro de texto activo no se arrastra (`TabsPopup.dragEnabled: false`).

### Buscar entre pestañas
- Arriba de la lista de pestañas, un campo `FormField` de `controlHeight`: fondo `tintSunken`, borde `hairline` (`focusRing` con foco), radio `radiusSmall`, icono `search` de `iconSizeSmall` a la izquierda (`brandLight1` con foco, `inkMuted` sin él) y el texto de ejemplo "Buscar pestañas".
- Al abrir la lista (botón o Ctrl+Shift+A) el campo empieza vacío y tiene el foco.
- Filtra mientras se escribe: coincide si el texto aparece en el título o la dirección, sin distinguir mayúsculas ni tildes. Las filas que no coinciden se ocultan; no hay un modelo aparte y cada fila conserva su índice real.
- Con filtro: el separador entre fijadas y normales se oculta (los resultados son una sola tira), no se arrastra, y el resaltado pasa a la primera fila que coincide.
- Sin coincidencias, en lugar de la lista: "Ninguna pestaña coincide" en `inkMuted`, centrado, en una fila de `popupRowHeight`.
- **Teclado.** El foco se queda siempre en el campo; la fila resaltada (`tintHover`, o `tintActive` si es la activa) es la de teclado. Al abrir es la pestaña activa; al empezar a filtrar, la primera coincidencia; si cambia el filtro y sigue visible, se mantiene. El hover del ratón no la mueve.

  | Tecla | Efecto |
  |---|---|
  | ↑ / ↓ | Resaltado a la fila visible anterior / siguiente, sin dar la vuelta |
  | RePág / AvPág | Salta las filas que caben en la vista |
  | Enter | Va a la pestaña resaltada (o a la primera visible) y cierra la lista |
  | Supr | Cierra la resaltada, solo con el cursor al final del texto y sin selección (si no, borra texto). Una fijada no se cierra. El resaltado pasa a la fila que ocupa su lugar, o a la anterior si era la última |
  | Escape | Con texto, lo borra; con el campo vacío, cierra la lista |
  | Tab / Mayús+Tab | Nada: el foco no sale del campo |

  Inicio, Fin y las flechas con modificadores son del campo de texto.
- La lista mide lo que suman sus filas visibles, con `popupMaxHeight` como tope para todo el desplegable.

### `NewTabPage` — página de nueva pestaña
- Minimalista y en una columna centrada de hasta `ntpMaxWidth`: logo, buscador, accesos rápidos, noticias. Se desplaza si no cabe.
- **Fondo:** el del tema (`ThemeBackground`, compartido con Configuración), un radial `bgGlow → bgMid → bgBase` desde arriba a la izquierda (como StartCode). Con imagen propia, la imagen a pantalla completa (recortada, decodificada al tamaño de la pantalla para no gastar RAM) y encima un velo `backgroundScrim`.
- **Logo:** el completo de Mitis (oscuro o claro según el tema), `ntpLogoWidth` de ancho, centrado sobre el buscador a `ntpLogoSpacing`.
- **Buscador:** píldora de `ntpSearchHeight`, `surfaceFloat`, texto `fontSizeLarge`, icono de búsqueda (en `brandLight1` con el foco); sin borde ni anillo de foco. Tiene el foco al abrir una pestaña nueva.
- **Accesos rápidos:** cuadros de `tileSize` con el favicon del sitio (`tileIconSize`) sobre un círculo `faviconBackdrop` de `tileIconBackdrop` (muchos favicons son negros y desaparecerían sobre el fondo oscuro), y el nombre debajo en `inkSecondary`. Sin favicon, la inicial del sitio en `brandLight1`. Los favicons vienen del servicio de iconos de DuckDuckGo y quedan en la caché en disco. La ✕ para quitar aparece al pasar por encima. Hasta `quickLinksMax`; el último cuadro es "Añadir".
- **Noticias:** encabezado con icono `news` en `brandLight1`, tarjetas `NewsCard` (titular de hasta dos líneas en `ink`, fuente y antigüedad en `inkMuted`), en dos columnas desde `ntpNewsTwoColumnsWidth`.
- **Botones de fondo** arriba a la derecha: cambiar (abre el selector de archivos) y quitar (solo con imagen propia). Lo mismo está en Configuración → Nueva pestaña.

### Diálogos (`QuickLinkEditor`)
- `Popup` modal centrado, ancho `dialogWidth`, fondo `PopupBackground`, velo `backgroundScrim` detrás.
- Título en `fontSizeTitle` DemiBold, campos `FormField` (fondo `tintSunken`, radio `radiusSmall`, borde `focusRing` con foco), botones `TextButton` abajo a la derecha: cancelar primero, la acción principal (`primary`, degradado de marca) al final.
- `TextButton` con `danger` (sin `primary`): acción arriesgada y secundaria. Mismo fondo que un botón normal (sin borde, como todos) y texto en `danger`.
- Las filas clicables de un `Popup` sobre la página usan `TapHandler` con `gesturePolicy: TapHandler.ReleaseWithinBounds` (agarre exclusivo): con la política por defecto, lo que hay debajo (una noticia, un acceso rápido de la nueva pestaña) recibe también el clic.

### `SettingsPage` — Configuración
- Página propia (no una pestaña ni HTML): menú de opciones → «Configuración». Cubre la ventana bajo la barra de título, sobre las pestañas; los controles inferiores y el mini reproductor se ocultan mientras está abierta. Se cierra con Esc, con la ✕ (`IconButton`, arriba a la derecha) o al abrir o cambiar de pestaña. Aparece con un fundido (`durationBase`) y la cabecera baja `spacing` (`durationSlow`, `easeOut`).
- **Fondo:** `ThemeBackground`, el de la nueva pestaña.
- **Cabecera** de `settingsHeaderHeight`: círculo de `settingsHeaderIconBox` con el degradado de marca y el icono `settings` de `settingsHeaderIconSize` en `onBrand`, y «Configuración» en `fontSizeHeading` Bold `ink`.
- **Listas largas plegadas** (`ExpandRow`): los sitios con anuncios permitidos y los permisos guardados por sitio se resumen en una fila (título DemiBold `ink`, cuántos hay en `fontSizeSmall` `inkMuted`, icono `expand` a la derecha que gira 180° al desplegar; hover `tintHover`) y la lista aparece debajo al pulsarla.
- **Índice** a la izquierda, de `settingsNavWidth`, solo si la página mide al menos `settingsNavBreakpoint`. Es una lista con su propio desplazamiento que ocupa como mucho `settingsNavHeightRatio` (40 %) del alto; sigue a la sección a la vista y la mantiene en su tercio central (`durationSlow`). una fila de `popupRowHeight` por sección (icono `inkMuted` y nombre DemiBold `inkSecondary`; hover `tintHover`). La sección a la vista: fondo `tintActive`, barra `markerWidth` con el degradado de marca, icono `brandLight1` y nombre Bold `ink`. Pulsar una fila desplaza hasta la sección (`durationSlow`, `easeOut`); al desplazarse, el índice sigue a la sección a la vista.
- **Logo completo de Mitis** al pie de la ventana, centrado en la columna del índice, de `settingsMitisLogoWidth` (180) de ancho y `settingsSectionSpacing` sobre el borde inferior: `mitis-logo-dark.png` en los temas oscuros y `mitis-logo-light.png` en el Claro. Siempre visible: en una ventana baja, el índice se acorta (y se desplaza) para dejarle sitio.
- **«by StartCode»** al final de la columna de ajustes, centrado: «by» en `fontSizeSmall` `inkMuted` y el logo de StartCode de `settingsLogoWidth` (80) × la mitad, al 70 % de opacidad (100 % con el ratón encima, `durationFast`). Sin fondo: `startcode.png` (claro) en los temas oscuros y `startcode-light.png` (tinta del Claro `#1d1631` y su violeta `#7c3aed`, sacado de `startcode.png` cambiando sus dos colores) en el Claro.
- **Bordes que se funden:** el índice y la columna de ajustes desvanecen lo que llega a su borde de arriba o de abajo (solo si hay más contenido por ese lado). En la columna de ajustes la franja es más alta (`settingsContentFadeHeight`, `settingsContentFadeSteps` escalones): los ajustes parecen salir del fondo y volver a él. Franjas (en el índice, de `settingsFadeHeight` y `settingsFadeSteps` escalones) hechas de escalones del propio fondo del tema con opacidad creciente hacia el borde en curva suave (`EdgeFade`), sin shaders.
- **Columna** de hasta `settingsMaxWidth`; índice y columna van juntos y centrados. Entre secciones, `settingsSectionSpacing`. Cada sección: icono `brandLight1` y título `fontSizeLarge` Bold `ink`, una nota opcional en `fontSizeSmall` `inkSecondary` y una tarjeta (`surfaceFloat`, borde `hairline`, `radius`) con los ajustes.
- **Fila de ajuste:** al menos `settingsRowHeight`; título `fontSize` DemiBold `ink` y descripción `fontSizeSmall` `inkMuted` a la izquierda (con icono opcional `inkSoft` delante), controles (`TextButton`, `Toggle`, `Chip`) a la derecha. Entre filas, separador `line` con margen `margin`. Estados en píldora: borde y texto Bold `ok` («Disponible») o `warn` («No disponible»), alto `buttonSizeSmall`.
- **Elección única en filas** (`OptionRow`, «Al iniciar»): título y descripción con un `RadioMark` a la derecha; toda la fila se pulsa (hover `tintHover`), la elegida con fondo `tintActive` y título Bold.
- **Opciones en píldoras** (`ChoiceRow`: zoom, idiomas): título y descripción arriba y debajo los `Chip`, que saltan de línea si no caben. En los idiomas se marcan varios; la descripción dice el orden.
- **Permisos guardados** (`SitePermissionRow`, de `pageRowHeight`): icono del permiso `inkSoft`, sitio DemiBold `ink` y «Ubicación · Permitido» en `inkMuted` (`warn` si es «Bloqueado»); ✕ plana para olvidarlo, visible al pasar.
- **Sitios con anuncios permitidos** (`AllowedSiteRow`, como `SitePermissionRow`): icono `blocker` `inkSoft`, sitio DemiBold `ink` y «Anuncios y rastreadores permitidos» en `warn`; ✕ plana «Volver a bloquear», visible al pasar.
- **Acción con confirmación** («Restablecer la configuración»): el primer clic cambia la descripción por la pregunta y muestra «Cancelar» junto al botón `danger`.
- **Búsqueda:** cada buscador en una fila de `settingsRowHeight`: favicon de `faviconSize` sobre un círculo `faviconBackdrop` de `settingsIconBox` (sin favicon, `search` sobre `tintActive`), nombre DemiBold `ink` y dominio debajo en `fontSizeSmall` `inkMuted`, y un `RadioMark` a la derecha. Hover `tintHover`; el elegido, fondo `tintActive`, nombre Bold y `RadioMark` marcado. **Pulsar una fila lo elige al momento.** Debajo, «Personalizado»: nombre (un tercio) y dirección con `%s` (sin esquema se añade `https://`) en `FormField`, nota con un ejemplo en `fontSizeSmall` `inkMuted` (en `danger` si la dirección no vale) y «Guardar y usar» (`primary`). Guardado, el personalizado es la última fila de la lista.
- **Borrar datos de navegación:** «Borrar datos de» y el periodo en `Chip` (píldoras de `buttonSizeSmall` + `spacing / 2`, borde `hairline`; la elegida, `tintActive`, borde `brandLight1` y texto Bold `ink`). Debajo, una `CheckRow` por dato (`CheckMark`, título y descripción; toda la fila se pulsa, hover `tintHover`): historial y listado de descargas (por periodo), cookies, caché y permisos de sitios (siempre enteros). Abajo, «Borrar datos» (`TextButton` `danger`) y, al terminar, «Datos borrados» con `check` en `ok`, que se desvanece a los `clearedNoticeHold`.
- **Secciones:**
  - Al iniciar: continuar donde lo dejaste, pestaña nueva o una página (dirección en `FormField` y «Usar la página actual»).
  - Apariencia e idioma: tema (`ThemeTile`: una tarjeta de `themeTileWidth` por tema, con su vista previa de `themeTilePreviewHeight` dibujada con los colores de ese tema —barra de título, una tarjeta con texto, los controles con el acento—; borde `hairline`, `hairlineHover` al pasar y 2 px `focusRing` en el elegido; debajo el nombre, Bold `ink` con `check` `brandLight1` si está elegido), zoom de las páginas, modo oscuro en las páginas, idiomas de las páginas.
  - Búsqueda; Nueva pestaña (imagen de fondo: elegir o quitar).
  - Privacidad: cookies de terceros, borrar cookies y caché al cerrar, no rastrear, ocultar la IP local.
  - Anuncios y rastreadores: bloquear (`Toggle`), estado de las listas («335.043 reglas, del 22 de octubre…», con lo bloqueado en la sesión) y «Actualizar ahora», quitar el rastreo de los enlaces, «Permitir en <sitio>» (el de la pestaña activa) y la lista de sitios permitidos.
  - Seguridad: conexiones seguras, ventanas emergentes, JavaScript.
  - Permisos de sitios: «Preguntar» / «Bloquear» (`Chip`) por tipo y, debajo, lo decidido para cada sitio.
  - Contenido: imágenes, reproducción automática.
  - Borrar datos de navegación; Descargas (carpeta y preguntar dónde guardar).
  - Rendimiento: suspender las pestañas que no usas (`ChoiceRow`: 15 min, 30 min, 1 hora, 2 horas, Nunca).
  - Desarrollo: dos `Toggle` independientes. «Herramientas de desarrollo» («Inspeccionar» y F12; al apagarlo se cierran las ventanas de DevTools abiertas) y «Monitor de rendimiento» (muestra el panel; Shift+Esc lo oculta o lo vuelve a mostrar).
  - Acerca de Mitis (versión, Chromium, Widevine) y restablecer la configuración.

### Instalador de Windows (`installer/`)
- Ventana sin marco de 480 × 340 (a 100 %), centrada, esquinas redondeadas de Windows 11; se arrastra desde cualquier punto. Fondo `bgBase` con el resplandor `bgGlow` arriba a la izquierda (como `ThemeBackground`).
- Arriba, el logo provisional de Mitis: círculo de 64 con el degradado `brand1 → brand2` y «Mitis» en Nunito Bold 28 `ink`.
- Estado en 14 `inkSecondary`: «Instalando Mitis… 45 %», «Mitis está listo. Abriéndolo…»; un error, en `danger`, con un botón «Cerrar» (píldora `tintHover`/`tintActive`, borde `hairline`).
- Barra de progreso de 6 de alto, redondeada: pista `tintActive` y relleno con el degradado de la marca; sigue al avance real con suavidad.
- Abajo, «un proyecto de» (11, `inkMuted`) y el logo de StartCode (112 de ancho).
- No se cierra a medias. Al terminar abre Mitis y se cierra solo.
- **Si Mitis ya está instalado**, antes de nada pregunta en la misma ventana: «Mitis ya está instalado», la versión instalada (y la del instalador si difiere) y que el historial, los marcadores y los ajustes se conservan. Botones: «Cancelar», «Reinstalar» (o «Actualizar» si la versión es otra; solo si el `.exe` lleva el paquete) y «Desinstalar» con el estilo de peligro (texto rojo, borde rojo al pasar). Esc cierra mientras no haya nada en marcha. Al desinstalar: «Desinstalando Mitis… N %» con la barra y, al acabar, «Mitis se ha desinstalado.» con «Cerrar».

### `CheckMark` — casilla
- Cuadrado de `radioSize` con radio `checkRadius`. Sin marcar: borde `hairlineStrong` (`hairlineHover` al pasar por su fila). Marcada: degradado de marca con `check` en `onBrand` (`iconSizeSmall`). Solo dibuja: la fila atiende el clic.

### `BookmarksPopup` — marcadores
- Lista desplegable del botón de marcadores, como las demás (`popupWidth`, `PopupBackground`, abre hacia arriba). Arriba, `PopupAction` «Añadir esta página» (`bookmark-add`) o «Quitar esta página» (`bookmark`), con Ctrl+D; desactivada fuera de una página web. Separador `hairline`, buscador (`FormField`, con el foco al abrir) y la lista en `PageRow`; vacía: «Aún no hay marcadores» en `inkMuted`.
- Con la página actual guardada, la estrella del botón va en `brandLight1` (`IconButton.highlighted`). Ctrl+D la guarda (si no lo estaba) y abre la lista.

### `HistoryPopup` — historial
- Menú de opciones → Historial (o Ctrl+H). Título «Historial» (`fontSizeTitle` DemiBold), `PopupAction` «Reabrir la última pestaña cerrada» (Ctrl+Shift+T; desactivada sin cerradas), separador, las 30 últimas visitadas en `PageRow` (detalle: dominio · «hace 5 min»), separador y «Historial en Configuración» (`settings`), que abre Configuración en su sección.

### `PageRow` — fila de una página
- `pageRowHeight`. Favicon sobre círculo `faviconBackdrop` de `buttonSizeSmall` (sin él, la inicial del dominio en `brandLight1` sobre `tintActive`), título en `ink` y detalle en `fontSizeSmall` `inkMuted` (la dirección sin esquema, si no se da otro). Hover `tintHover` y ✕ plana para quitar, visible solo al pasar.

### Sugerencias de la barra de dirección
- Al escribir, una lista sobre el campo (mismo ancho, `PopupBackground`, separada `floatingMargin`), que no se queda el foco. Hasta 6 filas de `popupRowHeight`: icono `bookmark` o `history` (`inkMuted`; `brandLight1` en la elegida), título en `ink` (hasta el 60 % del ancho) y la dirección sin esquema en `fontSizeSmall` `inkMuted`. La elegida con las flechas: `tintActive` y título DemiBold.

### Ventana privada
- Otra ventana como la principal. En la barra de título, junto al nombre, una píldora de `logoSize` de alto: borde `brandLight1`, fondo `tintActive`, icono `private` y «Privada» en `fontSizeSmall` Bold `brandLight1`. El título de la ventana termina en «Mitis (ventana privada)».

### `Toggle` — interruptor
- Pista de `toggleWidth` × `toggleHeight`, totalmente redonda. Apagado: `tintHover` (`tintActive` al pasar), borde `hairline` y bola `inkSoft`. Encendido: degradado de marca (aparece con un fundido `durationFast`) y bola `onBrand`. La bola, separada `toggleKnobInset` del borde, se desliza en `durationBase` con `easeInOut`. Con foco de teclado, borde `focusRing`; Espacio lo cambia.

### `RadioMark` — elección única
- Círculo de `radioSize`. Sin elegir: aro `hairlineStrong` (`hairlineHover` al pasar por su fila). Elegido: relleno con el degradado de marca y punto `onBrand` de `radioDotSize`. Solo dibuja: la fila que lo contiene atiende el clic.

### `CertificateDialog` — certificado inválido
- `PageDialog` con `danger`: tarjeta de `certificateDialogWidth` sobre la página de su pestaña (se oculta y vuelve con ella), icono `not-secure` y título «La conexión no es privada» en `danger`.
- Mensaje en `inkSoft`: quién podría hacerse pasar por el host y qué datos podrían ver otros. Debajo, el motivo concreto en `fontSizeSmall` `inkMuted` (caducado, otro sitio, autoridad no fiable…), siempre en español.
- Botones: «Continuar de todos modos» (`danger`, solo si el motor permite continuar) y «Volver» (`primary`, la opción segura). Enter y Esc vuelven. Al cerrar, el foco pasa a la página.

### `PermissionDialog` — permisos de un sitio
- `PageDialog` de `dialogWidth` sobre la página de su pestaña (se oculta y vuelve con ella). Icono del permiso en `brandLight1` y título «ejemplo.com quiere usar tu cámara» (dominio sin `www.`).
- Mensaje en `inkSoft`: «Mitis recordará tu decisión para este sitio» o, en los de un solo uso (compartir pantalla), «Se volverá a preguntar la próxima vez».
- Botones: «Bloquear» y «Permitir» (`primary`). Esc bloquea; Enter no hace nada (un Enter que se estaba pulsando en la página no debe conceder nada). Al cerrar, el foco pasa a la página.
- Varias peticiones seguidas esperan en cola y se muestran de una en una. Si la pestaña pasa a otro sitio o se cierra, lo pendiente se descarta sin guardar respuesta.

### `ProtectedContentNotice` — falta Widevine
- `PageDialog` sobre la página que pidió contenido protegido sin Widevine en el motor: icono `protected-content` en `brandLight1`, título «Este sitio necesita Widevine», mensaje con el dominio y qué es Widevine, y debajo, en `fontSizeSmall` `inkSecondary`, cómo instalarlo según el sistema (Linux: Google Chrome, `chromium-widevine` en Arch o Firefox con DRM; Windows y macOS: Google Chrome). Ancho `certificateDialogWidth`.
- Un solo botón, «Entendido» (`primary`); Enter y Esc también cierran. Una vez por sitio y sesión.

### `JsDialog` — alert, confirm y prompt
- `PageDialog` de `dialogWidth` sobre la página de su pestaña (se oculta y vuelve con ella), sin icono. Título «localhost dice» / «ejemplo.com dice» (dominio de origen sin `www.`; sin dominio, «Esta página dice») y el mensaje de la página en `inkSoft`, siempre como texto plano.
- `alert`: solo «Aceptar» (`primary`). `confirm`: «Cancelar» y «Aceptar». `prompt`: además un `FormField` con el texto por defecto seleccionado y el foco. Enter acepta; Esc cancela (en `alert`, cierra).
- Aviso de salir (`beforeunload`): título «¿Salir de este sitio?», mensaje «Puede que no se guarden los cambios que hayas hecho», botones «Cancelar» y «Salir» (`primary`).
- Varios seguidos esperan en cola y se muestran de uno en uno. Si la pestaña empieza a cargar otra página se cancelan (salvo el de salir) y, si se cierra, desaparecen con ella. Al cerrar el último, el foco pasa a la página. El diálogo se crea la primera vez que una pestaña lo necesita.

### `FilePicker` — selector de archivos
- `<input type=file>` abre el diálogo de archivos del sistema (`FileDialog`/`FolderDialog` de Qt Quick Dialogs; en Linux sin portal, el de Qt). Uno para toda la ventana: es modal y las peticiones esperan su turno.
- Los tipos de `accept` (`image/*`, `.pdf`…) se convierten en el filtro «Archivos admitidos (*.png *.jpg…)», con «Todos los archivos (*)» como alternativa.

### `AddressBar` — campo de dirección
- Píldora de `controlHeight`, relleno degradado `fillStart → fillEnd`, sin borde.
- **Dos modos:**
  - **Reposo** (sin foco, también tras Enter o Escape): muestra el **título corto** de la página en `inkStrong`, centrado, y el campo se encoge a ese texto más `margin + spacing` a cada lado (`compactWidth`). En páginas web, a la izquierda, el botón del sitio (ver «Botón y panel del sitio»). Hover: tinte `tintHover`, borde `hairlineHover` y cursor de mano.
  - **Escribiendo** (con foco): ocupa todo el hueco entre los grupos de botones, muestra la dirección seleccionada, el icono de búsqueda en `brandLight1` y el anillo `focusRing`.
- El cambio de ancho se anima con `durationBase` y `easeOut`. Los botones acompañan al campo: la separación entre ellos (`2 × spacing`) es la misma en ambos modos y todo el grupo queda centrado.
- **Título corto:** se corta en el primer guion separado por espacios (` - `, ` – `, ` — `) y se descarta lo que sigue. Los guiones dentro de una palabra no cortan. Sin título, se muestra el dominio; sin dirección, "Buscar" en `inkMuted`. Si aun así no cabe, termina en "…".
- Progreso de carga: línea de `progressHeight` con el degradado de marca en el borde inferior, dentro del radio.

### `Glass` — vidrio esmerilado (experimental)
- **Siempre opcional:** apagada por defecto y no forma parte del diseño de Mitis; el aspecto normal (los tonos de Configuración en cada tema) es el que vale. Lo enciende Configuración → Apariencia, «Transparencia con desenfoque (experimental)» (`Settings.glassEffect`, apagada por defecto; `Theme.glassEnabled`). La fila dice si la ventana se dibuja con la GPU y con qué API (OpenGL, Direct3D 11/12, Vulkan, Metal); sin GPU, el interruptor está desactivado.
- **En toda la interfaz**, a través de `Surface` (el fondo de los controles y tarjetas): barra de título, campo de dirección y botones, pestaña del borde, mini reproductor, buscar en la página, zoom, avisos (`Notice`, pantalla completa), listas desplegables, diálogos de las páginas, tooltips, barras de la captura de pantalla; y en las páginas propias, el buscador, los accesos rápidos y las noticias de la nueva pestaña, las tarjetas de Configuración y las de las novedades.
- **Qué se difumina:** el fondo más cercano (`GlassBackdrop`): en la nueva pestaña, Configuración y novedades, su propio fondo (con la imagen propia, si la hay); en los diálogos de una pestaña, la web; en los controles de la ventana, las páginas; en las listas desplegables, `Main.glassBackdrop` (Configuración si está abierta; si no, las páginas).
- **Fondos:** con el vidrio, `ThemeBackground` añade `GlassAurora`: tres manchas radiales de `brand1`, `brand2` y `brandLight1` (opacidad `glassAuroraOpacity`), para que el vidrio tenga color que difuminar.
- **Aislado para poder quitarlo:** todo lleva «Glass» en el nombre (`Glass`, `GlassBackdrop`, `GlassAurora`, `glass*` de Theme y Settings) y solo `Surface`, `SurfaceShape` y `ThemeBackground` lo usan. Quitarlo: en `Surface` y `SurfaceShape`, el hijo `Glass` (y la máscara de `SurfaceShape`) y los `glass.active ?`; en `ThemeBackground`, `GlassAurora`; cambiar `GlassBackdrop` por `Item` (o dejarlo, es un Item); borrar esos archivos, la fila de Configuración y las claves de Settings.
- Copia el trozo de página que tapa el control a media resolución (`ShaderEffectSource` con `sourceRect`), lo difumina (`MultiEffect`, `glassBlur` 48 px, `glassSaturation` 0,3) y lo recorta con la forma del control. Encima, un velo **morado** (`glassTint`), en tres tonos a elegir (Configuración → Apariencia → «Tono del velo», `Settings.glassTone`): lavanda `#c084fc` al 18 %, violeta `#7c3aed` al 30 % y profundo `#2a1352` al 55 % en los temas oscuros (`glassTintsDark`); en el Claro, lilas claros (`glassTintsLight`). El mini reproductor, de texto blanco, usa siempre el de los oscuros (`glassTintDark`). El relleno propio del control pasa a transparente; el borde se mantiene.
- Sin GPU (backend software) no hay shaders: no se dibuja y el control queda opaco como siempre. En el servidor de desarrollo (Chromium sin GPU) la copia del contenido de la página sale vacía: falta confirmar que con una GPU real sí se copia (ver `docs/PLAN.md`).

### `ScreenshotOverlay` — captura de pantalla
- Se abre con Ctrl+Shift+S o «Hacer captura de pantalla» (icono `screenshot`) en el panel del sitio; solo en páginas web. Cubre la página y los controles de abajo (bajo la barra de título). Esc cancela.
- **Elegir:** lo que no entra se oscurece con `screenshotDim`. Al pasar el ratón, la sección de la página que hay debajo (el primer bloque de al menos 120 × 48 px que no sea la página entera) se resalta con `screenshotHoverFill` y borde `brandLight1` de `screenshotBorder`; un clic la elige (sin sección, lo visible). Arrastrando se marca un área libre. La rueda desplaza la página. Arriba, en una píldora `surfacePopup` con borde `hairlineStrong`: icono `screenshot` en `brandLight1`, la indicación y «Página visible», «Página completa» (`TextButton`) y cerrar.
- **Ajustar:** marco de `screenshotBorder` en `brandLight1` con ocho tiradores redondos de `screenshotHandle` (`onBrand` con borde `brandLight1`); arrastrando dentro se mueve. Llevando el borde de arriba o de abajo a la franja `screenshotEdgeZone` del borde de la ventana, la página se desplaza sola (`screenshotScrollStep` px CSS cada `screenshotScrollInterval` ms) y la selección crece; como mucho `screenshotMaxHeight` px CSS de alto.
- **Acciones**, en una píldora bajo la selección (dentro de ella si no cabe): el tamaño en px («773 × 1952 px», `inkSecondary`), «Cancelar», «Copiar» y «Guardar» (`primary`). Mientras captura, «Capturando…»; al terminar, un aviso («Captura copiada», «Captura guardada en descargas») durante `screenshotNoticeHold`. Lo guardado aparece en la lista de descargas, ya completado.
- **Cómo captura:** copia la capa de las páginas (`grabToImage`, sin la interfaz). Si la selección cabe en lo visible, tal como se ve. Si no, por trozos: desplaza, espera `screenshotSliceDelay` a que la página se pinte y copia; en los trozos con la página desplazada oculta lo que la página fija en pantalla (cabeceras, avisos), que si no taparía el contenido y saldría repetido. Al terminar, la página vuelve donde estaba. Los trozos los junta `Screenshot` (C++) en un PNG «Captura de Mitis AAAA-MM-DD HH.MM.SS.png».

### Botón y panel del sitio (`SiteInfoPopup`)
- **Botón** dentro del campo de dirección, a la izquierda, solo en reposo y en páginas web (no en la nueva pestaña ni en archivos): círculo de `buttonSizeSmall` (realce `tintActive` al pasar) con `site-secure` (`inkSoft`, `ink` al pasar) si la conexión es https, `site-insecure` en `warn` si es http y en `danger` si se aceptó un certificado no válido. Tooltip «Conexión segura · Información del sitio». Suma su ancho al del campo en reposo. Pulsarlo abre o cierra el panel.
- **Panel**: lista desplegable (`PopupBackground`, `popupWidth`) que se abre hacia arriba desde el borde izquierdo del campo, con la entrada de las demás listas. De arriba abajo:
  - Sitio: favicon, dominio en `fontSizeTitle` Bold `ink` y título de la página en `fontSizeSmall` `inkMuted`. Separador `line`.
  - **Conexión**: fila con icono de color (`ok` segura, `warn` no segura, `danger` certificado aceptado), título DemiBold y explicación en `fontSizeSmall` `inkMuted`. Si es https, pulsarla despliega el certificado (icono `expand` girado 180°): «Verificado por» (organización y nombre del emisor), «Emitido para», «Válido» (del … al …) y «Protocolo», cada uno con etiqueta `inkMuted` y valor DemiBold `ink` en `fontSizeSmall`; los problemas, en `danger`. Mientras llega, «Comprobando el certificado…». Lo consulta C++ con su propia conexión TLS al sitio (solo al desplegar, se guarda durante la sesión).
  - **Protección contra rastreadores**: icono `blocker` en `ok` (activa) o `inkMuted`, si está activada en este sitio («Activada en este sitio» / «Desactivada en este sitio»; sin contador) y un `Toggle` que la quita o la pone solo en este sitio (lista «Permitidos» del bloqueador) y recarga la página. Con el bloqueador apagado en Configuración, sin interruptor.
  - Separador y acciones (`PopupAction`): «Añadir a marcadores» / «Quitar de marcadores» (Ctrl+D), «Copiar enlace» (pasa a «Enlace copiado» `siteInfoCopiedHold`), «Enviar por correo» (`mailto:`) y «Permisos de sitios» (Configuración).

### `BottomBar` — degradado compartido
- Todos los controles (de atrás a opciones) se leen como una sola pieza de color: `controlsStart` a la izquierda, `controlsEnd` a la derecha. El degradado se reparte sobre el **ancho del grupo**, no de la ventana, así que el botón de atrás siempre lleva el tono claro (`bgGlow`) y el de opciones el oscuro (`bgMid`), con el campo grande o pequeño.
- No se pinta un degradado grande recortado con máscara (costaría GPU): cada control recibe en `fillStart`/`fillEnd` el tramo que le corresponde según su posición, con `tone(x)`.
- Un control nuevo en la fila debe recibir también `fillStart: root.tone(x)` y `fillEnd: root.tone(x + width)`.

### Botón de descargas y `ProgressRing`
- `IconButton` `downloads` («Descargas») **justo antes del de pestañas**. No existe hasta que empieza una descarga y desaparece cuando el panel de la descarga actual se cierra solo (ver abajo). Recibe su tramo del degradado con `tone(x)`, como los demás.
- Aparece y desaparece animando el **ancho de su hueco** (de 0 a `buttonSize + spacing`) con `durationBase` y `easeOut`, junto con su opacidad: el grupo, centrado, se recoloca de forma continua y el degradado se reparte de nuevo sin saltos.
- Pulsarlo abre o cierra el panel de la descarga actual.
- **Anillo de progreso** (`ProgressRing`): con el panel cerrado y la descarga en curso, un arco de `progressRingWidth` sobre el borde del botón, desde arriba en el sentido del reloj, en `brandLight1` sobre una pista `tintActive`, que avanza con el porcentaje. Sin total conocido, un arco de `progressIndeterminateSpan` gira (`durationSpin`). En pausa, el arco en `inkMuted` y quieto. Aparece con fundido (`durationBase`) y acompaña la escala del botón al pasar por encima o pulsar.
- Se dibuja con `QtQuick.Shapes` (`PathAngleArc`; `CurveRenderer` para bordes suaves con Qt 6.6+), sin efectos de GPU ni sombras. Un trazo de `ShapePath` no admite degradado: por eso el color plano de marca.

### `ReleaseNotesPage` — novedades tras actualizar
- En su propia pestaña («Novedades de Mitis», icono de Mitis), sobre el fondo del tema (`ThemeBackground`); los controles inferiores no se ocultan, como en la nueva pestaña.
- Columna centrada de hasta `releaseNotesMaxWidth`: logo completo (`ntpLogoWidth`), título en `fontSizeHeading` Bold `ink` y «Versión x.y.z» en `fontSizeTitle` `inkSecondary`.
- Un grupo por sección del CHANGELOG («Nuevo», «Cambios», «Correcciones», «Ya no está»), separados `releaseNotesGroupSpacing`: encabezado como el de Configuración (icono `brandLight1`, `fontSizeLarge` Bold) y tarjeta `surfaceFloat` sin borde; cada cambio con un punto de `releaseNotesDotSize` con el degradado de marca y el texto en `ink` (Markdown: negrita y código).
- Al final, `TextButton` `primary` «Entendido», que cierra la pestaña.

### Botón de actualizar (`UpdateButton`) y `UpdatePopup`
- Solo con una versión nueva de Mitis (`Updates.available`), **después de Opciones** y solo en la ventana principal. Recibe su tramo del degradado con `tone(x)`, como los demás.
- Es un `IconButton` `update` encendido (icono en `brandLight1`) dentro de un **anillo de `updateRingWidth` con el degradado de marca** `brand1 → brand2` (un círculo con el degradado detrás del botón, que asoma por el borde). El anillo acompaña la escala del botón al pasar por encima o pulsar.
- **Pulso** para que se note: un aro de `updateRingWidth` en `brandLight1` crece de 1 a `updatePulseScale` mientras se desvanece (`updatePulseDuration`, `OutCubic`), espera `updatePulsePause` y repite. Sin sombras ni efectos de GPU.
- Pulsarlo abre o cierra `UpdatePopup`: `Popup` hacia arriba anclado al botón (borde derecho alineado, `floatingMargin`), ancho `updatePopupWidth`, fondo `PopupBackground`, relleno `margin`, fundido `durationFast`. Título «Actualizar ahora» en `ink` DemiBold; debajo, en `fontSizeSmall` `inkMuted`, qué pasará (o el avance de la descarga, o el error en `danger`); abajo a la derecha, `TextButton` «Cancelar» (cierra el popup) y `primary` «Confirmar» (o «Reintentar»). Mientras se descarga no se cierra al pulsar fuera.

### `DownloadPanel` — descargas en curso
- `Popup` hacia arriba anclado al botón de descargas (borde derecho alineado, `floatingMargin` de separación), ancho `downloadPanelWidth`, fondo `PopupBackground`, relleno `margin`. Fundido `durationFast`. No toma el foco del teclado (se abre solo mientras se navega). Se cierra con su ✕ o pulsando fuera.
- Muestra **todas las descargas de la tanda**: las que siguen en curso y las que terminaron desde que se abrió, la más reciente arriba, separadas `margin`. Con muchas, la lista se desplaza a partir de `downloadPanelMaxHeight`.
  - Cabecera en `fontSizeSmall` DemiBold `inkSecondary`: «Descargando 2 archivos», «Descargando 1 archivo» o «Descarga(s) terminada(s)», y un `IconButton` plano `close` («Cerrar»).
  - Cada fila: icono de estado (`downloads` en `brandLight1` en curso, `inkMuted` en pausa o cancelada; `download-done` en `ok`; `download-failed` en `danger`) y nombre del archivo en `ink` DemiBold acortado por el centro con «…» (conserva la extensión).
  - `ProgressBar` (en curso, en pausa y completa): `downloadBarHeight`, pista `tintActive`, relleno con el degradado de marca `brand1 → brand2`; sin total conocido, un tramo de `progressIndeterminateSpan` recorre la pista (`durationIndeterminate`).
  - Estado en `fontSizeSmall`: «3,2 MB de 10 MB» (solo lo recibido sin total), «… · En pausa», «Cancelada» en `inkSecondary`; «Completada · 10 MB» en `ok`; «Error: …» en `danger`.
  - A la derecha del estado, `IconButton` planos de `buttonSizeSmall`: en curso, pausar/reanudar (`pause`/`play`) y cancelar (`download-cancel`, `danger`); terminada, abrir la carpeta (`folder`) y abrir el archivo (`open-file`).
- **Ciclo:** se abre solo al empezar cada descarga y al terminar cada una (aunque se hubiera cerrado), para que se vea cuál terminó. Cuando ya no queda ninguna en curso, se queda `downloadPanelHold` (10 s); luego se cierra, olvida las terminadas y el botón desaparece. Con el ratón encima no se cierra; al salir vuelve a contar. Reabrirlo con el botón durante esa espera reinicia la cuenta. Si empieza otra mientras tanto, se añade arriba y la cuenta se para.
- El **anillo del botón** (panel cerrado) suma las que siguen en curso: lo recibido entre el total de todas (indeterminado si alguna no lo dice), en `inkMuted` si están todas en pausa.
- `ProgressBar` (`value` 0..1, `indeterminate`) es reutilizable.

### Listas desplegables (`TabsPopup`, `OptionsPopup`)
- Fondo `PopupBackground`: `surfacePopup`, borde `hairlineStrong`, radio `radius`.
- Las etiquetas largas se recortan con "…"; nunca se montan sobre el texto de la derecha (atajo, "Próximamente").
- Filas de `popupRowHeight`, radio `radiusSmall`; hover `tintHover`, activa `tintActive`.
- Elemento activo: barra vertical de `markerWidth` con el degradado de marca.
- Separadores: `line`.
- Se abren hacia arriba desde su botón, con `floatingMargin` de separación.
- Las acciones al pie de una lista (nueva pestaña, reabrir) son `PopupAction`: icono `inkSoft`, texto `ink`, atajo `inkMuted` a la derecha. Una acción sin efecto posible se oculta (reabrir sin pestañas cerradas).

### `ContextMenu` — menú contextual de la página
- Sustituye al menú de Chromium al hacer clic derecho en la página. `BrowserTab` avisa con `contextMenuRequested(info)` (datos neutrales) y ejecuta con `runAction(nombre)`; `ContextMenu` decide las opciones.
- Mismo aspecto que las listas desplegables: `PopupBackground`, relleno `spacing`, filas de `popupRowHeight` (radio `radiusSmall`) con icono `inkSoft`, texto `ink` y atajo `fontSizeSmall` `inkMuted` a la derecha. Resaltado `tintHover`. Fila desactivada: icono, texto y atajo en `inkDisabled`, sin resaltado. Entre grupos, separador `line` en un hueco de `spacing`. Fundido `durationFast`.
- Ancho según la fila más larga, entre `optionsWidth` y `popupWidth` (lo que no quepa termina en «…»).
- **Posición:** la esquina superior izquierda en el cursor. Si no cabe a la derecha se abre hacia la izquierda; si no cabe abajo, hacia arriba. Nunca se sale de la ventana.
- Se cierra con Esc, pulsando fuera o al elegir una opción; el teclado vuelve a la página. ↑/↓ recorren las filas disponibles (dando la vuelta) y Enter elige.
- **Grupos**, en este orden y solo los que apliquen:
  | Contexto | Opciones |
  |---|---|
  | Enlace | Abrir en pestaña nueva (segundo plano, a la derecha, en serie como los enlaces) · Abrir en pestaña nueva y cambiar a ella · Copiar dirección del enlace · Guardar enlace |
  | Imagen | Abrir imagen en pestaña nueva (segundo plano) · Copiar imagen · Copiar dirección de la imagen · Guardar imagen |
  | Vídeo o audio | Copiar dirección del archivo · Guardar archivo |
  | Campo editable | Deshacer `Ctrl+Z` · Rehacer `Ctrl+Mayús+Z` · Cortar `Ctrl+X` · Copiar `Ctrl+C` · Pegar `Ctrl+V` · Seleccionar todo `Ctrl+A`, cada una activa según lo que permita el campo |
  | Texto seleccionado (fuera de un campo) | Copiar `Ctrl+C` · Buscar “…” en <buscador elegido> (texto acortado a 24 caracteres; pestaña nueva en primer plano) |
  | Página (solo si no hay ninguno de los anteriores, como Chrome) | Atrás `Alt+←` · Adelante `Alt+→` (desactivadas si no hay historial) · Recargar `Ctrl+R` · Guardar página |
- Guardar no pregunta: va al sistema de descargas como cualquier otra descarga (por eso sin «…»).
- Siempre, como último grupo: Inspeccionar `F12` (abre las herramientas de desarrollo con el elemento bajo el cursor seleccionado).

### `DownloadsPopup` — listado de descargas
- Se abre desde el menú de opciones → «Descargas», hacia arriba y anclado al botón de opciones, como las demás listas (`PopupBackground`, ancho `popupWidth`). Con él abierto, el botón de opciones lo cierra.
- **Cabecera** de `popupRowHeight`: «Descargas» en `fontSizeTitle` DemiBold `ink`; a la derecha «Limpiar» (`fontSizeSmall`, `inkSecondary`, `ink` al pasar por encima), solo si hay terminadas, fallidas o canceladas: las quita del listado (los archivos no se borran). Debajo, separador `hairline`.
- Sin descargas: «Aún no hay descargas» en `inkMuted`, centrado, en una fila de `popupRowHeight`.
- **Filas** de `downloadRowHeight`, la más reciente arriba, radio `radiusSmall`, hover `tintHover`. Con más filas de las que caben, la lista se desplaza; todo el desplegable tiene `popupMaxHeight` de tope.
  - Icono `file` (`inkSoft`; `inkMuted` si falló o se canceló), nombre en `fontSize` (`ink`; `inkSecondary` si falló o se canceló) recortado por el centro con «…» para conservar la extensión.
  - Línea secundaria en `fontSizeSmall` `inkMuted`: en curso «3,2 MB de 10 MB» (solo lo recibido si no se sabe el total); en pausa «En pausa · 3,2 MB de 10 MB»; terminada «10 MB · hace 5 min» («ahora mismo», «hace 2 h», «ayer, 14:32» o «12 oct, 14:32»); fallida «Error: …» en `danger`; cancelada «Cancelada».
  - En curso y en pausa, bajo el texto, un `ProgressBar` (el mismo del panel de la descarga actual). Sin total conocido, en curso, va indeterminado. En pausa, la barra se atenúa y se detiene.
  - Acciones: `IconButton` planos de `buttonSizeSmall` con icono `iconSizeSmall` y tooltip. En curso, siempre visibles: pausar/reanudar (`pause`/`play`) y cancelar (`close`, `danger`). Terminada, al pasar por la fila: abrir (`open-file`), mostrar en la carpeta (`folder`) y quitar del listado (`close`). Fallida o cancelada, al pasar por la fila: quitar del listado.
  - Clic en una terminada: abre el archivo (cursor de mano). Abrir el archivo o la carpeta cierra el listado.

### `TitleBar`
- **Esquinas de la ventana:** redondeadas como las del sistema en Windows 11 (DWM) y macOS (radio 10, curva continua, con la sombra del sistema); rectas maximizada o en pantalla completa. En Linux, las que ponga el gestor de ventanas (`src/windowstyle.*`).
- **macOS:** cerrar, minimizar y zoom como en el sistema, a la izquierda (`macControls`): círculos de `macDotSize` (12) separados `macDotSpacing` (8) en los colores de Apple (`macClose` `#ff5f57`, `macMinimize` `#febc2e`, `macZoom` `#28c840`) con borde `macDotBorder`; con la ventana inactiva, `macDotInactive` (vuelven a su color al pasar el ratón por el grupo). Al pasar por el grupo, los tres muestran su símbolo (`close`, `minimize`, `maximize`/`restore`) en `macDotSymbol`. El nombre de Mitis va centrado en la barra, como el título de las ventanas de macOS, y el avatar a la derecha. En Windows y Linux, los `IconButton` planos de siempre a la derecha.
- Fondo con el degradado `titleBarStart → titleBarEnd` (los tonos de Configuración). Nada de colores de marca vivos como fondo.
- A la izquierda, el nombre de Mitis tal como va en el logo, sin el icono, de `titleBarLogoHeight` (17) de alto (la barra mantiene su `titleBarHeight`): `mitis-wordmark-dark.png` en los temas oscuros y `mitis-wordmark-light.png` en el Claro. Detrás, las píldoras «Beta» y «Privada».
- Los controles de ventana son `IconButton` con `flat: true`: solo iconos; el círculo aparece al pasar por encima.
- Solo marca y controles de ventana. Toda la barra es zona de arrastre; doble clic maximiza. En pantalla completa no se arrastra ni maximiza (además, está oculta).

### Pantalla completa
Dos modos independientes. Con cualquiera de ellos la ventana pasa a pantalla completa; al salir de ambos vuelve a su estado anterior (normal o maximizada). `ResizeHandles` no existe en pantalla completa.
- **De página** (la pide la página, p. ej. el botón de un vídeo; se acepta siempre): la página ocupa toda la ventana. Se ocultan la barra de título, los controles inferiores, el mini reproductor, la búsqueda en la página (se cierra) y el indicador de zoom; las listas abiertas se cierran. Ctrl+F no abre la búsqueda.
  - Sale con **Esc** (también con el foco fuera de la página), con el botón del propio vídeo o cuando lo decide la página. Cambiar de pestaña o cerrar la que está en pantalla completa también sale. Una pestaña en segundo plano que la pida sale al momento.
- **De ventana** (**F11**, alterna): se ocultan la barra de título y los controles inferiores (con el mini reproductor); la página ocupa todo. Al llevar el ratón a la franja inferior (`fullscreenRevealEdge`, 4 px) los controles aparecen flotando (fundido y desplazamiento, `durationBase`) y se esconden al alejarse de ellos. Siguen visibles mientras se escribe en la dirección (Ctrl+L los muestra) o hay una lista suya abierta. La búsqueda y el zoom funcionan igual, pegados al borde superior.
  - Sale solo con **F11**: Esc queda para la página y las listas (cerrar un diálogo web, una lista o la búsqueda no debe sacar de la pantalla completa).
  - Un vídeo puede entrar en pantalla completa de página desde F11; al salir de ella se vuelve a F11. F11 durante la de página sale de las dos.
- **Aviso** (`FullscreenHint`): al entrar, una píldora centrada arriba (a `floatingMargin`) de `controlHeight`, degradado `controlsStart → controlsEnd`, sin borde, y texto `ink`: «Pulsa Esc para salir de la pantalla completa» (página) o «Pulsa F11 para salir de la pantalla completa» (ventana). Aparece con fundido y desplazamiento (`durationBase`), se queda `fullscreenHintHold` (3 s) y se desvanece. No recibe clics. Desaparece al salir.

---

### `DevToolsWindow` — herramientas de desarrollo (F12)
- **Ventana aparte**, una por pestaña: F12 la abre o la cierra (también desde la propia ventana), «Inspeccionar» del menú contextual la abre con el elemento seleccionado. Se cierra sola al cerrar su pestaña o la ventana principal. Mientras no está abierta no existe: no gasta memoria.
- **Estética propia, distinta a propósito del resto de Mitis:** negro puro, blanco y un acento fuerte, sin los violetas y rosas de la marca; es una herramienta de trabajo y no debe confundirse con la página. Tokens `devtools*`, iguales en todos los temas:
  | Token | Valor | Uso |
  |---|---|---|
  | `devtoolsBg` | `#000000` | Marco de la ventana y fondo del panel |
  | `devtoolsSurface` | `#161616` | Botones en reposo; barras del panel |
  | `devtoolsSurfaceHover` | `#262626` | Superficies elevadas del panel |
  | `devtoolsLine` | blanco 16 % | Borde de la ventana y del panel; separadores del panel |
  | `devtoolsInk` | `#ffffff` | Título e iconos; texto del panel |
  | `devtoolsInkSoft` | blanco 62 % | Texto secundario del panel |
  | `devtoolsAccent` | `#00e5ff` | Etiqueta «DevTools», botones al pasar por encima, selección y foco del panel |
  | `devtoolsOnAccent` | `#000000` | Texto e iconos sobre el acento |
  | `devtoolsDanger` | `#ff3b30` | Botón cerrar al pasar por encima |
- **Ventana** sin marco del sistema, esquinas de `devtoolsRadius` (rectas maximizada), borde `devtoolsLine`. Se mueve arrastrando la barra, doble clic maximiza y se redimensiona por los bordes (`ResizeHandles`).
- **Barra** de `devtoolsTitleBarHeight`: a la izquierda, la etiqueta en píldora de acento (icono `devtools` y «DevTools» en Black, `devtoolsOnAccent`) y el título de la página en Bold `devtoolsInk`; a la derecha, minimizar, maximizar y cerrar: círculos de `devtoolsButtonSize` en `devtoolsSurface` que al pasar por encima se llenan de acento (cerrar, de `devtoolsDanger`) con el icono en negro. Tooltip con atajo (cerrar: F12).
- **Panel**: el de Chromium, separado `devtoolsInset` del borde para no tapar las esquinas, con borde `devtoolsLine` y radio `radiusSmall`. Se fuerza en oscuro y se tiñe con los mismos tokens, con letra gruesa (600): ver `assets/scripts/devtools.js`.

## Reglas de implementación

1. **Ningún color, medida ni duración literal** en un componente: siempre `Theme.*`. Si falta un token, se añade a `Theme.qml` y a la tabla de este archivo.
2. **El degradado de marca va siempre de `brand1` a `brand2`**, en ese orden.
3. **Nada de blur ni `MultiEffect` sobre la página.** Si una superficie necesita separarse más, sube su alfa o su borde.
4. **Todo control que flota sobre la página lleva superficie y borde propios**, porque puede quedar sobre una web clara u oscura. Los controles sobre la interfaz (barra de título, listas) son planos.
5. **Sin sombras.** Ni en controles, ni en listas, ni en paneles.
6. **Realce con tintes** (`tintHover`, `tintActive`) encima de la superficie, no cambiando el color de la superficie.
7. **Texto de la interfaz en `ink*`**: elegir la variante por jerarquía, no por gusto.
8. **Iconos**: siempre `Icon` (o `IconButton { icon }`), nunca caracteres Unicode. Ver *Iconos*.

---

## Cómo añadir un tema (Fase 1: tema claro)

1. Los temas declaran **exactamente los mismos tokens de color, en el mismo orden** que Nocturno. Así un token olvidado se detecta comparando listas.
2. Medidas, tipografía y movimiento no cambian entre temas.
3. Tras añadirlo, revisar cada componente en todos los temas: contraste del texto, iconos desactivados y la tinta sobre la marca.

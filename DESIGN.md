# Sistema de diseño — Mitis

Fuente de verdad del aspecto de Mitis. Toda pantalla, componente o cambio visual **debe** seguir estas reglas.

El tema por defecto, **Nocturno**, sale del tema oscuro de StartCode Panel (`/srv/proyectos/startcode_panel/FRONTEND/src/styles/themes/dark.css`): violeta y rosa sobre un negro con matiz morado. Mitis usa los mismos valores, adaptados a QML.

---

## Principios

- **Oscuro y morado.** Fondo casi negro (`#07050d`) con resplandor violeta; la marca es el degradado violeta → rosa (`#a855f7 → #ec4899`).
- **El color nunca se escribe en un componente.** Todo sale de `qml/Theme.qml`. Un `"#hex"` o un `Qt.rgba(...)` fuera de `Theme.qml` es un error.
- **La interfaz flota sobre la página.** Arriba, una barra de título fina; abajo, controles sueltos (botones y campo de dirección) sin barra de fondo. Cada control lleva su propia superficie y borde, sin sombra.
- **Ligero.** Nada de desenfoque (`blur`) ni efectos que obliguen a re-renderizar la página: Mitis prioriza RAM y GPU. Las superficies imitan el "glass" con alfa alto en lugar de borronear lo de detrás.
- **Un tema = un juego de tokens.** Los componentes no saben qué tema está activo; solo leen `Theme`.

---

## Tokens (`qml/Theme.qml`)

### Fondo

| Token | Valor | Uso |
|---|---|---|
| `bgBase` | `#07050d` | Fondo de la ventana |
| `bgMid` | `#150a2e` | Transición de fondos con degradado (reservado) |
| `bgGlow` | `#2a1352` | Resplandor violeta de fondos (reservado) |
| `titleBarStart` → `titleBarEnd` | `#2a1352 → #4a1438` | Barra de título: versión oscura del degradado de marca, violeta profundo → rosa ciruela, de izquierda a derecha |
| `controlsStart` → `controlsEnd` | `#1d0d39 → #340e27` al 92 % | Controles inferiores: el mismo degradado, más oscuro y con un 8 % de transparencia, compartido por todos los controles |

Los fondos de la interfaz usan siempre **tonos oscuros** de la marca. El degradado vivo `brand1 → brand2` se reserva para detalles pequeños (logo, progreso, marcas), nunca para superficies grandes.

### Superficies

| Token | Valor | Uso |
|---|---|---|
| `surfaceFloat` | `rgba(8,3,20,0.88)` | Todo lo que flota sobre la página: botones, campo de dirección, listas desplegables. Equivale a `glass-float` de StartCode, sin blur |
| `surfacePopup` | `#080314` opaco | Listas desplegables. Opacas: sin blur, hasta un 3 % de transparencia deja ver el texto de la página de detrás |
| `selectBg` | `#1a0f3d` | Fondo de selects y listas opacas (reservado) |

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

**Mitis no usa sombras.** Las superficies se separan de la página por su relleno oscuro y un borde fino (`hairline`); el hover se marca con tinte y borde, no con halo.

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
- Tamaños desde `Theme`: `fontSizeTitle` (14) nombre de la app, `fontSize` (13) texto general, `fontSizeSmall` (12) atajos y notas. Pesos: regular para texto, `Font.DemiBold` para el nombre de la app y títulos.

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

Arrastre de filas: `dragOpacity` (0,85) opacidad de la fila levantada, `dropIndicatorHeight` (2) grosor de la línea de destino, `dragScrollStep` (6 px por paso) velocidad del auto-scroll.

Descargas: `downloadRowHeight` (52) fila de dos líneas del listado, `durationIndeterminate` (1,2 s) vuelta de la barra de progreso sin total conocido, `relativeTimeRefresh` (30 s) refresco de «hace 5 min» en el listado.

Descarga actual: `downloadPanelWidth` (340) ancho del panel, `downloadBarHeight` (4) grosor de su barra, `progressRingWidth` (2) trazo del anillo del botón, `progressIndeterminateSpan` (0,3) fracción que ocupan el tramo de la barra y el arco del anillo sin total conocido, `durationSpin` (1 s) vuelta del anillo sin total, `downloadPanelHold` (10 s) lo que se quedan panel y botón al terminar.

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
| `search` | `search` | Campo de dirección al escribir; menú de opciones y diálogo «Motor de búsqueda» (también en lugar del favicon de un buscador que no carga) |
| `bookmarks`, `bookmark-add`, `bookmark` | `star`, `bookmark-plus`, `bookmark` | Botón y lista de marcadores |
| `options` | `ellipsis` | Botón de opciones |
| `new-tab`, `reopen` | `plus`, `undo-2` | Lista de pestañas: nueva y reabrir cerrada |
| `history`, `downloads`, `profile`, `settings` | `history`, `download`, `circle-user-round`, `settings` | Menú de opciones |
| `background`, `background-reset`, `news` | `image`, `image-off`, `newspaper` | Página de nueva pestaña |
| `music`, `play`, `pause`, `previous`, `next` | `music`, `play`, `pause`, `skip-back`, `skip-forward` | Mini reproductor |
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
| `devtools`, `inspect` | `code-xml`, `scan-search` | Ventana de herramientas de desarrollo (etiqueta «DevTools»); «Inspeccionar» del menú contextual |

### `IconButton` — botón flotante
- `icon` (nombre de `assets/icons/`, tamaño `iconSize`) o, si no, `glyph` (texto corto: el contador de pestañas).
- Círculo de `buttonSize`, relleno degradado `fillStart → fillEnd` (por defecto `surfaceFloat` plano), borde `hairline`.
- Hover: tinte `tintHover`, borde `hairlineHover`, escala `hoverScale`, icono `ink`.
- Pulsado: tinte `tintActive`, escala `pressScale`.
- `danger: true` (cerrar): al pasar por encima el fondo pasa a `dangerStrong` y el icono a `onBrand`.
- `flat: true`: solo el icono en reposo; al pasar por encima aparece el círculo con `tintActive` (o `dangerStrong` si es `danger`). Se usa en la barra de título y dentro de las listas.
- Desactivado: icono `inkDisabled`.

### `Tooltip` — qué hace un control
- Fondo `surfacePopup`, borde `hairlineStrong`, radio `radiusSmall`, relleno `tooltipPaddingX` × `tooltipPaddingY`, texto `fontSizeSmall`.
- Dos partes: la acción en `ink` y, si tiene, el atajo en `inkMuted` (`Atrás  Alt+←`).
- Siempre en una sola línea. Aparece tras `tooltipDelay` (1 s), con fundido `durationFast`; se oculta al pulsar. Encima del control; debajo en la barra de título (`below`). Nunca se sale de la ventana.
- **Todo botón de solo icono lleva tooltip.** En `IconButton`: `tooltip`, `shortcut` y `tooltipBelow`. El texto es un verbo o sustantivo corto en español; el atajo, el mismo que define `Main.qml`.

### `FindBar` — buscar en la página
- Píldora flotante de `findBarWidth` × `controlHeight`, **centrada bajo la barra de título** (a `floatingMargin`), con el degradado `controlsStart → controlsEnd` de los controles y borde `hairline` (`focusRing` con el foco en el campo).
- Contenido: icono de búsqueda (`brandLight1` con foco), campo sin fondo, contador en `inkMuted` ("2 de 7") o "Sin coincidencias" en `danger`, y tres `IconButton` planos: anterior, siguiente, cerrar. Sus tooltips salen hacia abajo.
- Aparece con fundido (`durationBase`) y un pequeño desplazamiento desde arriba.
- Busca mientras se escribe. Intro: siguiente; Mayús+Intro: anterior; Esc: cerrar (el teclado vuelve a la página y se quita el resaltado).
- Atajos globales: Ctrl+F abre (con el texto anterior seleccionado); F3/Ctrl+G siguiente; Mayús+F3/Ctrl+Mayús+G anterior. No se abre en la página de nueva pestaña. Se cierra al cambiar de pestaña.

### `ZoomIndicator` — zoom de la pestaña
- Píldora de `controlHeight` **arriba a la derecha**, bajo la barra de título (a `floatingMargin` de ella y `margin` del borde), con el degradado de los controles y borde `hairline`.
- Contenido: `IconButton` plano "−", el porcentaje (`ink`, DemiBold, ancho fijo `zoomLabelWidth` para que no baile), "+" y, si no está al 100 %, un separador `line` y "Restablecer" (`inkSecondary`, `ink` al pasar por encima).
- Aparece (fundido y desplazamiento, `durationBase`) con cada cambio de zoom de la pestaña activa; se queda `zoomIndicatorHold` (2 s) desde el último cambio y se cierra solo. Con el ratón encima no se cierra; al salir vuelve a contar. Cambiar de pestaña no lo muestra.
- Pasos de Chrome: 25, 33, 50, 67, 75, 80, 90, 100, 110, 125, 150, 175, 200, 250, 300, 400, 500 %. Atajos: Ctrl + `+` / `=` / `+` numérico, Ctrl + `-`, Ctrl + `0`. El zoom es de la pestaña y se mantiene al navegar dentro de ella.

### `MiniPlayer` — mini reproductor
- Aparece (fundido `durationBase`) centrado justo encima de la barra de búsqueda mientras una pestaña reproduce algo; desaparece si la página ya no tiene nada que reproducir.
- **Tamaño fijo** (`miniPlayerWidth` × `miniPlayerHeight`: 270 × 34, el mismo alto que el campo de dirección): no crece con el título, que se acorta con "…". Píldora con el degradado `controlsStart → controlsEnd` y borde `hairline`, como los controles.
- A la izquierda, el **favicon de la plataforma** que suena (YouTube, Spotify, Apple Music…: el de la pestaña, sin descargar nada), atenuado en pausa. Si no hay favicon, el icono `music` (`brandLight1` sonando, `inkMuted` en pausa). Título en `inkStrong` (`título · artista` si la página da artista) y tres `IconButton` planos: anterior, play/pausa, siguiente. "Siguiente" se desactiva si la página no lo ofrece; "anterior" vuelve al inicio si ya avanzó.
- Clic en el título: ir a la pestaña que suena.

### Pestaña con sonido
- En la lista de pestañas, un `IconButton` plano `sound` junto a la ✕ mientras la pestaña suena; `muted` si está silenciada (se ve aunque no suene). Pulsarlo alterna el silencio.

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
- Minimalista y en una columna centrada de hasta `ntpMaxWidth`: buscador, accesos rápidos, noticias. Se desplaza si no cabe.
- **Fondo:** el del tema, un radial `bgGlow → bgMid → bgBase` desde arriba a la izquierda (como StartCode). Con imagen propia, la imagen a pantalla completa (recortada, decodificada al tamaño de la pantalla para no gastar RAM) y encima un velo `backgroundScrim`.
- **Buscador:** píldora de `ntpSearchHeight`, `surfaceFloat`, texto `fontSizeLarge`, icono de búsqueda; borde `focusRing` con foco. Tiene el foco al abrir una pestaña nueva.
- **Accesos rápidos:** cuadros de `tileSize` con el favicon del sitio (`tileIconSize`) sobre un círculo `faviconBackdrop` de `tileIconBackdrop` (muchos favicons son negros y desaparecerían sobre el fondo oscuro), y el nombre debajo en `inkSecondary`. Sin favicon, la inicial del sitio en `brandLight1`. Los favicons vienen del servicio de iconos de DuckDuckGo y quedan en la caché en disco. La ✕ para quitar aparece al pasar por encima. Hasta `quickLinksMax`; el último cuadro es "Añadir".
- **Noticias:** encabezado con icono `news` en `brandLight1`, tarjetas `NewsCard` (titular de hasta dos líneas en `ink`, fuente y antigüedad en `inkMuted`), en dos columnas desde `ntpNewsTwoColumnsWidth`.
- **Botones de fondo** arriba a la derecha: cambiar (abre el selector de archivos) y quitar (solo con imagen propia).

### Diálogos (`QuickLinkEditor`, `SearchEngineDialog`)
- `Popup` modal centrado, ancho `dialogWidth`, fondo `PopupBackground`, velo `backgroundScrim` detrás.
- Título en `fontSizeTitle` DemiBold, campos `FormField` (fondo `tintSunken`, radio `radiusSmall`, borde `focusRing` con foco), botones `TextButton` abajo a la derecha: cancelar primero, la acción principal (`primary`, degradado de marca) al final.
- `TextButton` con `danger` (sin `primary`): acción arriesgada y secundaria. Mismo fondo que un botón normal, texto en `danger` y, al pasar por encima, borde en `danger`.

### `SearchEngineDialog` — motor de búsqueda
- Se abre desde el menú de opciones → «Motor de búsqueda» (hasta que exista la página de Configuración). Diálogo como los demás: título «Motor de búsqueda».
- Lista de buscadores en filas de `popupRowHeight` (radio `radiusSmall`, hover `tintHover`): favicon de `faviconSize` del servicio de iconos de DuckDuckGo (sin él, el icono `search` en `inkSoft`), nombre en `ink` y dominio a la derecha en `fontSizeSmall` `inkMuted`. El elegido: fondo `tintActive`, barra `markerWidth` con el degradado de marca y nombre DemiBold. **Pulsar una fila lo elige al momento y cierra.**
- Debajo, separador `line` y «Personalizado» (`fontSizeSmall` `inkSecondary`): dos `FormField` (nombre opcional y dirección con `%s` donde va el texto; sin esquema se añade `https://`) y una nota `fontSizeSmall` `inkMuted` con un ejemplo, que pasa a `danger` si la dirección no vale. Botones «Cerrar» y «Usar personalizado» (`primary`). Una vez guardado, el personalizado aparece como última fila de la lista.
- Las filas clicables de un `Popup` sobre la página usan `TapHandler` con `gesturePolicy: TapHandler.ReleaseWithinBounds` (agarre exclusivo): con la política por defecto, lo que hay debajo (una noticia, un acceso rápido de la nueva pestaña) recibe también el clic.

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
- Píldora de `controlHeight`, relleno degradado `fillStart → fillEnd`, borde `hairline`.
- **Dos modos:**
  - **Reposo** (sin foco, también tras Enter o Escape): muestra el **título corto** de la página en `inkStrong`, centrado, y el campo se encoge a ese texto más `margin + spacing` a cada lado (`compactWidth`). Sin icono. Hover: tinte `tintHover`, borde `hairlineHover` y cursor de mano.
  - **Escribiendo** (con foco): ocupa todo el hueco entre los grupos de botones, muestra la dirección seleccionada, el icono de búsqueda en `brandLight1` y el borde `focusRing`.
- El cambio de ancho se anima con `durationBase` y `easeOut`. Los botones acompañan al campo: la separación entre ellos (`2 × spacing`) es la misma en ambos modos y todo el grupo queda centrado.
- **Título corto:** se corta en el primer guion separado por espacios (` - `, ` – `, ` — `) y se descarta lo que sigue. Los guiones dentro de una palabra no cortan. Sin título, se muestra el dominio; sin dirección, "Buscar" en `inkMuted`. Si aun así no cabe, termina en "…".
- Progreso de carga: línea de `progressHeight` con el degradado de marca en el borde inferior, dentro del radio.

### `BottomBar` — degradado compartido
- Todos los controles (de atrás a opciones) se leen como una sola pieza de color: `controlsStart` a la izquierda, `controlsEnd` a la derecha. El degradado se reparte sobre el **ancho del grupo**, no de la ventana, así que el botón de atrás siempre es violeta y el de opciones siempre rosa, con el campo grande o pequeño.
- No se pinta un degradado grande recortado con máscara (costaría GPU): cada control recibe en `fillStart`/`fillEnd` el tramo que le corresponde según su posición, con `tone(x)`.
- Un control nuevo en la fila debe recibir también `fillStart: root.tone(x)` y `fillEnd: root.tone(x + width)`.

### Botón de descargas y `ProgressRing`
- `IconButton` `downloads` («Descargas») **justo antes del de pestañas**. No existe hasta que empieza una descarga y desaparece cuando el panel de la descarga actual se cierra solo (ver abajo). Recibe su tramo del degradado con `tone(x)`, como los demás.
- Aparece y desaparece animando el **ancho de su hueco** (de 0 a `buttonSize + spacing`) con `durationBase` y `easeOut`, junto con su opacidad: el grupo, centrado, se recoloca de forma continua y el degradado se reparte de nuevo sin saltos.
- Pulsarlo abre o cierra el panel de la descarga actual.
- **Anillo de progreso** (`ProgressRing`): con el panel cerrado y la descarga en curso, un arco de `progressRingWidth` sobre el borde del botón, desde arriba en el sentido del reloj, en `brandLight1` sobre una pista `tintActive`, que avanza con el porcentaje. Sin total conocido, un arco de `progressIndeterminateSpan` gira (`durationSpin`). En pausa, el arco en `inkMuted` y quieto. Aparece con fundido (`durationBase`) y acompaña la escala del botón al pasar por encima o pulsar.
- Se dibuja con `QtQuick.Shapes` (`PathAngleArc`; `CurveRenderer` para bordes suaves con Qt 6.6+), sin efectos de GPU ni sombras. Un trazo de `ShapePath` no admite degradado: por eso el color plano de marca.

### `DownloadPanel` — descarga actual
- `Popup` hacia arriba anclado al botón de descargas (borde derecho alineado, `floatingMargin` de separación), ancho `downloadPanelWidth`, fondo `PopupBackground`, relleno `margin`. Fundido `durationFast`. No toma el foco del teclado (se abre solo mientras se navega). Se cierra con su ✕ o pulsando fuera.
- Muestra **solo la descarga más reciente** (`Downloads.currentId`):
  - Arriba: icono de estado (`downloads` en `brandLight1` en curso, `inkMuted` en pausa o cancelada; `download-done` en `ok`; `download-failed` en `danger`), nombre del archivo en `ink` DemiBold acortado por el centro con «…» (conserva la extensión) y un `IconButton` plano `close` («Cerrar»).
  - `ProgressBar` (en curso, en pausa y completa): `downloadBarHeight`, pista `tintActive`, relleno con el degradado de marca `brand1 → brand2`; sin total conocido, un tramo de `progressIndeterminateSpan` recorre la pista (`durationIndeterminate`).
  - Estado en `fontSizeSmall` `inkSecondary`: «3,2 MB de 10 MB» (solo lo recibido sin total), «… · En pausa», «Completada · 10 MB», «Cancelada»; «Error: …» en `danger`.
  - En curso, a la derecha del estado: `IconButton` planos de `buttonSizeSmall` pausar/reanudar (`pause`/`play`) y cancelar (`download-cancel`, `danger`).
  - Terminada: `TextButton` «Abrir carpeta» y «Abrir» (`primary`: abre o ejecuta el archivo), alineados a la derecha.
- **Ciclo:** se abre solo al empezar una descarga. Al terminar (bien, con error o cancelada) se vuelve a abrir aunque se hubiera cerrado y se queda `downloadPanelHold` (10 s); luego se cierran el panel y el botón. Con el ratón encima no se cierra; al salir vuelve a contar. Reabrirlo con el botón durante esa espera reinicia la cuenta. Si empieza otra descarga mientras tanto, el panel pasa a la nueva y el botón se queda. Si al cerrarse queda otra descarga en curso, el botón se queda con ella.
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
- Fondo con el degradado oscuro `titleBarStart → titleBarEnd` (violeta profundo → rosa ciruela). Nada de colores de marca vivos como fondo.
- Logo con el degradado de marca vivo y nombre en `inkSoft`.
- Los controles de ventana son `IconButton` con `flat: true`: solo iconos; el círculo aparece al pasar por encima.
- Solo marca y controles de ventana. Toda la barra es zona de arrastre; doble clic maximiza. En pantalla completa no se arrastra ni maximiza (además, está oculta).

### Pantalla completa
Dos modos independientes. Con cualquiera de ellos la ventana pasa a pantalla completa; al salir de ambos vuelve a su estado anterior (normal o maximizada). `ResizeHandles` no existe en pantalla completa.
- **De página** (la pide la página, p. ej. el botón de un vídeo; se acepta siempre): la página ocupa toda la ventana. Se ocultan la barra de título, los controles inferiores, el mini reproductor, la búsqueda en la página (se cierra) y el indicador de zoom; las listas abiertas se cierran. Ctrl+F no abre la búsqueda.
  - Sale con **Esc** (también con el foco fuera de la página), con el botón del propio vídeo o cuando lo decide la página. Cambiar de pestaña o cerrar la que está en pantalla completa también sale. Una pestaña en segundo plano que la pida sale al momento.
- **De ventana** (**F11**, alterna): se ocultan la barra de título y los controles inferiores (con el mini reproductor); la página ocupa todo. Al llevar el ratón a la franja inferior (`fullscreenRevealEdge`, 4 px) los controles aparecen flotando (fundido y desplazamiento, `durationBase`) y se esconden al alejarse de ellos. Siguen visibles mientras se escribe en la dirección (Ctrl+L los muestra) o hay una lista suya abierta. La búsqueda y el zoom funcionan igual, pegados al borde superior.
  - Sale solo con **F11**: Esc queda para la página y las listas (cerrar un diálogo web, una lista o la búsqueda no debe sacar de la pantalla completa).
  - Un vídeo puede entrar en pantalla completa de página desde F11; al salir de ella se vuelve a F11. F11 durante la de página sale de las dos.
- **Aviso** (`FullscreenHint`): al entrar, una píldora centrada arriba (a `floatingMargin`) de `controlHeight`, degradado `controlsStart → controlsEnd`, borde `hairline` y texto `ink`: «Pulsa Esc para salir de la pantalla completa» (página) o «Pulsa F11 para salir de la pantalla completa» (ventana). Aparece con fundido y desplazamiento (`durationBase`), se queda `fullscreenHintHold` (3 s) y se desvanece. No recibe clics. Desaparece al salir.

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

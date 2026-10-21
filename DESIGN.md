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

Radios: `radius` (12) para listas y paneles, `radiusSmall` (8) para filas dentro de ellos. Botones y campo de dirección son totalmente redondos (`height / 2`).

---

## Layout

```
Window (bgBase, sin marco)
├── TitleBar      30 px · degradado oscuro titleBarStart → titleBarEnd · separador hairlineSoft
│                 logo (degradado de marca) + "Mitis" (inkSoft) · minimizar / maximizar / cerrar
├── páginas       WebEngineView, de la barra de título hasta el borde inferior
└── BottomBar     controles sueltos flotando sobre la página, sin fondo
                  un solo grupo centrado: [← → ⟳] · campo de dirección · [pestañas, marcadores, opciones]
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
| `search` | `search` | Campo de dirección al escribir |
| `bookmarks`, `bookmark-add`, `bookmark` | `star`, `bookmark-plus`, `bookmark` | Botón y lista de marcadores |
| `options` | `ellipsis` | Botón de opciones |
| `new-tab`, `reopen` | `plus`, `undo-2` | Lista de pestañas: nueva y reabrir cerrada |
| `history`, `downloads`, `profile`, `settings` | `history`, `download`, `circle-user-round`, `settings` | Menú de opciones |
| `background`, `background-reset`, `news` | `image`, `image-off`, `newspaper` | Página de nueva pestaña |
| `music`, `play`, `pause`, `previous`, `next` | `music`, `play`, `pause`, `skip-back`, `skip-forward` | Mini reproductor |
| `sound`, `muted` | `volume-2`, `volume-x` | Pestaña que suena / silenciada |
| `pin`, `unpin` | `pin`, `pin-off` | Lista de pestañas: fijar / desfijar |

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

### Diálogos (`QuickLinkEditor`)
- `Popup` modal centrado, ancho `dialogWidth`, fondo `PopupBackground`, velo `backgroundScrim` detrás.
- Título en `fontSizeTitle` DemiBold, campos `FormField` (fondo `tintSunken`, radio `radiusSmall`, borde `focusRing` con foco), botones `TextButton` abajo a la derecha: cancelar primero, la acción principal (`primary`, degradado de marca) al final.

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

### Listas desplegables (`TabsPopup`, `OptionsPopup`)
- Fondo `PopupBackground`: `surfacePopup`, borde `hairlineStrong`, radio `radius`.
- Las etiquetas largas se recortan con "…"; nunca se montan sobre el texto de la derecha (atajo, "Próximamente").
- Filas de `popupRowHeight`, radio `radiusSmall`; hover `tintHover`, activa `tintActive`.
- Elemento activo: barra vertical de `markerWidth` con el degradado de marca.
- Separadores: `line`.
- Se abren hacia arriba desde su botón, con `floatingMargin` de separación.
- Las acciones al pie de una lista (nueva pestaña, reabrir) son `PopupAction`: icono `inkSoft`, texto `ink`, atajo `inkMuted` a la derecha. Una acción sin efecto posible se oculta (reabrir sin pestañas cerradas).

### `TitleBar`
- Fondo con el degradado oscuro `titleBarStart → titleBarEnd` (violeta profundo → rosa ciruela). Nada de colores de marca vivos como fondo.
- Logo con el degradado de marca vivo y nombre en `inkSoft`.
- Los controles de ventana son `IconButton` con `flat: true`: solo iconos; el círculo aparece al pasar por encima.
- Solo marca y controles de ventana. Toda la barra es zona de arrastre; doble clic maximiza.

---

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

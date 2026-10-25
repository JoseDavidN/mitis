# Rendimiento: memoria de Mitis frente a Chrome y Firefox

Comparativa de la Fase 5 (criterio: «con 20 pestañas, 5 activas, Mitis usa
claramente menos RAM que Chrome en el mismo equipo»). Medido el 2026-10-22.

## Resultado

| Navegador | Al minuto de cargar todo (T1) | A los 16 min sin tocar nada (T2) |
|---|---|---|
| **Mitis 0.1.0** (Chromium 140, bloqueador activo) | 2199 MB · 26 procesos | **1922 MB · 13 procesos** |
| Mitis sin bloqueador | 2478 MB · 25 procesos | — |
| Chrome for Testing 156 | 3245 MB · 76 procesos | 3305 MB · 93 procesos |
| Firefox 158 | 2318 MB · 34 procesos | 3251 MB · 71 procesos |

- **Criterio cumplido:** a los 16 minutos, Mitis usa **un 42 % menos que Chrome**
  (1922 frente a 3305 MB) y la mitad de procesos que Firefox.
- Recién cargadas las 20 páginas, Mitis ya usa un 32 % menos que Chrome y algo
  menos que Firefox. Sin el bloqueador, un 24 % menos que Chrome: el bloqueador
  ahorra ~280 MB en estas páginas.
- Con el tiempo, Chrome y Firefox **crecen** (más procesos y memoria: anuncios
  que se recargan, vídeos, trabajo en segundo plano) y Mitis **baja**: las 15
  pestañas no activas se descargan (suspensión, a los 15 min en esta prueba).

## Qué se midió

- **Páginas:** las 20 de `tools/paginas.txt` (YouTube, Wikipedia, GitHub, Amazon,
  Mercado Libre, El Tiempo, El País, BBC Mundo, Stack Overflow, MDN, docs de Qt,
  IMDb, CNN, Reddit, Hacker News, Infobae, Semana, Twitch, ESPN, Booking), sin
  iniciar sesión.
- **Procedimiento** (`tools/medir_ram.py`, igual para los tres): perfil nuevo;
  abrir las 20; recorrer todas con Ctrl+Tab (6 s visible cada una) para que
  todas carguen; T1 al minuto de terminar el recorrido; T2 a los 16 minutos
  sin tocar nada.
- **5 activas:** en Mitis, las 4 primeras van fijadas (nunca se suspenden) y la
  visible es la quinta. Chrome y Firefox no suspenden pestañas en 16 minutos
  con memoria libre, así que para ellos las 20 siguen activas.
- **Memoria:** suma del PSS (`/proc/<pid>/smaps_rollup`) del proceso y todos
  sus descendientes. El PSS reparte la memoria compartida entre quienes la
  usan, así que la suma no cuenta dos veces lo mismo (es lo que muestra el
  panel de memoria de Mitis, Shift+Esc).

## Condiciones y límites

- Equipo: Arch Linux, 2 núcleos, 7,8 GB de RAM; servidor sin GPU, ventanas en
  Xvnc (renderizado por software en los tres).
- Una sola medición por navegador: entre cargas de las mismas páginas hay
  variaciones de ±100–150 MB (anuncios y contenido que cambian). La diferencia
  con Chrome es mucho mayor que ese ruido.
- Versiones distintas del motor: Mitis usa el Chromium 140 de Qt WebEngine
  6.11; Chrome for Testing es la 156.
- Mitis lleva el bloqueador activo de serie; Chrome y Firefox, sin extensiones.
  La fila «sin bloqueador» separa su efecto.
- En pantallas con GPU, los tres usan más memoria de vídeo y algo distinta de
  RAM: repetir la medición en un escritorio normal para tener cifras de uso real.

## Opciones de Chromium probadas (Mitis, T1)

| Opciones | RAM | Procesos |
|---|---|---|
| Ninguna | 2122–2223 MB | 25–26 |
| `--process-per-site` | 2500 MB | 29 |
| `--renderer-process-limit=6` | 2126 MB | 13 |
| `--enable-low-end-device-mode` | 2383 MB | 27 |

Ninguna ahorra memoria: limitar procesos los reduce a la mitad, pero la RAM es
la misma (las páginas se juntan en menos procesos) y empeorarían la fluidez y
la estabilidad (una página colgada arrastraría a otras). No se usan. Sí se
usan las que quitan trabajo en segundo plano (ver `setupChromiumFlags()` en
`src/main.cpp`).

## Paneles creados al abrirlos (2026-10-24, versión 0.11.1)

Antes, `Main.qml` creaba al arrancar, en cada ventana (también las privadas),
Configuración entera, las ocho listas desplegables, el menú contextual, el
monitor de rendimiento, la captura de pantalla y una ventana de imprimir por
pestaña, aunque no se abrieran nunca. Ahora existen solo mientras se usan
(`LazyPopup` para las listas y el menú; `Loader` para lo demás, también la pestaña de novedades) y se sueltan al
cerrarse; el monitor de rendimiento, solo con su opción activada.

Medido en el servidor de desarrollo (Xvnc, dibujo por software, modo `--dev`
en los dos casos: mismo ejecutable, solo cambia `Main.qml`), 25 s tras la
primera imagen, con PSS como en el resto del documento. Cada arranque parte de
una copia idéntica del perfil (sesión vacía) y abre una página sencilla; media
de 4 arranques:

| | Antes | Después | Diferencia |
|---|---|---|---|
| Hasta la primera imagen | 5,8 s | 4,0 s | −1,8 s (−31 %) |
| Proceso principal (interfaz) | 230 MB | 205 MB | −25 MB (−11 %) |
| Total (con la página) | 349 MB | 324 MB | −25 MB (−7 %) |
| Lo que añade una ventana privada (proceso principal) | +36 MB | +19 MB | −17 MB (−48 %) |

Con muchas pestañas el ahorro crece, porque antes cada una llevaba su ventana
de imprimir: con unas 50–60 pestañas restauradas (sin cargar), el proceso
principal pasó de 352 a 299 MB (−53 MB) y la primera imagen, de 13,9 a 11,8 s
(medida menos controlada: la sesión crecía entre arranques, en contra del
cambio).

En modo `--dev` los QML se compilan al cargarlos, así que el arranque mejora
algo menos en el ejecutable normal (que los trae compilados); la memoria es
del mismo orden. Abrir un panel por primera vez lo crea en ese momento (unas
decenas de milisegundos).

## Precargar páginas (2026-10-25, versión 0.12.0)

«Precargar páginas» (Configuración → Rendimiento, apagada por defecto):
`assets/scripts/preload.js` precarga la página del enlace que tiene el ratón
encima 65 ms (o que se pulsa).

Medido en el servidor de desarrollo con un servidor local que simula una
conexión lenta (0,15 s de latencia por petición y 0,6 s para preparar la
página de destino; respuesta `Cache-Control: no-cache`, como la mayoría de
páginas HTML). La prueba pasa el ratón por un enlace, espera y lo pulsa;
copia limpia del perfil, modo `--dev`, 5–8 navegaciones por caso. «Del clic
a la página cargada» se mide fuera de Mitis (hora del clic en el guion y del
aviso de carga en el servidor); «respuesta» y «lista» son los tiempos de
navegación de la propia página (Navigation Timing).

| Caso (ratón encima antes de pulsar) | Del clic a la página cargada | Respuesta | Lista | Descargas de la página |
|---|---|---|---|---|
| Sin precarga (0,5 s) | 1091 ms | 700 ms | 750 ms | 1 por visita |
| `<link rel=prefetch>` (1,5 s) | — | 703 ms | 763 ms | 2 por visita: no se aprovecha |
| `<link rel=prefetch>` con la página guardable (`max-age=60`) | — | 23 ms | 100 ms | 1 |
| Regla de precarga (`speculationrules`, 0,5 s) | **442 ms (−60 %)** | 8 ms | 96 ms | 1 (la precarga) |

`<link rel=prefetch>` va a la caché normal: con `no-cache` (o `max-age=0`,
como GitHub y Wikipedia) la navegación vuelve a pedir la página entera y la
precarga es una descarga doble. Las reglas de precarga la guardan aparte y la
navegación la usa aunque la página pida comprobarse; si la precarga aún no
ha terminado al pulsar, la navegación la espera en vez de empezar otra. La
memoria no cambia de forma apreciable (proceso principal 225 → 215 MB, dentro
de lo que varía de una prueba a otra). El coste es de datos: cada enlace en
el que el ratón se para se descarga (como mucho 20 por página).

## Repetir la medición

```bash
# Pantalla aparte (no la :1 del usuario)
Xvnc :7 -geometry 1400x900 -depth 24 -SecurityTypes None -localhost &
tools/medir_ram.py mitis build/bin/Mitis --filtros ~/.local/share/Mitis/Mitis/filtros --minutos 16
tools/medir_ram.py chrome /ruta/a/chrome --minutos 16
tools/medir_ram.py firefox /ruta/a/firefox --minutos 16
```

Cada medición tarda ~20 minutos y escribe una línea JSON con T1 y T2. Mientras
mide no conviene usar el equipo para otra cosa (ni compilar: la carga de CPU
cambia lo que da tiempo a cargar).

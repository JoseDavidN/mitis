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

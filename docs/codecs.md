# Códecs propietarios (H.264, AAC) en Windows y macOS

Tarea de la Fase 6 (`docs/PLAN.md`, «Códecs propietarios»). Aquí se explica cómo obtener un
Qt WebEngine con H.264 y AAC para Windows y macOS, y cómo hacer que GitHub Actions lo use
en lugar del oficial.

**Para hacerlo con Claude Code en un Windows:** `tools/codecs/GUIA-CLAUDE-WINDOWS.md`
(pasos por fases).

**Versión: 6.11.2.** Sin códecs, el workflow usa Qt 6.11.3, pero **el código fuente de
Qt WebEngine 6.11.3 no está publicado** (comprobado el 2026-10-23: `download.qt.io` solo
tiene las fuentes hasta la 6.11.2 y code.qt.io no tiene la etiqueta `v6.11.3`; el
instalador de Qt sí la da compilada). Sin código no se puede compilar con códecs: se usa
la **6.11.2** en Windows y macOS, y con `QT_VERSION=6.11.2` («Usar en GitHub Actions»)
el workflow instala esa misma versión en los tres sistemas. La 6.11.2 lleva parches de
seguridad de Chromium algo más antiguos que la 6.11.3: cuando se publique el código de
una versión más nueva, repetir con ella («Actualizar Qt»).

Resumen: se compila **solo el módulo qtwebengine**, en un equipo propio, contra un Qt
oficial de la misma versión. El resultado se empaqueta en un archivo (`.7z` en Windows,
`.tar.xz` en macOS), se publica en un release de GitHub y el workflow lo extrae encima del
Qt que instala `install-qt-action`. Si no se ha publicado ninguno, el workflow hace lo de
siempre (Qt oficial, sin códecs).

```
equipo propio (horas)                         GitHub Actions (minutos)
─────────────────────                         ────────────────────────
Qt 6.11.2 oficial (aqt) ─┐                    install-qt-action (Qt 6.11.2)
fuentes de qtwebengine ──┼─ compilar-*.{ps1,sh} ─► .7z/.tar.xz ─► release ─► se extrae encima
FEATURE_..._codecs=ON ───┘                                                  └► Mitis, windeployqt/macdeployqt
```

## Por qué hace falta

- El Qt WebEngine que distribuye Qt (el que instalan el instalador oficial, `aqt` e
  `install-qt-action`) se compila **sin códecs propietarios**: el formato MP4 con H.264 y
  AAC no se reproduce. Lo dice la documentación de Qt
  ([Qt WebEngine Features → Audio and Video Codecs](https://doc.qt.io/qt-6/qtwebengine-features.html#audio-and-video-codecs)):
  la opción viene desactivada (`AUTODETECT OFF` en `src/core/configure.cmake`) y hay que
  activarla al compilar.
- Chromium hace lo mismo: sus compilaciones abiertas solo traen los códecs libres; H.264 y
  AAC quedan para Google Chrome ([chromium.org/audio-video](https://www.chromium.org/audio-video/)).
- Sin ellos fallan Spotify, Netflix y muchos vídeos de la web (los servicios de vídeo y
  audio sirven MP4 con H.264/AAC a los navegadores que lo anuncian; algunos solo eso).
  Spotify y Netflix además necesitan Widevine, que ya resuelve `src/widevine.*` (Fase 3):
  Widevine descifra, pero el motor tiene que saber decodificar lo descifrado.
- **En Arch Linux no hace falta**: el paquete `qt6-webengine` de la distribución ya se
  compila con códecs propietarios (y con Widevine). Tampoco se toca el trabajo `Linux` del
  workflow, que solo comprueba que Mitis compila.

## Requisitos

Los de Qt WebEngine 6.11, según su `configure.cmake` (comprobados en la etiqueta
`v6.11.0` del repositorio [qt/qtwebengine](https://github.com/qt/qtwebengine)) y la
[página de requisitos](https://doc.qt.io/qt-6/qtwebengine-platform-notes.html#building-qt-webengine-from-source).
Qt WebEngine 6.11 se basa en **Chromium 140**.

### Comunes

| Herramienta | Versión mínima | Notas |
|---|---|---|
| Compilador C++20 | ver cada sistema | Qt WebEngine es la excepción de Qt: pide C++20 |
| CMake | 3.19 | |
| Ninja | 1.7.2 | |
| Python | 3.8 | con el módulo `html5lib` (`python -m pip install html5lib`) |
| Node.js | 20, **de 64 bits** | |
| gperf, bison, flex | — | las versiones GNU |
| Qt base | **exactamente** la misma versión | con `qtwebchannel` y `qtpositioning` (ver «Qt base») |

Recursos (estimación, no medida en este proyecto: depende mucho del equipo):

- **Disco:** unos 100 GB libres en Windows y 60 GB en macOS (fuentes ~4 GB extraídas,
  compilación de decenas de GB). Mejor en un SSD.
- **RAM:** 16 GB como mínimo, 32 GB recomendado. Cada trabajo en paralelo de Chromium
  puede pasar de 2 GB; los scripts eligen los trabajos según la RAM (unos 3 GB cada uno).
- **Tiempo:** de 2 a 4 h en un equipo de 8 núcleos y 32 GB; 6 h o más con 4 núcleos o
  poca RAM. Más del doble para un binario universal de macOS (`arm64;x86_64`). Por eso no
  cabe en un runner de GitHub (límite de 6 h por trabajo, 4 núcleos).
- Sin QtPdf (que viene en las mismas fuentes y Mitis no usa) se ahorra un rato: los
  scripts lo desactivan (`-DFEATURE_qtpdf_build=OFF`).

### Windows

- **Visual Studio 2022** (MSVC 14.36 o posterior), con la carga «Desarrollo para el
  escritorio con C++». VS 2019 (14.29) también vale para Qt WebEngine, pero el Qt oficial
  y el workflow usan `msvc2022_64`: usar 2022.
- **SDK de Windows 11 10.0.26100.0 o posterior** (se marca en el instalador de Visual
  Studio). Qt WebEngine lo comprueba al configurar.
- **ATL y MFC de C++** (componentes individuales del instalador de Visual Studio: «ATL de
  C++ para las herramientas de compilación v143 más recientes» y el de MFC; IDs
  `Microsoft.VisualStudio.Component.VC.ATL` y `Microsoft.VisualStudio.Component.VC.ATLMFC`).
  Chromium incluye `atldef.h`: sin ATL, la configuración pasa y la compilación falla al
  empezar («No se puede abrir el archivo incluir: 'atldef.h'»). El script lo comprueba.
- Herramientas, por ejemplo con Chocolatey (consola de administrador):
  `choco install ninja gperf winflexbison3 7zip nodejs-lts python` y después
  `python -m pip install html5lib`. CMake acepta los `win_bison`/`win_flex` de
  winflexbison sin renombrarlos. **No usar** las de MSYS2 ni Cygwin (Qt lo desaconseja).
- **MinGW no sirve** (lo dice Qt y ya lo recoge `CLAUDE.md`).
- Activar las rutas largas de Windows (`LongPathsEnabled`) y trabajar en una ruta corta
  (el script usa `C:\qwe`). Conviene excluir esa carpeta del antivirus (Defender
  ralentiza mucho una compilación de decenas de miles de archivos).

### macOS

- **Xcode** con su SDK de macOS. La documentación de Qt dice «Xcode 12 y SDK de macOS 11»,
  pero ese texto no se ha puesto al día; Chromium 140 en la práctica pide un Xcode y un SDK
  recientes: usar **Xcode 16 o posterior** (SDK de macOS 15). *No verificado aquí*: si la
  configuración o la compilación se quejan del SDK, subir Xcode.
- Herramientas con Homebrew: `brew install cmake ninja node gperf bison flex python` y
  `python3 -m pip install html5lib` (o en un entorno virtual). El `bison` de Xcode es
  demasiado viejo: el script pone delante en el `PATH` los de Homebrew.
- Un Mac con Apple Silicon compila `arm64` por defecto. **El workflow hace un `.dmg`
  universal** (Apple Silicon e Intel) y comprueba que Qt WebEngine traiga las dos
  arquitecturas: el archivo con códecs también tiene que ser universal
  (`--arquitecturas "arm64;x86_64"`), que compila Chromium dos veces. Con solo `arm64`,
  el workflow falla en el paso «Empaquetar» de macOS.

## Qt base

Se compila contra el **mismo** Qt que usa el workflow (versión, compilador y paquetes de
Qt), para que el resultado encaje al extraerlo encima. Qt WebEngine usa API privada de Qt
(Qt Quick, Qt Gui): con otra versión, aunque solo cambie el último número, no carga.

1. Fijar la versión. El workflow pide `6.11.*`, que resuelve a la última (hoy 6.11.2).
   Para usar códecs hay que fijarla (variable `QT_VERSION` del repositorio, ver «Usar en
   GitHub Actions») y compilar exactamente esa.
2. Instalar ese Qt con `aqt` (la herramienta que usa `install-qt-action` por debajo), sin
   `qtwebengine` para que sus cabeceras no se mezclen con las nuevas:

   ```bash
   python -m pip install aqtinstall
   # Windows
   aqt install-qt windows desktop 6.11.2 win64_msvc2022_64 -m qtwebchannel qtpositioning -O C:\Qt
   # macOS
   aqt install-qt mac desktop 6.11.2 clang_64 -m qtwebchannel qtpositioning -O ~/Qt
   ```

   Queda en `C:\Qt\6.11.2\msvc2022_64` y `~/Qt/6.11.2/macos`, las rutas que los scripts
   usan por defecto. Si ya hay un Qt con `qtwebengine`, también funciona (es lo que
   describe la documentación de Qt), pero los scripts avisan.

## Compilar

Los scripts de `tools/codecs/` hacen todos los pasos: comprueban las herramientas (antes
de empezar, para no fallar a las tres horas), descargan las fuentes de qtwebengine de
`download.qt.io` y comprueban su suma MD5, configuran con
`-DFEATURE_webengine_proprietary_codecs=ON`, **comprueban que la opción quedó activada**
en `CMakeCache.txt`, compilan, instalan **solo el módulo** en una carpeta aparte (con la
estructura de Qt: `bin`, `lib`, `resources`, `translations`, `qml`…) y la empaquetan.
Si la compilación se corta (memoria, reinicio), se vuelve a lanzar el mismo comando y
continúa donde se quedó.

### Windows

Desde **«x64 Native Tools Command Prompt for VS 2022»**, con `pwsh` (o `powershell`):

```powershell
pwsh tools\codecs\compilar-windows.ps1 -QtVersion 6.11.2 -QtDir C:\Qt\6.11.2\msvc2022_64
```

Parámetros: `-Trabajo` (carpeta de fuentes y compilación, `C:\qwe`), `-Salida` (instalación,
`C:\qwe\salida`), `-Trabajos` (paralelo; por defecto según núcleos y RAM), `-ConPdf`,
`-SinEmpaquetar`. Resultado: `C:\qwe\qtwebengine-codecs-6.11.2-windows-msvc2022_64.7z`.

### macOS

```bash
tools/codecs/compilar-macos.sh --qt-version 6.11.2 --qt-dir ~/Qt/6.11.2/macos
```

Opciones: `--trabajo` (`~/qwe`), `--salida`, `--trabajos`, `--arquitecturas` (`arm64`),
`--con-pdf`, `--sin-empaquetar`. Resultado:
`~/qwe/qtwebengine-codecs-6.11.2-macos-arm64.tar.xz` (con `tar`, que conserva los enlaces
simbólicos de los frameworks; un `.zip` los rompería).

### A mano (lo mismo que hacen los scripts)

```bash
# Fuentes: https://download.qt.io/official_releases/qt/6.11/6.11.2/submodules/
#   qtwebengine-everywhere-src-6.11.2.zip (Windows) o .tar.xz (macOS), y md5sums.txt
export NINJAFLAGS=-j8        # Qt WebEngine lo lee al configurar y se lo pasa al ninja de Chromium
<Qt>/bin/qt-cmake -S qtwebengine-everywhere-src-6.11.2 -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DFEATURE_webengine_proprietary_codecs=ON \
    -DFEATURE_qtpdf_build=OFF
    # macOS: además -DCMAKE_OSX_ARCHITECTURES=arm64
grep webengine_proprietary_codecs build/CMakeCache.txt   # QT_FEATURE_..._codecs:INTERNAL=ON
cmake --build build --parallel 8
cmake --install build --prefix salida   # solo el módulo, aparte del Qt base
```

La documentación de Qt usa `qt-configure-module <fuentes> -webengine-proprietary-codecs`,
que es lo mismo: traduce la opción a `-DFEATURE_webengine_proprietary_codecs=ON` y llama a
`qt-cmake`. Con `qt-cmake` directamente se ven mejor el generador y el tipo de compilación.

Cada script deja en la raíz de la salida `mitis-codecs.txt` (versión de Qt, plataforma,
fecha): el workflow lo comprueba antes de usar el archivo.

## Comprobar que funcionan

1. **En el equipo donde se compiló**, sin tocar el workflow: extraer el archivo encima de
   una copia del Qt base (o apuntar `CMAKE_PREFIX_PATH` a un Qt con la salida copiada
   encima), compilar Mitis contra él y abrir `tools/codecs/prueba-codecs.html` en Mitis
   (arrastrarla a la ventana o escribir su ruta en la barra de dirección).
2. La página pregunta al motor por cada formato con `canPlayType()` y
   `MediaSource.isTypeSupported()`:

   | Formato | Sin códecs | Con códecs |
   |---|---|---|
   | `video/mp4; codecs="avc1.42E01E"` (H.264) | `""` / `false` | `"probably"` / `true` |
   | `audio/mp4; codecs="mp4a.40.2"` (AAC-LC) | `""` / `false` | `"probably"` / `true` |
   | VP9, Opus, AV1, MP3 (control) | sí | sí |

   y dice arriba si hay códecs propietarios. Con un `.mp4` H.264/AAC cualquiera (botón
   «Elegir archivo») comprueba además que se ve y se oye: `canPlayType` solo dice lo que
   el motor anuncia.
3. Lo mismo desde las herramientas de desarrollo (F12, con la opción activada en
   Configuración → Desarrollo):
   `document.createElement('video').canPlayType('video/mp4; codecs="avc1.42E01E"')`.
4. En el paquete final (instalador de Windows, `.dmg`): instalarlo en un equipo **sin**
   Qt y repetir la prueba, para confirmar que `windeployqt`/`macdeployqt` copiaron las
   bibliotecas nuevas y no otras. Después, Spotify web y un vídeo de Netflix (con Widevine).

## Publicar

El archivo se sube como recurso de un release de GitHub (límite: 2 GB por archivo; el de
Qt WebEngine en Release debería quedar en unos cientos de MB). El workflow lo descarga con
`gh`, así que sirve un repositorio privado.

**Dónde:** si el repositorio de Mitis es público, un release en él hace públicas esas
bibliotecas con códecs, igual que los instaladores (ver «Patentes y licencias»). Para
tenerlas aparte, usar un repositorio **privado** solo para esto (p. ej. `mitis-qt`):

```bash
gh repo create mitis-qt --private
gh release create qt-codecs-6.11.2 --repo <usuario>/mitis-qt --prerelease \
    --title "Qt WebEngine 6.11.2 con códecs propietarios" \
    --notes "Compilado con tools/codecs/ (docs/codecs.md). Solo para el workflow de Mitis." \
    qtwebengine-codecs-6.11.2-windows-msvc2022_64.7z \
    qtwebengine-codecs-6.11.2-macos-arm64.tar.xz
```

Los dos archivos van en el **mismo release** (los nombres los distinguen). Para el otro
sistema, se puede añadir después: `gh release upload qt-codecs-6.11.2 <archivo> --repo …`.

## Usar en GitHub Actions

El workflow (`.github/workflows/compilar.yml`) se controla con **variables del
repositorio** de Mitis (Settings → Secrets and variables → Actions, o `gh variable set`).
Sin ellas no cambia nada: Qt oficial, sin códecs.

| Nombre | Tipo | Valor | Para qué |
|---|---|---|---|
| `QT_VERSION` | variable | `6.11.2` | Fija el Qt de los tres sistemas a la versión del archivo |
| `QT_CODECS_RELEASE` | variable | `qt-codecs-6.11.2` | Etiqueta del release con los archivos; si está vacía, no se usan |
| `QT_CODECS_REPO` | variable | `<usuario>/mitis-qt` | Repositorio del release (por defecto, el de Mitis) |
| `QT_CODECS_TOKEN` | **secreto** | token de acceso | Solo si el release está en otro repositorio privado: token *fine-grained* con permiso de lectura de *Contents* en él |

```bash
gh variable set QT_VERSION --body 6.11.2
gh variable set QT_CODECS_RELEASE --body qt-codecs-6.11.2
gh variable set QT_CODECS_REPO --body <usuario>/mitis-qt
gh secret set QT_CODECS_TOKEN          # pega el token
```

En Windows y macOS, tras instalar Qt, un paso descarga el archivo de su sistema, comprueba
que su `mitis-codecs.txt` es de la misma versión que el Qt instalado (si no, falla con un
mensaje claro: mezclarlos daría un Mitis que no arranca) y lo copia encima de
`$QT_ROOT_DIR`. `windeployqt` y `macdeployqt` toman de ahí las bibliotecas, así que el
instalador y el `.dmg` salen con códecs. La caché de Qt de `install-qt-action` usa otra
clave cuando hay códecs, para que el Qt modificado no se mezcle con el oficial en la caché.

Para quitar los códecs basta con borrar `QT_CODECS_RELEASE` (y, si se quiere,
`QT_VERSION`).

## Actualizar Qt

Cada versión de Qt (también las de corrección, 6.11.2 → 6.11.3) necesita su propia
compilación de qtwebengine: repetir los pasos con la nueva versión, publicar un release
nuevo y cambiar `QT_VERSION` y `QT_CODECS_RELEASE` a la vez. Hasta entonces, el workflow
sigue con la versión fijada. Las versiones de corrección de Qt WebEngine traen parches de
seguridad de Chromium: no conviene quedarse mucho en una.

## Problemas frecuentes

- **Falta una herramienta al configurar:** el resumen de `qt-cmake` dice cuál
  (`Tool gperf is required`, `Python3 html5lib is missing`…). Instalarla y repetir.
- **Sin memoria** (compilador que muere, `out of memory`, el equipo se congela): repetir
  con menos trabajos (`-Trabajos 4` / `--trabajos 4`); continúa donde se quedó.
- **«Too many open files» en macOS:** macOS deja abrir pocos archivos a la vez (256) y
  Chromium necesita muchos más. El script ya sube el límite; con una versión anterior del
  script, antes de repetir: `ulimit -n 65536` en la misma terminal (o `10240` si lo
  rechaza). Continúa donde se quedó.
- **«clang++: error: unable to execute command: Segmentation fault: 11»** (macOS): el
  compilador se cayó en un archivo. Suele ser pasajero (memoria justa o un fallo puntual,
  más con x86_64 en un Mac con Apple Silicon): repetir el mismo comando, con menos
  trabajos (`--trabajos 4`); continúa donde se quedó. Si se cae **siempre en el mismo
  archivo**, es un fallo de esa versión de Apple clang: actualizar Xcode (Xcode 16.2 trae
  clang 1600.0.26.6) y repetir. Los archivos que se piden adjuntar (`/var/folders/…`) no
  hacen falta.
- **Rutas demasiado largas en Windows:** ruta de trabajo corta y `LongPathsEnabled`.
- **Mitis no arranca con el Qt nuevo** («Cannot mix incompatible Qt library», símbolos que
  faltan): la versión del Qt base y la del archivo no coinciden.
- **La prueba dice que no hay códecs** con el Qt nuevo: comprobar que el Mitis probado
  carga las bibliotecas nuevas (en Windows, que `Qt6WebEngineCore.dll` junto a
  `Mitis.exe` es la compilada, por fecha y tamaño) y que `CMakeCache.txt` de la
  compilación tiene `QT_FEATURE_webengine_proprietary_codecs:INTERNAL=ON`.

## Patentes y licencias

> **Nota para el autor. No es asesoría legal.** Resume lo publicado por las fuentes
> citadas (consultadas en octubre de 2026) para que el autor lo revise, con ayuda
> profesional si hace falta, según los países donde se distribuya Mitis. No saca
> conclusiones sobre si Mitis necesita una licencia.

- **Qt avisa:** «When distributing proprietary codec libraries, you must acquire licenses
  for them» (al distribuir bibliotecas con códecs propietarios hay que obtener sus
  licencias). [Qt WebEngine Features](https://doc.qt.io/qt-6/qtwebengine-features.html#audio-and-video-codecs).
- **Chromium** deja H.264 y AAC fuera de sus compilaciones abiertas («Proprietary … Codecs
  (Limited to Google Chrome)»): Google los incluye en Chrome, no en el código que
  redistribuyen otros. [chromium.org/audio-video](https://www.chromium.org/audio-video/).
  Lo que decodifica es FFmpeg (LGPL) dentro del motor: el código es libre, las patentes
  son otra cuestión.
- **H.264/AVC:** el consorcio de patentes lo gestiona **Via Licensing Alliance (Via LA)**,
  que absorbió a MPEG LA en 2023. Su licencia AVC/H.264 cobra por unidad (decodificador o
  codificador) en productos para PC; según su página, las primeras 100 000 unidades al
  año no pagan y a partir de ahí hay tarifa por unidad con un máximo anual por empresa.
  [via-la.com — AVC/H.264](https://via-la.com/licensing-programs/avc-h-264/).
  Las patentes van caducando por países y fechas distintas; no se ha comprobado cuáles
  siguen vigentes en cada país.
- **AAC:** también en Via LA (programa AAC, heredado de Via Licensing). Su tabla publicada
  cobra por unidad **desde la primera** (0,98 USD hasta 500 000 unidades, bajando con el
  volumen); puede haber además cuotas fijas: revisar la página y las condiciones completas.
  [via-la.com — AAC](https://via-la.com/licensing-programs/aac/).
- **Contraste:** Firefox reproduce H.264 con **OpenH264**, un binario que compila y
  distribuye Cisco, quien paga las regalías de ese binario; otros navegadores usan los
  decodificadores del sistema operativo (Windows Media Foundation, VideoToolbox en macOS),
  cuya licencia cubre el fabricante del sistema. Qt WebEngine con
  `webengine_proprietary_codecs` no hace ninguna de las dos cosas: lleva el decodificador
  dentro de sus bibliotecas.
- **MP3** dejó de estar sujeto a licencia: Fraunhofer y Technicolor cerraron su programa en
  2017. Chromium ya lo incluye en sus compilaciones abiertas.
- **LGPL de Qt (tarea aparte del PLAN):** al distribuir un Qt WebEngine compilado por
  Mitis, las obligaciones de la LGPL se aplican igual que con el oficial (fuentes de esa
  versión de Qt, poder sustituir las bibliotecas). Conviene guardar junto a cada release
  las opciones de compilación (los scripts de `tools/codecs/`).

Preguntas para revisar: en qué países se distribuirá Mitis y si allí siguen vigentes
patentes de H.264 y AAC; si la distribución gratuita de un navegador cuenta como «unidad»
en esas licencias; si conviene mantener dos variantes (con y sin códecs) o limitar dónde
se ofrece la descarga con códecs.

## Sin verificar

Escrito sin poder compilar ni ejecutar en este entorno (servidor Linux, sin Windows ni
macOS, y sin descargar las fuentes de Qt):

- Los scripts no se han ejecutado; el de PowerShell ni siquiera se ha analizado (no hay
  `pwsh` aquí). El de macOS pasa `bash -n`.
- Requisitos de Xcode/SDK de macOS para Chromium 140, tiempos, disco y RAM: estimaciones.
- Que `-G Ninja -DCMAKE_BUILD_TYPE=Release` con `qt-cmake` compile solo la versión Release
  contra el Qt oficial de Windows (que trae Debug y Release).
- Que `cmake --install --prefix` deje exactamente los archivos que `windeployqt` y
  `macdeployqt` esperan al extraerlos encima del Qt de `install-qt-action`.
- La clave de caché `QT_FEATURE_webengine_proprietary_codecs:INTERNAL` en `CMakeCache.txt`
  (es como Qt guarda sus opciones; si el nombre fuera otro, el script se detendría antes
  de compilar y bastaría con ajustar la comprobación).

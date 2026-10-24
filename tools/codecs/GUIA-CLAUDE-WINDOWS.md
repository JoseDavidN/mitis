# Guía para Claude Code en Windows: Qt WebEngine con códecs propietarios

Esta guía es para una sesión de **Claude Code en un equipo Windows** con el repositorio de
Mitis clonado. Objetivo: preparar el entorno, compilar Qt WebEngine **6.11.2** con H.264 y
AAC, publicarlo para que GitHub Actions genere el instalador de Mitis con códecs, y dejar
lista la lista de pruebas del motor.

Para empezar, en la sesión de Claude Code en Windows:

> Lee `tools/codecs/GUIA-CLAUDE-WINDOWS.md` y sigue sus pasos. Empieza por la fase 0.

Contexto completo (por qué, requisitos, patentes): `docs/codecs.md`.

**Por qué 6.11.2 y no 6.11.3:** el workflow usa Qt 6.11.3 sin códecs, pero el código
fuente de Qt WebEngine 6.11.3 no se ha publicado (comprobado el 2026-10-23: ni en
`download.qt.io` ni como etiqueta `v6.11.3` en code.qt.io; Qt solo la da compilada). Sin
código no se puede compilar con códecs, así que se usa **6.11.2**, la última con código, y
al terminar se fija `QT_VERSION=6.11.2` en el repositorio (fase 7) para que el workflow
use esa misma versión. Cuando se publique el código de una versión más nueva, repetir con
ella (ver «Actualizar Qt» en `docs/codecs.md`).

---

## Reglas para Claude Code

- Responde y escribe en **español**.
- **Pregunta antes de** instalar programas, ejecutar algo como administrador, cambiar el
  registro o el antivirus, crear repositorios o releases en GitHub, o definir variables y
  secretos del repositorio. Explica qué vas a hacer y espera el «sí».
- **No modifiques el código de Mitis** ni hagas commits o push. Si un script de
  `tools/codecs/` falla por un error suyo, propón el arreglo y espera; el autor lo aplica
  en el repositorio principal.
- **No pidas ni escribas tokens o contraseñas** en la conversación: el usuario los
  introduce él mismo en los comandos interactivos (`gh auth login`, `gh secret set`).
- Comprueba cada fase antes de pasar a la siguiente y di el resultado (lo que salió, no
  lo que se esperaba).
- La compilación dura horas: lánzala en segundo plano con un registro en archivo y
  revísalo de vez en cuando; no la vigiles con esperas cortas continuas.
- Al terminar (o si algo se atasca), deja un resumen en `C:\qwe\RESUMEN.md`: qué se hizo,
  versiones, rutas, errores y lo que falta. Ese resumen es el que el autor lleva de vuelta.

## Datos fijos

| Dato | Valor |
|---|---|
| Versión de Qt | `6.11.2` (la última con el código publicado; el workflow la usará con `QT_VERSION=6.11.2`) |
| Compilador | Visual Studio 2022, `win64_msvc2022_64` |
| Qt base | `C:\Qt\6.11.2\msvc2022_64` |
| Carpeta de trabajo | `C:\qwe` (ruta corta: Chromium crea rutas muy largas) |
| Paquete resultante | `C:\qwe\qtwebengine-codecs-6.11.2-windows-msvc2022_64.7z` |
| aqtinstall | desde git: `git+https://github.com/miurahr/aqtinstall.git@076e1659807d0b362a3ed684d54c2e9c775eb9c7` (la publicada no instala Qt 6.11+ en Windows) |
| Release | `qt-codecs-6.11.2` |

---

## Fase 0 — Comprobar el equipo (sin instalar nada)

1. RAM, núcleos y disco libre en `C:`:
   ```powershell
   Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory, NumberOfLogicalProcessors
   Get-PSDrive C | Select-Object Free
   ```
   Mínimo: **16 GB de RAM** (mejor 32) y **100 GB libres** (mejor en SSD). Si no llega,
   avisa y para.
2. Qué hay ya instalado (sin instalar nada todavía): Visual Studio 2022 y su carga de C++,
   SDK de Windows, y las herramientas:
   ```powershell
   & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
   Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\Include" | Select-Object Name
   foreach ($c in "cmake","ninja","python","node","gperf","win_bison","win_flex","7z","git","gh","choco","pwsh") {
       "{0,-10} {1}" -f $c, ((Get-Command $c -ErrorAction SilentlyContinue).Source)
   }
   node -p "process.arch + ' ' + process.version"
   python -c "import html5lib; print('html5lib ok')"
   ```
3. Informa en una tabla: qué está, qué falta y qué versión hay. Requisitos:
   - Visual Studio 2022 (MSVC 14.36 o posterior) con «Desarrollo para el escritorio con C++».
   - SDK de Windows **10.0.26100.0 o posterior** (carpeta en `Windows Kits\10\Include`).
   - **ATL y MFC de C++** (`atldef.h` en `<VC\Tools\MSVC\versión>\atlmfc\include`): Chromium
     los necesita y no vienen con la carga de C++ por defecto.
   - CMake ≥ 3.19, Ninja, Python ≥ 3.8 con `html5lib`, Node.js ≥ 20 **x64**, gperf,
     winflexbison (`win_bison`, `win_flex`), 7-Zip (`7z` en el `PATH`), git, gh, pwsh.

## Fase 1 — Instalar lo que falte (pide permiso antes)

- Visual Studio 2022 o el SDK de Windows 11: se instalan con el instalador de Visual
  Studio (Modificar → «Desarrollo para el escritorio con C++» y, en Componentes
  individuales, «SDK de Windows 11 (10.0.26100.0)» y «ATL de C++ para las herramientas de
  compilación v143 más recientes (x86 y x64)», más el de MFC). Explica al usuario cómo hacerlo: es
  una interfaz gráfica.
- El resto, en una consola de **administrador** (el usuario la abre y ejecuta, o lo
  aprueba):
  ```powershell
  choco install ninja gperf winflexbison3 7zip nodejs-lts python git gh powershell-core -y
  python -m pip install html5lib
  ```
  Si no hay Chocolatey, propón `winget` para lo que exista allí (p. ej.
  `winget install Ninja-build.Ninja OpenJS.NodeJS.LTS Python.Python.3.12 GitHub.cli 7zip.7zip Microsoft.PowerShell`)
  y Chocolatey solo para `gperf` y `winflexbison3`.
- Abre una consola nueva (para que el `PATH` se actualice) y repite la comprobación de la
  fase 0. 7-Zip suele necesitar añadir `C:\Program Files\7-Zip` al `PATH`.

## Fase 2 — Ajustes del sistema (administrador, pide permiso)

1. Rutas largas:
   ```powershell
   reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t REG_DWORD /d 1 /f
   ```
2. Crear `C:\qwe` y excluirla de Microsoft Defender (si no, la compilación va mucho más
   lenta):
   ```powershell
   New-Item -ItemType Directory -Force C:\qwe | Out-Null
   Add-MpPreference -ExclusionPath C:\qwe
   ```
   Si el equipo usa otro antivirus, explica al usuario cómo añadir la exclusión.

## Fase 3 — Qt base 6.11.2 (sin Qt WebEngine)

```powershell
python -m pip install "git+https://github.com/miurahr/aqtinstall.git@076e1659807d0b362a3ed684d54c2e9c775eb9c7"
python -m aqt install-qt windows desktop 6.11.2 win64_msvc2022_64 -m qtwebchannel qtpositioning -O C:\Qt
```

Comprobar:
```powershell
& C:\Qt\6.11.2\msvc2022_64\bin\qmake.exe -query QT_VERSION     # debe decir 6.11.2
Test-Path C:\Qt\6.11.2\msvc2022_64\bin\qt-cmake.bat
Test-Path C:\Qt\6.11.2\msvc2022_64\lib\cmake\Qt6WebChannel
Test-Path C:\Qt\6.11.2\msvc2022_64\lib\cmake\Qt6WebEngineCore   # debe ser False (sin WebEngine)
```
Si `C:\Qt\6.11.2` ya existía con Qt WebEngine dentro, avisa: el script funciona, pero
conviene una instalación limpia para que no se mezclen cabeceras.

## Fase 4 — Compilar (horas)

El script necesita el entorno de Visual Studio x64 (`VSCMD_ARG_TGT_ARCH=x64`). Desde
Claude Code no hay una «x64 Native Tools Command Prompt», así que se carga con
`vcvars64.bat` dentro del mismo comando. Lanzarlo **en segundo plano** con registro:

```powershell
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
$repo = (Get-Location).Path   # raíz del repositorio de Mitis
cmd /c "call `"$vs\VC\Auxiliary\Build\vcvars64.bat`" && pwsh -NoProfile -File `"$repo\tools\codecs\compilar-windows.ps1`" -QtVersion 6.11.2 -QtDir C:\Qt\6.11.2\msvc2022_64 > C:\qwe\compilacion.log 2>&1"
```

- Antes de compilar, el script comprueba herramientas, descarga las fuentes
  (`qtwebengine-everywhere-src-6.11.2.zip`, con su MD5), configura con
  `-DFEATURE_webengine_proprietary_codecs=ON` y **verifica en `CMakeCache.txt` que la
  opción quedó activada**. Revisa el registro tras la configuración (los primeros minutos):
  si algo falta o la opción no quedó activa, para y avisa.
- Trabajos en paralelo: por defecto según núcleos y RAM (unos 3 GB por trabajo). Si se
  queda sin memoria (el compilador muere, `out of memory`, el equipo se congela), vuelve a
  lanzar el mismo comando con `-Trabajos 4`: **continúa donde se quedó**. Lo mismo tras un
  corte o un reinicio.
- Para seguir el avance: las últimas líneas de `C:\qwe\compilacion.log` (Ninja muestra
  `[actual/total]`). Revísalo cada 20–30 minutos, no más a menudo.
- Este script **no se ha ejecutado nunca** (se escribió en Linux, sin `pwsh`). Si falla por
  un error del propio script (no por una herramienta que falte), explica el error, propón
  el cambio y espera.

## Fase 5 — Comprobar el resultado

```powershell
Get-Item C:\qwe\qtwebengine-codecs-6.11.2-windows-msvc2022_64.7z | Select-Object Name, Length
Get-Content C:\qwe\salida\mitis-codecs.txt          # debe incluir qt=6.11.2
Select-String -Path C:\qwe\build\CMakeCache.txt -Pattern "webengine_proprietary_codecs"
Test-Path C:\qwe\salida\bin\Qt6WebEngineCore.dll
Test-Path C:\qwe\salida\bin\QtWebEngineProcess.exe
```
(Si las rutas de `build` o `salida` del script son otras, búscalas en el registro.) El
`.7z` debería pesar unos cientos de MB. Anota tamaño y fecha en el resumen.

## Fase 6 — Publicar el paquete (pide permiso; el usuario se autentica)

1. El usuario inicia sesión en GitHub: `gh auth login` (lo hace él, de forma interactiva).
2. Pregunta el nombre del repositorio privado para los paquetes (por defecto `mitis-qt`) y
   créalo solo con su «sí»:
   ```powershell
   gh repo create mitis-qt --private
   gh release create qt-codecs-6.11.2 --repo <usuario>/mitis-qt --prerelease `
     --title "Qt WebEngine 6.11.2 con códecs propietarios" `
     --notes "Compilado con tools/codecs/compilar-windows.ps1 (docs/codecs.md). Solo para el workflow de Mitis." `
     C:\qwe\qtwebengine-codecs-6.11.2-windows-msvc2022_64.7z
   ```
   Repositorio privado a propósito: así las bibliotecas con H.264/AAC no quedan públicas
   (ver «Patentes y licencias» en `docs/codecs.md`).

## Fase 7 — Que GitHub Actions lo use (pide permiso; el token lo pone el usuario)

En el repositorio de Mitis (no en `mitis-qt`):
```powershell
gh variable set QT_VERSION --body 6.11.2
gh variable set QT_CODECS_RELEASE --body qt-codecs-6.11.2
gh variable set QT_CODECS_REPO --body <usuario>/mitis-qt
gh secret set QT_CODECS_TOKEN
```
El token lo crea el usuario en GitHub (Settings → Developer settings → Fine-grained
tokens): acceso solo a `mitis-qt`, permiso **Contents: Read-only**. Lo pega él en el
último comando; no lo escribas tú.

Después, el usuario lanza el workflow (un push o «Run workflow» en Actions). Antes de
usar el paquete, el workflow comprueba que su `mitis-codecs.txt` es de la misma versión
que el Qt instalado. Sigue el run con `gh run watch` y, si falla, enseña el error del paso.

## Fase 8 — Pruebas del motor (las hace el usuario; tú preparas la lista y anotas)

Con el `MitisInstalador.exe` de ese run instalado:

1. **Códecs:** abrir `tools\codecs\prueba-codecs.html` en Mitis (arrastrarla a la
   ventana). H.264 (`avc1.42E01E`) y AAC (`mp4a.40.2`) deben salir `probably` / `true`.
   Con «Elegir archivo», un `.mp4` H.264/AAC debe verse y oírse.
2. **Widevine:** Configuración → Acerca de Mitis → «Contenido protegido» debe estar
   disponible (Mitis lo toma de Google Chrome instalado).
3. **Servicios:** Apple Music y Spotify web (deberían sonar ya); HBO Max (antes «Código de
   error: 1k-0003»: si sigue igual con códecs, lo más probable es la firma VMP de
   Widevine, que Qt WebEngine no tiene); Netflix si hay cuenta.
4. **Vidrio (experimental):** Configuración → Apariencia → «Transparencia con desenfoque»:
   ¿el campo de dirección deja ver la página difuminada, o se ve transparente sin
   difuminar, o gris?
5. De paso, lo pendiente de Windows en `docs/PLAN.md`: redimensionar la ventana sin
   parpadeos, notificaciones del sistema (WhatsApp Web, Gmail), aviso de micrófono y
   cámara en la barra de tareas (Meet), el instalador con Mitis ya instalado
   (desinstalar/actualizar).

Anota cada resultado en `C:\qwe\RESUMEN.md` (qué se probó, qué salió, capturas si hay
errores). Ese archivo es lo que el autor lleva de vuelta a la sesión de desarrollo.

---

## Problemas frecuentes

| Síntoma | Qué hacer |
|---|---|
| `Tool gperf is required`, `Python3 html5lib is missing`… al configurar | Instalar la herramienta que dice y relanzar |
| El compilador muere, `out of memory`, el equipo se congela | Relanzar con `-Trabajos 4` (continúa) |
| Errores de rutas largas | Fase 2 hecha y carpeta `C:\qwe` |
| `Cannot mix incompatible Qt library` al arrancar Mitis | La versión del Qt base y la del paquete no coinciden |
| La prueba dice que no hay códecs | Comprobar que `Qt6WebEngineCore.dll` junto a `Mitis.exe` es la compilada (fecha y tamaño) y que `CMakeCache.txt` tiene la opción en `ON` |
| `aqt` no encuentra Qt 6.11 | Usar el aqtinstall de git de «Datos fijos», no el de PyPI |

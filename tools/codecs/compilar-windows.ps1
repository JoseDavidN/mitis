# Compila Qt WebEngine con códecs propietarios (H.264, AAC) para Windows
# contra un Qt ya instalado, y lo deja en una carpeta y en un .7z listo para
# extraer encima de ese Qt (lo que hace el workflow). Guía: docs/codecs.md.
#
# Solo compila el módulo qtwebengine: el resto de Qt es el oficial. Tarda
# horas (más de las 6 h que da un runner de GitHub), por eso va en un equipo propio.
#
# Desde una consola «x64 Native Tools Command Prompt for VS 2022» (pwsh):
#   pwsh tools/codecs/compilar-windows.ps1 -QtVersion 6.11.2 -QtDir C:\Qt\6.11.2\msvc2022_64
#
# Requisitos (docs/codecs.md): VS 2022 (MSVC ≥ 14.36), SDK de Windows 11
# ≥ 10.0.26100, CMake ≥ 3.19, Ninja, Python ≥ 3.8 con html5lib, Node.js ≥ 20
# (64 bits), gperf, bison y flex (winflexbison), 7-Zip.
param(
    # Exactamente la misma versión que el Qt de -QtDir: Qt WebEngine usa API
    # privada de Qt y no carga con otra versión
    [string] $QtVersion = "6.11.2",
    # Qt base (msvc2022_64) con qtwebchannel y qtpositioning; mejor SIN
    # qtwebengine instalado, para que no se mezclen sus cabeceras con las nuevas
    [string] $QtDir = "C:\Qt\$QtVersion\msvc2022_64",
    # Ruta corta: Chromium genera rutas muy largas y Windows limita a 260 caracteres
    [string] $Trabajo = "C:\qwe",
    # Donde se instala el módulo (solo sus archivos, con la estructura de Qt)
    [string] $Salida = "",
    # Trabajos en paralelo; 0 = según núcleos y RAM (unos 3 GB por trabajo)
    [int] $Trabajos = 0,
    # QtPdf viene en las mismas fuentes; Mitis no lo usa y alarga la compilación
    [switch] $ConPdf,
    # Solo compilar e instalar, sin crear el .7z
    [switch] $SinEmpaquetar
)
$ErrorActionPreference = "Stop"
if (-not $Salida) { $Salida = Join-Path $Trabajo "salida" }

function Comprobar($nombre, $comando, $pista) {
    if (-not (Get-Command $comando -ErrorAction SilentlyContinue)) {
        throw "Falta $nombre ($comando). $pista"
    }
}

# --- Comprobaciones antes de empezar (mejor fallar ahora que a las 3 horas) ---

if ($env:VSCMD_ARG_TGT_ARCH -ne "x64") {
    throw "Abre una consola «x64 Native Tools Command Prompt for VS 2022» (VSCMD_ARG_TGT_ARCH=x64)"
}
Comprobar "el compilador de Visual Studio" "cl.exe" "Usa la consola de VS x64."
Comprobar "CMake" "cmake" "Viene con Visual Studio o: winget install Kitware.CMake"
Comprobar "Ninja" "ninja" "choco install ninja"
Comprobar "Python 3" "python" "winget install Python.Python.3.12"
Comprobar "Node.js (64 bits, ≥ 20)" "node" "winget install OpenJS.NodeJS.LTS"
Comprobar "gperf" "gperf" "choco install gperf"
# CMake acepta bison/flex con sus nombres de winflexbison (win_bison, win_flex)
if (-not ((Get-Command bison -ErrorAction SilentlyContinue) -or (Get-Command win_bison -ErrorAction SilentlyContinue))) {
    throw "Falta bison. choco install winflexbison3"
}
if (-not ((Get-Command flex -ErrorAction SilentlyContinue) -or (Get-Command win_flex -ErrorAction SilentlyContinue))) {
    throw "Falta flex. choco install winflexbison3"
}
if (-not $SinEmpaquetar) { Comprobar "7-Zip" "7z" "choco install 7zip (y su carpeta en el PATH)" }

& python -c "import html5lib" 2>$null
if ($LASTEXITCODE -ne 0) { throw "Falta el módulo html5lib de Python: python -m pip install html5lib" }

$nodeArch = (& node -p "process.arch").Trim()
$nodeMayor = [int](& node -p "process.versions.node.split('.')[0]")
if ($nodeArch -ne "x64" -or $nodeMayor -lt 20) { throw "Hace falta Node.js ≥ 20 de 64 bits (hay $nodeMayor, $nodeArch)" }

$qtCmake = Join-Path $QtDir "bin\qt-cmake.bat"
$qmake = Join-Path $QtDir "bin\qmake.exe"
if (-not (Test-Path $qtCmake)) { throw "No hay Qt en $QtDir (falta bin\qt-cmake.bat)" }
$qtInstalado = (& $qmake -query QT_VERSION).Trim()
if ($qtInstalado -ne $QtVersion) { throw "El Qt de $QtDir es $qtInstalado, no ${QtVersion}: deben coincidir" }
if (Test-Path (Join-Path $QtDir "bin\Qt6WebEngineCore.dll")) {
    Write-Warning "$QtDir ya tiene Qt WebEngine: mejor un Qt base sin él (docs/codecs.md, «Qt base»)"
}

$sdk = $env:WindowsSDKVersion -replace '\\', ''
if ($sdk -and ([version]$sdk).Build -lt 26100) {
    throw "SDK de Windows ${sdk}: Qt WebEngine $QtVersion pide 10.0.26100 o posterior (instalador de Visual Studio)"
}

# Chromium usa ATL (atldef.h al compilar, atls.lib al enlazar Qt6WebEngineCore.dll),
# que no viene con la carga de C++ por defecto. Las cabeceras pueden estar sin la
# biblioteca x64 (p. ej. solo la versión Spectre o la de ARM64): se miran las dos,
# porque sin atls.lib falla al final, tras horas de compilación
if ($env:VCToolsInstallDir) {
    foreach ($archivo in "atlmfc\include\atldef.h", "atlmfc\lib\x64\atls.lib") {
        if (-not (Test-Path (Join-Path $env:VCToolsInstallDir $archivo))) {
            throw "Falta ATL de C++ para x64 en Visual Studio ($archivo): instálalo con el instalador de Visual Studio («ATL de C++ para las herramientas de compilación v143 más recientes (x86 y x64)», Microsoft.VisualStudio.Component.VC.ATL, y VC.ATLMFC; docs/codecs.md)"
        }
    }
}

# Rutas largas: aunque el trabajo vaya en una ruta corta, conviene tenerlas activas
$largas = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -ErrorAction SilentlyContinue).LongPathsEnabled
if ($largas -ne 1) { Write-Warning "Rutas largas desactivadas en Windows (LongPathsEnabled); si falla por rutas, actívalas" }

if ($Trabajos -le 0) {
    $nucleos = [Environment]::ProcessorCount
    $ramGB = [math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    # Cada trabajo de Chromium (compilación «jumbo») puede pasar de 2 GB
    $Trabajos = [math]::Max(1, [math]::Min($nucleos, [math]::Floor($ramGB / 3)))
}
Write-Host "Qt $QtVersion en $QtDir · $Trabajos trabajos en paralelo · trabajo en $Trabajo"

# --- Fuentes ---

New-Item -ItemType Directory -Force -Path $Trabajo | Out-Null
$serie = ($QtVersion -split '\.')[0..1] -join '.'
$nombre = "qtwebengine-everywhere-src-$QtVersion"
$base = "https://download.qt.io/official_releases/qt/$serie/$QtVersion/submodules"
$zip = Join-Path $Trabajo "$nombre.zip"
$fuentes = Join-Path $Trabajo $nombre

if (-not (Test-Path $fuentes)) {
    if (-not (Test-Path $zip)) {
        Write-Host "Descargando $nombre.zip (cientos de MB)…"
        # curl.exe (Windows 10+) es mucho más rápido que Invoke-WebRequest con archivos grandes
        & curl.exe -L --fail -o $zip "$base/$nombre.zip"
        if ($LASTEXITCODE -ne 0) { throw "No se pudo descargar $base/$nombre.zip" }
    }
    # Integridad de la descarga con la suma que publica Qt
    $sumas = (& curl.exe -sL --fail "$base/md5sums.txt") -split "`n"
    $esperada = ($sumas | Where-Object { $_ -match "\s$nombre\.zip\s*$" } | Select-Object -First 1) -replace '\s.*$', ''
    $real = (Get-FileHash $zip -Algorithm MD5).Hash.ToLower()
    if (-not $esperada -or $esperada.Trim() -ne $real) { throw "La suma MD5 de $zip no coincide ($real ≠ $esperada): bórralo y repite" }

    Write-Host "Extrayendo (tarda: decenas de miles de archivos)…"
    # tar.exe de Windows (bsdtar) extrae ZIP mucho más rápido que Expand-Archive
    & tar.exe -xf $zip -C $Trabajo
    if ($LASTEXITCODE -ne 0) { throw "No se pudo extraer $zip" }
}

# --- Configurar ---

$build = Join-Path $Trabajo "build"
New-Item -ItemType Directory -Force -Path $build | Out-Null
# Qt WebEngine lee NINJAFLAGS al configurar y se lo pasa al ninja de Chromium
$env:NINJAFLAGS = "-j$Trabajos"
$pdf = if ($ConPdf) { "ON" } else { "OFF" }

Push-Location $build
try {
    & $qtCmake -S $fuentes -B . -G Ninja `
        -DCMAKE_BUILD_TYPE=Release `
        -DFEATURE_webengine_proprietary_codecs=ON `
        "-DFEATURE_qtpdf_build=$pdf"
    if ($LASTEXITCODE -ne 0) { throw "La configuración falló: revisa el resumen de arriba (herramientas que falten)" }

    # Si la opción no llegó a aplicarse, horas de compilación no servirían de nada
    if (-not (Select-String -Path CMakeCache.txt -Pattern '^QT_FEATURE_webengine_proprietary_codecs:INTERNAL=(ON|1)$' -Quiet)) {
        throw "La configuración no activó webengine_proprietary_codecs (mira CMakeCache.txt)"
    }

    # --- Compilar e instalar ---

    $inicio = Get-Date
    & cmake --build . --parallel $Trabajos
    if ($LASTEXITCODE -ne 0) { throw "La compilación falló (si es por memoria, repite con -Trabajos menor: continúa donde se quedó)" }
    Write-Host ("Compilado en {0:hh\:mm}" -f ((Get-Date) - $inicio))

    # Instala solo el módulo en $Salida, con la estructura de Qt (bin, lib,
    # resources, translations, qml…), para extraerlo encima de un Qt igual
    if (Test-Path $Salida) { Remove-Item -Recurse -Force $Salida }
    & cmake --install . --prefix $Salida
    if ($LASTEXITCODE -ne 0) { throw "La instalación falló" }
} finally {
    Pop-Location
}

# Marca que el workflow comprueba antes de usar el archivo (UTF-8 sin BOM:
# Windows PowerShell 5 lo pondría con Set-Content y estropearía la primera línea)
[IO.File]::WriteAllLines((Join-Path $Salida "mitis-codecs.txt"), [string[]]@(
    "qt=$QtVersion"
    "plataforma=windows-msvc2022_64"
    "codecs=propietarios"
    "fecha=$(Get-Date -Format yyyy-MM-dd)"
))

if ($SinEmpaquetar) {
    Write-Host "Listo: $Salida"
    exit 0
}

# --- Empaquetar ---

$archivo = Join-Path $Trabajo "qtwebengine-codecs-$QtVersion-windows-msvc2022_64.7z"
if (Test-Path $archivo) { Remove-Item $archivo }
# Sin .pdb: símbolos de depuración que no hacen falta para compilar ni distribuir
& 7z a -t7z -mx=7 $archivo (Join-Path $Salida "*") "-xr!*.pdb"
if ($LASTEXITCODE -ne 0) { throw "7-Zip falló" }
$mb = [math]::Round((Get-Item $archivo).Length / 1MB)
Write-Host "Listo: $archivo ($mb MB). Publicarlo: docs/codecs.md, «Publicar»."

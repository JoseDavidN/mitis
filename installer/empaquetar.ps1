# Crea el instalador de Mitis para Windows: Mitis con todo lo que necesita
# (Qt, Qt WebEngine y el runtime de Visual C++) en un ZIP, pegado al final
# del instalador (MitisInstalador.exe) con su desplazamiento y una marca:
#
#   [instalador][ZIP][desplazamiento del ZIP: 8 bytes][«MITISPAQ»]
#
# Lo usa GitHub Actions. En local, desde una consola de Visual Studio
# (x64 Native Tools) con Qt en el PATH, tras compilar Mitis y el instalador:
#   pwsh installer/empaquetar.ps1 -Mitis build/bin/Mitis.exe `
#        -Instalador build-instalador/MitisInstalador.exe -Salida Mitis-Instalador.exe
param(
    [Parameter(Mandatory)] [string] $Mitis,
    [Parameter(Mandatory)] [string] $Instalador,
    [Parameter(Mandatory)] [string] $Salida,
    [string] $Qml = (Join-Path $PSScriptRoot "..\qml")
)
$ErrorActionPreference = "Stop"

$temporal = Join-Path ([IO.Path]::GetTempPath()) ("mitis-paquete-" + [Guid]::NewGuid())
$carpeta = Join-Path $temporal "Mitis"
New-Item -ItemType Directory -Path $carpeta | Out-Null

try {
    # Mitis y las bibliotecas de Qt que usa (Qt WebEngine incluido: su
    # proceso, recursos e idiomas)
    Copy-Item $Mitis $carpeta
    & windeployqt --release --qmldir $Qml --no-compiler-runtime (Join-Path $carpeta (Split-Path $Mitis -Leaf))
    if ($LASTEXITCODE -ne 0) { throw "windeployqt falló" }

    # Runtime de Visual C++ junto al ejecutable (despliegue local, sin
    # instalar vc_redist): VCToolsRedistDir lo define la consola de Visual Studio
    if (-not $env:VCToolsRedistDir) { throw "Falta VCToolsRedistDir: usa una consola de Visual Studio" }
    $runtime = Get-ChildItem (Join-Path $env:VCToolsRedistDir "x64") -Directory -Filter "Microsoft.VC*.CRT" | Select-Object -First 1
    if (-not $runtime) { throw "No se encontró el runtime de Visual C++ en $env:VCToolsRedistDir" }
    Copy-Item (Join-Path $runtime.FullName "*.dll") $carpeta

    # Licencias: la de Mitis (GPL-3.0) y las de terceros (LGPL de Qt…)
    $raiz = Join-Path $PSScriptRoot ".."
    Copy-Item (Join-Path $raiz "LICENSE") $carpeta
    Copy-Item (Join-Path $raiz "licencias") $carpeta -Recurse
    # Diccionario del corrector, junto a Mitis.exe (main.cpp, setupDictionaries)
    $diccionarios = Join-Path $carpeta "qtwebengine_dictionaries"
    New-Item -ItemType Directory -Path $diccionarios -Force | Out-Null
    Copy-Item (Join-Path $raiz "assets\dictionaries\es.bdic") $diccionarios

    # Comprimido con 7-Zip (en los equipos de GitHub Actions) o, si no está,
    # con PowerShell (más lento)
    $zip = Join-Path $temporal "Mitis.zip"
    if (Get-Command 7z -ErrorAction SilentlyContinue) {
        & 7z a -tzip -mx=7 $zip (Join-Path $carpeta "*") | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "7z falló" }
    } else {
        Compress-Archive -Path (Join-Path $carpeta "*") -DestinationPath $zip -CompressionLevel Optimal
    }

    # Instalador + ZIP + pie
    Copy-Item $Instalador $Salida -Force
    $inicio = (Get-Item $Salida).Length
    $flujo = [IO.File]::Open((Resolve-Path $Salida), [IO.FileMode]::Append)
    try {
        $entrada = [IO.File]::OpenRead($zip)
        try { $entrada.CopyTo($flujo) } finally { $entrada.Dispose() }
        [byte[]] $pie = [BitConverter]::GetBytes([Int64]$inicio) + [Text.Encoding]::ASCII.GetBytes("MITISPAQ")
        $flujo.Write($pie, 0, $pie.Length)
    } finally {
        $flujo.Dispose()
    }
    $mb = [Math]::Round((Get-Item $Salida).Length / 1MB)
    Write-Host "Instalador creado: $Salida ($mb MB)"
} finally {
    Remove-Item -Recurse -Force $temporal -ErrorAction SilentlyContinue
}

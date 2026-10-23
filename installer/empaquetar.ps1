# Prepara lo que va en el servidor de descargas de Mitis (MITIS_SERVIDOR):
#
#   Mitis-<versión>-windows.zip   Mitis con todo lo que necesita (Qt, Qt
#                                 WebEngine y el runtime de Visual C++)
#   MitisInstalador.exe           el instalador (sin Mitis dentro: lo descarga)
#   version.txt                   la versión, los nombres y sus SHA-256
#                                 (lo lee el instalador y Mitis para actualizar)
#
# Se suben los tres a la carpeta del servidor, reemplazando los anteriores.
# Lo usa GitHub Actions. En local, desde una consola de Visual Studio
# (x64 Native Tools) con Qt en el PATH, tras compilar Mitis y el instalador:
#   pwsh installer/empaquetar.ps1 -Mitis build/bin/Mitis.exe `
#        -Instalador build-instalador/MitisInstalador.exe -Version 0.8.1-beta -Salida servidor
param(
    [Parameter(Mandatory)] [string] $Mitis,
    [Parameter(Mandatory)] [string] $Instalador,
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [string] $Salida,
    [string] $Qml = (Join-Path $PSScriptRoot "..\qml")
)
$ErrorActionPreference = "Stop"

$temporal = Join-Path ([IO.Path]::GetTempPath()) ("mitis-paquete-" + [Guid]::NewGuid())
$carpeta = Join-Path $temporal "Mitis"
New-Item -ItemType Directory -Path $carpeta | Out-Null
New-Item -ItemType Directory -Path $Salida -Force | Out-Null

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

    # Comprimido con 7-Zip (en los equipos de GitHub Actions) o, si no está,
    # con PowerShell (más lento)
    $paquete = "Mitis-$Version-windows.zip"
    $zip = Join-Path $Salida $paquete
    Remove-Item $zip -ErrorAction SilentlyContinue
    if (Get-Command 7z -ErrorAction SilentlyContinue) {
        & 7z a -tzip -mx=7 $zip (Join-Path $carpeta "*") | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "7z falló" }
    } else {
        Compress-Archive -Path (Join-Path $carpeta "*") -DestinationPath $zip -CompressionLevel Optimal
    }

    $instaladorSalida = Join-Path $Salida "MitisInstalador.exe"
    Copy-Item $Instalador $instaladorSalida -Force

    # version.txt: una clave por línea, en UTF-8 sin BOM y con saltos \n
    $lineas = @(
        "version=$Version",
        "paquete=$paquete",
        "sha256=$((Get-FileHash $zip -Algorithm SHA256).Hash.ToLower())",
        "instalador=MitisInstalador.exe",
        "instalador_sha256=$((Get-FileHash $instaladorSalida -Algorithm SHA256).Hash.ToLower())"
    )
    [IO.File]::WriteAllText((Join-Path (Resolve-Path $Salida) "version.txt"), ($lineas -join "`n") + "`n",
                            (New-Object Text.UTF8Encoding $false))

    $mb = [Math]::Round((Get-Item $zip).Length / 1MB)
    Write-Host "Listo en ${Salida}: $paquete ($mb MB), MitisInstalador.exe y version.txt"
} finally {
    Remove-Item -Recurse -Force $temporal -ErrorAction SilentlyContinue
}

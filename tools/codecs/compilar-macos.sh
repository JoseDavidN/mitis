#!/usr/bin/env bash
# Compila Qt WebEngine con códecs propietarios (H.264, AAC) para macOS contra
# un Qt ya instalado, y lo deja en una carpeta y en un .tar.xz listo para
# extraer encima de ese Qt (lo que hace el workflow). Guía: docs/codecs.md.
#
# Solo compila el módulo qtwebengine: el resto de Qt es el oficial. Tarda
# horas (más de las 6 h que da un runner de GitHub), por eso va en un equipo propio.
#
#   tools/codecs/compilar-macos.sh --qt-version 6.11.2 --qt-dir ~/Qt/6.11.2/macos
#
# Requisitos (docs/codecs.md): Xcode con su SDK de macOS, CMake ≥ 3.19, Ninja,
# Python ≥ 3.8 con html5lib, Node.js ≥ 20, gperf, bison y flex (los de Homebrew).
set -euo pipefail

# Exactamente la misma versión que el Qt de --qt-dir: Qt WebEngine usa API
# privada de Qt y no carga con otra versión
QT_VERSION_OBJ="6.11.2"
QT_DIR=""
TRABAJO="$HOME/qwe"
SALIDA=""
TRABAJOS=0
# arm64 basta para los Mac con Apple Silicon (y para el runner macos-14).
# "arm64;x86_64" (universal) sirve también a los Intel, pero compila Chromium dos veces
ARQUITECTURAS="arm64"
PDF="OFF"
EMPAQUETAR=1

uso() {
    cat <<EOF
Uso: $0 [opciones]
  --qt-version V      versión de Qt (por defecto $QT_VERSION_OBJ)
  --qt-dir RUTA       Qt base de macOS (por defecto ~/Qt/<versión>/macos)
  --trabajo RUTA      carpeta de fuentes y compilación (por defecto $TRABAJO)
  --salida RUTA       donde se instala el módulo (por defecto <trabajo>/salida)
  --trabajos N        trabajos en paralelo (por defecto: según núcleos y RAM)
  --arquitecturas A   "arm64", "x86_64" o "arm64;x86_64" (por defecto $ARQUITECTURAS)
  --con-pdf           compilar también QtPdf (Mitis no lo usa)
  --sin-empaquetar    no crear el .tar.xz
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --qt-version) QT_VERSION_OBJ="$2"; shift 2 ;;
        --qt-dir) QT_DIR="$2"; shift 2 ;;
        --trabajo) TRABAJO="$2"; shift 2 ;;
        --salida) SALIDA="$2"; shift 2 ;;
        --trabajos) TRABAJOS="$2"; shift 2 ;;
        --arquitecturas) ARQUITECTURAS="$2"; shift 2 ;;
        --con-pdf) PDF="ON"; shift ;;
        --sin-empaquetar) EMPAQUETAR=0; shift ;;
        -h|--help) uso; exit 0 ;;
        *) echo "Opción desconocida: $1" >&2; uso; exit 1 ;;
    esac
done
# El Qt oficial de 6.x para macOS se instala en <versión>/macos (antes clang_64)
[[ -n "$QT_DIR" ]] || QT_DIR="$HOME/Qt/$QT_VERSION_OBJ/macos"
[[ -n "$SALIDA" ]] || SALIDA="$TRABAJO/salida"

falla() { echo "Error: $*" >&2; exit 1; }
requiere() { command -v "$1" >/dev/null 2>&1 || falla "falta $1. $2"; }

# --- Comprobaciones antes de empezar (mejor fallar ahora que a las 3 horas) ---

[[ "$(uname -s)" == "Darwin" ]] || falla "este script es para macOS"
xcode-select -p >/dev/null 2>&1 || falla "falta Xcode: instálalo y ejecuta sudo xcode-select -s /Applications/Xcode.app"
requiere cmake "brew install cmake"
requiere ninja "brew install ninja"
requiere python3 "brew install python"
requiere node "brew install node"
requiere gperf "brew install gperf"
requiere curl ""
python3 -c "import html5lib" 2>/dev/null || falla "falta html5lib de Python: python3 -m pip install html5lib (o en un venv)"

node_mayor=$(node -p "process.versions.node.split('.')[0]")
(( node_mayor >= 20 )) || falla "hace falta Node.js ≥ 20 (hay $node_mayor)"

# El bison y el flex de Xcode son demasiado viejos: se usan los de Homebrew
# (keg-only, no están en el PATH por defecto)
if command -v brew >/dev/null 2>&1; then
    for paquete in bison flex; do
        prefijo=$(brew --prefix "$paquete" 2>/dev/null || true)
        [[ -n "$prefijo" && -x "$prefijo/bin/$paquete" ]] || falla "falta $paquete de Homebrew: brew install $paquete"
        export PATH="$prefijo/bin:$PATH"
    done
fi
requiere bison "brew install bison"
requiere flex "brew install flex"

QT_CMAKE="$QT_DIR/bin/qt-cmake"
[[ -x "$QT_CMAKE" ]] || falla "no hay Qt en $QT_DIR (falta bin/qt-cmake)"
qt_instalado=$("$QT_DIR/bin/qmake" -query QT_VERSION)
[[ "$qt_instalado" == "$QT_VERSION_OBJ" ]] || falla "el Qt de $QT_DIR es $qt_instalado, no $QT_VERSION_OBJ: deben coincidir"
if [[ -d "$QT_DIR/lib/QtWebEngineCore.framework" ]]; then
    echo "Aviso: $QT_DIR ya tiene Qt WebEngine: mejor un Qt base sin él (docs/codecs.md, «Qt base»)" >&2
fi

echo "Xcode: $(xcodebuild -version | head -1) · SDK de macOS $(xcrun --show-sdk-version)"

if (( TRABAJOS <= 0 )); then
    nucleos=$(sysctl -n hw.ncpu)
    ram_gb=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
    # Cada trabajo de Chromium (compilación «jumbo») puede pasar de 2 GB
    TRABAJOS=$(( ram_gb / 3 ))
    (( TRABAJOS > nucleos )) && TRABAJOS=$nucleos
    (( TRABAJOS < 1 )) && TRABAJOS=1
fi
# macOS deja solo 256 archivos abiertos por proceso y la compilación de
# Chromium abre muchos más a la vez («Too many open files»): se sube el límite
# para esta terminal (hasta el máximo que permita el sistema)
ulimit -n "$(ulimit -Hn | sed 's/unlimited/65536/')" 2>/dev/null || ulimit -n 65536 2>/dev/null || ulimit -n 10240 || true
echo "Archivos abiertos permitidos: $(ulimit -n)"

echo "Qt $QT_VERSION_OBJ en $QT_DIR · $ARQUITECTURAS · $TRABAJOS trabajos en paralelo · trabajo en $TRABAJO"

# --- Fuentes ---

mkdir -p "$TRABAJO"
serie=$(echo "$QT_VERSION_OBJ" | cut -d. -f1-2)
nombre="qtwebengine-everywhere-src-$QT_VERSION_OBJ"
base="https://download.qt.io/official_releases/qt/$serie/$QT_VERSION_OBJ/submodules"
paquete="$TRABAJO/$nombre.tar.xz"
fuentes="$TRABAJO/$nombre"

if [[ ! -d "$fuentes" ]]; then
    if [[ ! -f "$paquete" ]]; then
        echo "Descargando $nombre.tar.xz (cientos de MB)…"
        curl -L --fail -o "$paquete.parcial" "$base/$nombre.tar.xz"
        mv "$paquete.parcial" "$paquete"
    fi
    # Integridad de la descarga con la suma que publica Qt
    esperada=$(curl -sL --fail "$base/md5sums.txt" | awk -v f="$nombre.tar.xz" '$2 == f { print $1 }')
    real=$(md5 -q "$paquete")
    [[ -n "$esperada" && "$esperada" == "$real" ]] || falla "la suma MD5 de $paquete no coincide ($real ≠ $esperada): bórralo y repite"
    echo "Extrayendo…"
    tar -xJf "$paquete" -C "$TRABAJO"
fi

# --- Configurar ---

build="$TRABAJO/build"
mkdir -p "$build"
# Qt WebEngine lee NINJAFLAGS al configurar y se lo pasa al ninja de Chromium
export NINJAFLAGS="-j$TRABAJOS"

"$QT_CMAKE" -S "$fuentes" -B "$build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$ARQUITECTURAS" \
    -DFEATURE_webengine_proprietary_codecs=ON \
    -DFEATURE_qtpdf_build="$PDF"

# Si la opción no llegó a aplicarse, horas de compilación no servirían de nada
grep -Eq '^QT_FEATURE_webengine_proprietary_codecs:INTERNAL=(ON|1)$' "$build/CMakeCache.txt" \
    || falla "la configuración no activó webengine_proprietary_codecs (mira $build/CMakeCache.txt)"

# --- Compilar e instalar ---

inicio=$SECONDS
cmake --build "$build" --parallel "$TRABAJOS" \
    || falla "la compilación falló (si es por memoria, repite con --trabajos menor: continúa donde se quedó)"
printf 'Compilado en %d h %02d min\n' $(( (SECONDS - inicio) / 3600 )) $(( (SECONDS - inicio) % 3600 / 60 ))

# Instala solo el módulo en $SALIDA, con la estructura de Qt (lib con los
# frameworks, resources, translations, qml…), para extraerlo encima de un Qt igual
rm -rf "$SALIDA"
cmake --install "$build" --prefix "$SALIDA"

# Marca que el workflow comprueba antes de usar el archivo
cat > "$SALIDA/mitis-codecs.txt" <<EOF
qt=$QT_VERSION_OBJ
plataforma=macos-$(echo "$ARQUITECTURAS" | tr ';' '-')
codecs=propietarios
fecha=$(date +%Y-%m-%d)
EOF

if (( ! EMPAQUETAR )); then
    echo "Listo: $SALIDA"
    exit 0
fi

# --- Empaquetar ---

# tar conserva los enlaces simbólicos de los frameworks (un .zip los rompería)
archivo="$TRABAJO/qtwebengine-codecs-$QT_VERSION_OBJ-macos-$(echo "$ARQUITECTURAS" | tr ';' '-').tar.xz"
rm -f "$archivo"
# Sin .dSYM: símbolos de depuración que no hacen falta para compilar ni distribuir
tar -C "$SALIDA" --exclude '*.dSYM' -cJf "$archivo" .
echo "Listo: $archivo ($(du -m "$archivo" | cut -f1) MB). Publicarlo: docs/codecs.md, «Publicar»."

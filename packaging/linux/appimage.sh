#!/usr/bin/env bash
# Crea el AppImage de Mitis a partir de una compilación ya hecha (cmake --build).
# Pensado para GitHub Actions (ubuntu-24.04, Qt de jurplel/install-qt-action),
# pero vale en cualquier Linux con el Qt de la compilación en el PATH (qmake).
#
#   packaging/linux/appimage.sh [carpeta de compilación] [carpeta de salida]
#   (por defecto: build/ y la raíz del repositorio)
#
# Sale Mitis-<versión>-x86_64.AppImage, con Qt y Qt WebEngine dentro: quien lo
# descarga no necesita Qt. Se compila en Ubuntu 24.04, así que pide glibc 2.39 o
# posterior (Ubuntu 24.04, Debian 13, Fedora 40, Arch…).
#
# Qué hace cada pieza:
#   linuxdeploy                 copia el ejecutable y sus bibliotecas al AppDir y
#                               crea el AppImage (plugin appimage, que lleva dentro).
#   linuxdeploy-plugin-qt       añade lo de Qt: plugins (xcb, imageformats, sqldrivers,
#                               tls…), los módulos QML que importan los .qml de qml/
#                               (QML_SOURCES_PATHS: van compilados dentro del ejecutable
#                               y sin esto no los encontraría) y, al ver Qt WebEngine:
#                                 usr/libexec/QtWebEngineProcess (+ su qt.conf)
#                                 usr/resources/  (qtwebengine_*.pak, icudtl.dat,
#                                                  v8_context_snapshot.bin)
#                                 usr/translations/qtwebengine_locales/
#                               Sin cualquiera de ellos las páginas no se abren, así
#                               que el script comprueba que estén antes de empaquetar.
#   apprun-sandbox.sh           gancho del AppRun: decide si el sandbox de Chromium
#                               puede usarse en el sistema (ver ese archivo y su riesgo).

set -euo pipefail

# Versiones fijadas de las herramientas (https://github.com/linuxdeploy)
LINUXDEPLOY_VERSION=1-alpha-20251107-1
LINUXDEPLOY_SHA256=c20cd71e3a4e3b80c3483cef793cda3f4e990aca14014d23c544ca3ce1270b4d
PLUGIN_QT_VERSION=1-alpha-20250213-1
# GitHub no publica el hash de esta versión (es anterior a que lo hiciera):
# es el sha256sum de la descarga, calculado a mano el 2026-10-22.
PLUGIN_QT_SHA256=15106be885c1c48a021198e7e1e9a48ce9d02a86dd0a1848f00bdbf3c1c92724

AQUI=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RAIZ=$(cd "$AQUI/../.." && pwd)
COMPILACION=$(cd "${1:-$RAIZ/build}" && pwd)
SALIDA=$(mkdir -p "${2:-$RAIZ}" && cd "${2:-$RAIZ}" && pwd)
TRABAJO=$COMPILACION/appimage
APPDIR=$TRABAJO/AppDir
HERRAMIENTAS=$TRABAJO/herramientas

VERSION=$(sed -n 's/^    VERSION \([0-9.]*\)$/\1/p' "$RAIZ/CMakeLists.txt" | head -1)
ARCH=x86_64
NOMBRE=Mitis-$VERSION-$ARCH.AppImage

if [[ ! -x $COMPILACION/bin/Mitis ]]; then
    echo "No está $COMPILACION/bin/Mitis: compila antes (cmake --build)." >&2
    exit 1
fi

# El plugin de Qt usa qmake para saber dónde está Qt. install-qt-action deja
# QT_ROOT_DIR; si no, el qmake del PATH.
if [[ -z ${QMAKE:-} ]]; then
    if [[ -n ${QT_ROOT_DIR:-} && -x $QT_ROOT_DIR/bin/qmake ]]; then
        export QMAKE=$QT_ROOT_DIR/bin/qmake
    else
        export QMAKE=$(command -v qmake6 || command -v qmake)
    fi
fi
echo "Qt: $("$QMAKE" -query QT_VERSION) ($QMAKE)"

# Las herramientas son AppImages: así se ejecutan sin FUSE (el runner no lo tiene)
export APPIMAGE_EXTRACT_AND_RUN=1

descargar() { # nombre versión repositorio sha256
    local destino=$HERRAMIENTAS/$1
    if [[ ! -x $destino ]]; then
        curl -fsSL -o "$destino" "https://github.com/linuxdeploy/$3/releases/download/$2/$1"
        chmod +x "$destino"
    fi
    if [[ -n $4 ]]; then
        echo "$4  $destino" | sha256sum -c --quiet -
    else
        echo "Aviso: $1 sin hash fijado; sha256: $(sha256sum "$destino" | cut -d' ' -f1)" >&2
    fi
}
mkdir -p "$HERRAMIENTAS"
descargar linuxdeploy-$ARCH.AppImage "$LINUXDEPLOY_VERSION" linuxdeploy "$LINUXDEPLOY_SHA256"
descargar linuxdeploy-plugin-qt-$ARCH.AppImage "$PLUGIN_QT_VERSION" linuxdeploy-plugin-qt "$PLUGIN_QT_SHA256"
# linuxdeploy busca los plugins en el PATH y junto a sí mismo
export PATH=$HERRAMIENTAS:$PATH

# AppDir limpio en cada ejecución
rm -rf "$APPDIR"
mkdir -p "$APPDIR/apprun-hooks"

# El comando se llama «mitis», como en el .desktop (Exec=mitis) y en el PKGBUILD
cp "$COMPILACION/bin/Mitis" "$TRABAJO/mitis"
cp "$AQUI/apprun-sandbox.sh" "$APPDIR/apprun-hooks/mitis-sandbox.sh"

# Variables del plugin de Qt
export QML_SOURCES_PATHS=$RAIZ/qml
# Lo enlazado (Quick, Network, Sql, Svg, WebEngine) lo detecta solo; esto es por
# si acaso: svg para el plugin de imagen SVG (iconos y favicons .svg) y
# webenginecore para que no falte el despliegue de QtWebEngineProcess (el plugin
# no conoce «webenginequick»: el módulo QML QtWebEngine llega por QML_SOURCES_PATHS)
export EXTRA_QT_MODULES="svg;webenginecore"

# NSS (certificados de Chromium) carga libsoftokn3 y libfreebl con dlopen:
# linuxdeploy no lo ve y, si solo copia libnss3, las conexiones https fallan
# («Error initializing NSS»). Se añaden a mano desde el sistema.
NSS_EXTRA=()
for lib in libsoftokn3.so libfreebl3.so libfreeblpriv3.so; do
    ruta=$(find /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib -name "$lib" -print -quit 2>/dev/null || true)
    if [[ -n $ruta ]]; then
        NSS_EXTRA+=(--library "$ruta")
    else
        echo "Aviso: no se encuentra $lib (paquete libnss3)" >&2
    fi
done

# 1) Ejecutable, bibliotecas y Qt
linuxdeploy-$ARCH.AppImage \
    --appdir "$APPDIR" \
    --executable "$TRABAJO/mitis" \
    --desktop-file "$AQUI/mitis.desktop" \
    --icon-file "$AQUI/mitis.svg" \
    "${NSS_EXTRA[@]}" \
    --plugin qt

# 2) Comprobar lo que Qt WebEngine necesita en tiempo de ejecución
falta=0
for f in usr/libexec/QtWebEngineProcess \
         usr/libexec/qt.conf \
         usr/resources/qtwebengine_resources.pak \
         usr/resources/icudtl.dat \
         usr/translations/qtwebengine_locales/es.pak \
         usr/plugins/platforms/libqxcb.so \
         usr/plugins/sqldrivers/libqsqlite.so \
         usr/qml/QtWebEngine \
         apprun-hooks/mitis-sandbox.sh; do
    if [[ ! -e $APPDIR/$f ]]; then
        echo "Falta en el AppDir: $f" >&2
        falta=1
    fi
done
[[ $falta == 0 ]] || exit 1

# Diccionario del corrector (main.cpp lo busca en usr/share/mitis)
install -Dm644 "$RAIZ/assets/dictionaries/es.bdic" "$APPDIR/usr/share/mitis/qtwebengine_dictionaries/es.bdic"

# Licencias de terceros que van dentro (iconos Lucide, fuente Nunito)
install -Dm644 "$RAIZ/assets/icons/LICENSE" "$APPDIR/usr/share/licenses/mitis/LICENSE-Lucide"
install -Dm644 "$RAIZ/assets/fonts/OFL.txt" "$APPDIR/usr/share/licenses/mitis/OFL-Nunito.txt"

# 3) Empaquetar (plugin appimage de linuxdeploy)
export LDAI_OUTPUT=$SALIDA/$NOMBRE
export OUTPUT=$LDAI_OUTPUT            # nombre que usan las versiones antiguas del plugin
export LINUXDEPLOY_OUTPUT_VERSION=$VERSION
linuxdeploy-$ARCH.AppImage --appdir "$APPDIR" --output appimage

echo "Creado: $SALIDA/$NOMBRE"

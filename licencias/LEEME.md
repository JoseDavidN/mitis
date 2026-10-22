# Licencias de Mitis

Mitis es software libre: Copyright (C) 2026 StartCode.

Puedes redistribuirlo y modificarlo bajo los términos de la **GNU General
Public License, versión 3** (GPL-3.0), publicada por la Free Software
Foundation. Mitis se distribuye con la esperanza de que sea útil, pero **sin
ninguna garantía**, ni siquiera la implícita de comerciabilidad o de idoneidad
para un fin determinado. El texto completo está en `LICENSE` (raíz del código)
y en `GPL-3.0.txt` (esta carpeta).

Código fuente de Mitis: <https://github.com/JoseDavidN/mitis>

Los componentes de terceros que usa Mitis, con sus licencias, están en
[`AVISOS.md`](AVISOS.md).

## Contenido de esta carpeta

| Archivo | Qué es |
|---|---|
| `LEEME.md` | Este archivo: licencia de Mitis y cómo se cumple la LGPL de Qt |
| `AVISOS.md` | Componentes de terceros: nombre, licencia y enlace |
| `GPL-3.0.txt` | GNU GPL v3 (Mitis; también es opción de licencia de Qt) |
| `LGPL-3.0.txt` | GNU LGPL v3 (Qt y Qt WebEngine). Se lee junto con `GPL-3.0.txt` |
| `Nunito-OFL-1.1.txt` | SIL Open Font License 1.1 de la fuente Nunito |
| `Lucide-ISC.txt` | Licencia ISC de los iconos Lucide |
| `miniz-MIT.txt` | Licencia MIT de miniz (instalador de Windows) |

Esta carpeta viaja dentro de cada paquete de Mitis:

- **Windows:** `%LOCALAPPDATA%\Programs\Mitis\licencias\` (y `LICENSE` junto a `Mitis.exe`).
- **macOS:** `Mitis.app/Contents/Resources/licencias/` (y `LICENSE` en `Contents/Resources/`).
- **Linux:** `/usr/share/licenses/mitis/` (o `<prefijo>/share/licenses/mitis/`).

## Cómo cumple Mitis la LGPL de Qt

Qt y Qt WebEngine se usan bajo la **GNU LGPL v3**. La LGPL permite usarlos
desde otro programa siempre que el usuario pueda **sustituir las bibliotecas
de Qt** por otra versión (por ejemplo, una modificada por él) y tenga acceso a
su código fuente. Mitis lo cumple así:

### 1. Qt se enlaza de forma dinámica

- Mitis se compila contra las bibliotecas **compartidas** de Qt: las del
  sistema en Arch Linux y las oficiales de Qt (instaladas con
  `install-qt-action`) en GitHub Actions. No se usa ninguna compilación
  estática de Qt.
- `CMakeLists.txt` enlaza `Qt6::Quick`, `Qt6::Network`, `Qt6::Sql`,
  `Qt6::WebEngineCore`, `Qt6::WebEngineQuick` y `Qt6::Svg` como bibliotecas
  compartidas (`.so`, `.dll`, `.framework`).
- La única biblioteca estática es `mitiscore` (módulo QML `Mitis.Core`), que es
  **código propio de Mitis**, no de Qt. Se enlaza dentro del ejecutable con
  `Q_IMPORT_QML_PLUGIN(Mitis_CorePlugin)`. Los complementos de QML y de
  plataforma de Qt se cargan en tiempo de ejecución desde sus carpetas.
- El instalador de Windows (`installer/`) no usa Qt: solo Win32, GDI+ y miniz.

### 2. El usuario puede sustituir las bibliotecas de Qt

Las bibliotecas de reemplazo deben ser de **Qt 6** con una versión igual o
posterior a la del paquete (Qt mantiene la compatibilidad binaria dentro de
Qt 6) y compiladas para la misma plataforma y compilador.

- **Windows** (`%LOCALAPPDATA%\Programs\Mitis`): las DLL de Qt (`Qt6Core.dll`,
  `Qt6Gui.dll`, `Qt6Quick.dll`, `Qt6WebEngineCore.dll`…) están junto a
  `Mitis.exe`, con `QtWebEngineProcess.exe`, `resources\`, `translations\`,
  y los complementos en `platforms\`, `imageformats\`, `qml\`… Basta con
  reemplazar esos archivos por los de otra compilación de Qt para MSVC 2022 de
  64 bits. Una actualización de Mitis vuelve a escribir los originales.
- **macOS** (`Mitis.app`): Qt va en `Mitis.app/Contents/Frameworks/`
  (`QtCore.framework`, `QtWebEngineCore.framework`…) y sus complementos en
  `Contents/PlugIns/` y `Contents/Resources/qml/`. Se reemplazan los
  frameworks y, como macOS exige firma en Apple Silicon, se vuelve a firmar
  la aplicación con una firma local:
  `codesign --force --deep --sign - Mitis.app`.
- **Linux, Arch (`PKGBUILD`)**: Mitis usa el Qt del sistema (`qt6-base`,
  `qt6-webengine`…). Para cambiarlo basta con instalar otros paquetes de Qt 6
  o apuntar a otras bibliotecas con `LD_LIBRARY_PATH`,
  `QT_PLUGIN_PATH` y `QML_IMPORT_PATH`.
- **Linux, AppImage**: Qt va dentro, en `usr/lib/`, `usr/plugins/` y
  `usr/qml/`. Se extrae con `./Mitis.AppImage --appimage-extract`, se
  reemplazan las bibliotecas en `squashfs-root/` y se ejecuta
  `squashfs-root/AppRun` (o se vuelve a empaquetar con `appimagetool`).

Mitis no impide ni comprueba esta sustitución, y su licencia (GPL-3.0) permite
además modificar y depurar el propio Mitis, por lo que también se cumple el
apartado 4 de la LGPL sobre ingeniería inversa.

### 3. Licencia y avisos incluidos

Cada paquete incluye esta carpeta (`LGPL-3.0.txt` y `GPL-3.0.txt`, que la
LGPL incorpora) y `AVISOS.md`, que indica que Mitis usa Qt y Qt WebEngine y
bajo qué licencia. La sección «Acerca de Mitis» de Configuración lo recuerda.

### 4. Código fuente de Qt

Mitis usa Qt **sin modificar**. Su código fuente, de la misma versión que la
del paquete (se ve en Configuración → Acerca de Mitis y en el nombre de las
bibliotecas):

- Archivos oficiales: <https://download.qt.io/official_releases/qt/>
  (carpeta de la versión → `single/qt-everywhere-src-<versión>.tar.xz`, o
  `submodules/` para cada módulo: `qtbase`, `qtdeclarative`, `qtwebengine`,
  `qtsvg`, `qtwebchannel`, `qtpositioning`…).
- Repositorios: <https://code.qt.io/> y <https://github.com/qt>.

Si quieres el código fuente exacto de Qt de un paquete concreto de Mitis y no
lo encuentras en esos enlaces, pídelo en
<https://github.com/JoseDavidN/mitis/issues>: durante al menos tres años
desde la publicación de cada versión se facilitará a quien lo solicite.

### 5. Código fuente de Mitis

Mitis es GPL-3.0: su código fuente completo, incluidos los scripts de
compilación y empaquetado (`CMakeLists.txt`, `installer/`,
`.github/workflows/`), está en <https://github.com/JoseDavidN/mitis>.

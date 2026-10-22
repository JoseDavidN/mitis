# Avisos de terceros

Mitis (GPL-3.0, ver `LEEME.md`) usa los componentes siguientes. Los textos de
licencia que se citan están en esta misma carpeta.

## Distribuidos con Mitis

### Qt 6

- **Qué:** biblioteca de la interfaz y del sistema. Módulos usados: Qt Core,
  Qt Gui, Qt Qml, Qt Quick, Qt Quick Controls, Qt Network, Qt Sql (SQLite),
  Qt Svg, Qt WebEngine (Core y Quick) y sus dependencias Qt WebChannel y
  Qt Positioning.
- **Licencia:** GNU LGPL v3 (`LGPL-3.0.txt`, junto con `GPL-3.0.txt`).
  Copyright (C) The Qt Company Ltd. y otros colaboradores.
- **Enlace:** <https://www.qt.io/> · código: <https://download.qt.io/official_releases/qt/>
- **Terceros dentro de Qt** (zlib, libpng, libjpeg, FreeType, HarfBuzz, PCRE2,
  SQLite, double-conversion…): lista y licencias en
  <https://doc.qt.io/qt-6/licenses-used-in-qt.html>.
- Cómo se cumple la LGPL (enlace dinámico, sustitución de las bibliotecas y
  código fuente): `LEEME.md`.

### Qt WebEngine y Chromium

- **Qué:** motor que renderiza las páginas. Qt WebEngine integra Chromium
  (Blink, V8, Skia, FFmpeg, ICU, BoringSSL, libvpx, libwebp y muchos más).
- **Licencia:** Qt WebEngine, GNU LGPL v3. Chromium y sus componentes tienen
  sus propias licencias, en su mayoría BSD de 3 cláusulas (Chromium), y además
  MIT, Apache 2.0, LGPL 2.1 (FFmpeg, partes de Blink), MPL 2.0, ICU y otras.
- **Enlace:** <https://doc.qt.io/qt-6/qtwebengine-index.html>
- **Avisos de Chromium:** el listado completo de componentes de Chromium
  incluidos en Qt WebEngine, con su licencia, está en
  <https://doc.qt.io/qt-6/qtwebengine-licensing.html> (y en la página de
  licencias de la documentación de cada versión de Qt). Cada componente lleva
  su archivo `LICENSE` o `README.chromium` en el código fuente de Qt WebEngine
  (`qtwebengine-everywhere-src-<versión>`, carpeta `src/3rdparty/chromium/` y
  sus `third_party/`).
- El FFmpeg que incluye Qt WebEngine es el de Chromium, compilado como LGPL.
  Los paquetes oficiales de Qt para Windows y macOS no traen códecs
  propietarios (H.264, AAC); el Qt WebEngine de Arch Linux sí.

### Fuente Nunito

- **Licencia:** SIL Open Font License 1.1 (`Nunito-OFL-1.1.txt`; en el
  código, `assets/fonts/OFL.txt`).
  Copyright 2014 The Nunito Project Authors.
- **Enlace:** <https://github.com/googlefonts/nunito>
- Va dentro del ejecutable de Mitis y del instalador de Windows.

### Iconos Lucide

- **Licencia:** ISC (`Lucide-ISC.txt`; en el código, `assets/icons/LICENSE`).
  Copyright (c) Lucide Contributors 2022; partes, Cole Bemis 2013-2022
  (Feather, MIT).
- **Enlace:** <https://lucide.dev/> · <https://github.com/lucide-icons/lucide>
- Los SVG van dentro del ejecutable (algunos renombrados por uso).

### miniz

- **Qué:** lectura de ZIP del instalador de Windows (`installer/`), versión 3.0.2.
- **Licencia:** MIT (`miniz-MIT.txt`).
  Copyright 2013-2014 RAD Game Tools and Valve Software; Copyright 2010-2014
  Rich Geldreich and Tenacious Software LLC.
- **Enlace:** <https://github.com/richgel999/miniz>

### Runtime de Visual C++ (solo Windows)

- **Qué:** `msvcp140.dll`, `vcruntime140.dll`… junto a `Mitis.exe`.
- **Licencia:** archivos redistribuibles de Microsoft Visual Studio 2022
  (Microsoft Software License Terms, lista «Distributable Code»).
- **Enlace:** <https://learn.microsoft.com/cpp/windows/redistributing-visual-cpp-files>

## Descargados en el equipo del usuario (no se distribuyen)

### Listas de filtros del bloqueador de anuncios

Mitis **no incluye** estas listas en sus paquetes: si el bloqueador está
activo, `ContentBlocker` las descarga de sus sitios oficiales directamente al
equipo del usuario (carpeta de datos de Mitis, `filtros/`) y las renueva cada
4 días. Cada lista conserva su licencia.

| Lista | Licencia | Enlace |
|---|---|---|
| EasyList | GPL v3 o CC BY-SA 3.0, a elegir | <https://easylist.to/> · <https://easylist.to/pages/licence.html> |
| EasyPrivacy | GPL v3 o CC BY-SA 3.0, a elegir | <https://easylist.to/> |
| EasyList Spanish | GPL v3 o CC BY-SA 3.0, a elegir | <https://easylist-downloads.adblockplus.org/easylistspanish.txt> |
| HaGeZi DNS Blocklists (Pro) | GPL v3 | <https://github.com/hagezi/dns-blocklists> |
| uBlock Origin, filtros «Unbreak» (uAssets) | GPL v3 | <https://github.com/uBlockOrigin/uAssets> |

### Módulo Widevine

Mitis no incluye Widevine (Google). Si el usuario ya lo tiene instalado por
Google Chrome, Chromium o Firefox, Mitis lo localiza y se lo pasa al motor.
Su uso se rige por las condiciones de Google.

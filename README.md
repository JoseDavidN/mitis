# Mitis

Navegador web ligero, multiplataforma y con interfaz propia.

Mitis usa Chromium (vía Qt WebEngine) únicamente para mostrar páginas web. Toda la interfaz y sus funciones se construyen desde cero con QML y C++.

Recursos de terceros incluidos: iconos [Lucide](https://lucide.dev) (ISC) y fuente [Nunito](https://github.com/googlefonts/nunito) (SIL OFL). Sus licencias están en `assets/icons/LICENSE` y `assets/fonts/OFL.txt`.

## Objetivos

- **Interfaz 100% propia**, nativa y sin HTML, dibujada con QML.
- **Bajo consumo de RAM**: suspensión de pestañas inactivas, bloqueo de anuncios y trackers, nada en segundo plano.
- **Multiplataforma**: Linux, Windows y macOS con el mismo código.

## Stack

| Capa | Tecnología |
|---|---|
| Motor | Chromium vía Qt WebEngine |
| Interfaz | QML (Qt Quick) |
| Lógica | C++17 |
| Build | CMake 3.21+ |

## Estructura

```
mitis/
├── src/        Código C++
├── qml/        Interfaz en QML
├── assets/     Iconos, fuentes e imágenes
├── docs/       Documentación del proyecto
└── CMakeLists.txt
```

## Requisitos

- **Qt 6.8 o superior** con los módulos **Qt WebEngine** y **Qt SVG** (se instalan desde el Qt Online Installer; en Arch: `qt6-webengine qt6-svg`).
- CMake 3.21 o superior.
- Compilador C++17:
  - **Windows:** MSVC (Visual Studio 2022). Qt WebEngine no funciona con MinGW.
  - **macOS:** Xcode / Clang.
  - **Linux:** GCC o Clang.

## Compilar

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=/ruta/a/Qt/6.x.x/<kit>
cmake --build build
```

## Modo desarrollo

Para trabajar la interfaz sin recompilar:

```bash
./build/bin/Mitis --dev
```

En este modo Mitis carga los QML directamente desde `qml/` y recarga la ventana cada vez que guardas un `.qml` o `.js`. Si hay un error de QML, se muestra en la terminal y la app sigue abierta: corriges, guardas y se recarga.

Solo hay que recompilar al cambiar código C++ o `CMakeLists.txt`.

## Estado

Versión 0.1.0, etapa inicial.
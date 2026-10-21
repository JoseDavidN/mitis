# Mitis

Navegador web ligero, multiplataforma y con interfaz propia.

Mitis usa Chromium (vía Qt WebEngine) únicamente para mostrar páginas web. Toda la interfaz y sus funciones se construyen desde cero con QML y C++.

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

- **Qt 6.5 o superior** con el módulo **Qt WebEngine** (se instala desde el Qt Online Installer).
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

## Estado

Versión 0.1.0, etapa inicial.

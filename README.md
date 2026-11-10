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

## Linux

**Arch:** con el `PKGBUILD` de `packaging/linux/` (compila la rama `main` con el Qt del sistema):

```bash
mkdir -p ~/mitis-pkg && cd ~/mitis-pkg
cp /ruta/a/mitis/packaging/linux/PKGBUILD .
makepkg -si            # para actualizar, otra vez lo mismo
```

Opcionales: `libva` y el driver de tu GPU (vídeo con la tarjeta gráfica), `pipewire` y el portal de tu escritorio (`xdg-desktop-portal-hyprland` en Hyprland: compartir pantalla y diálogos de archivos). **Otras distribuciones:** el AppImage de cada versión (se actualiza solo).

**Hyprland, Sway, i3, niri, River:** Mitis no muestra barra de título ni bordes; las ventanas se mueven, cambian de tamaño y se cierran con los atajos del escritorio. Su clase (`app_id`) es `mitis`. Ejemplo para Hyprland 0.56 o posterior (configuración en Lua): herramientas de desarrollo (F12) flotando.

```lua
hl.window_rule({
    name  = "mitis-devtools",
    match = { class = "^mitis$", title = ".*Herramientas de desarrollo$" },
    float = true,
})
```

Con la configuración antigua (`hyprland.conf`): `windowrulev2 = float, class:^(mitis)$, title:^(.*Herramientas de desarrollo)$`.

## Modo desarrollo

Para trabajar la interfaz sin recompilar:

```bash
./build/bin/Mitis --dev
```

En este modo Mitis carga los QML directamente desde `qml/` y recarga la ventana cada vez que guardas un `.qml` o `.js`. Si hay un error de QML, se muestra en la terminal y la app sigue abierta: corriges, guardas y se recarga.

Solo hay que recompilar al cambiar código C++ o `CMakeLists.txt`.

## Estado

Versión 0.21.0 (beta, en desarrollo; la última publicada es la 0.20.0). Lo pendiente está en `docs/PLAN.md`; lo hecho en cada versión, en `CHANGELOG.md`. Windows y macOS usan Qt WebEngine con códecs propietarios (H.264, AAC), compilado aparte (`docs/codecs.md`).


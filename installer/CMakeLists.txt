# Instalador de Mitis para Windows (ver src/main.cpp). Proyecto aparte del
# navegador: Win32 y GDI+, sin Qt, porque se ejecuta antes de que Qt esté
# instalado. Lo compila GitHub Actions (.github/workflows/compilar.yml); no
# lleva Mitis dentro: lo descarga del servidor (ver src/red.h), donde
# empaquetar.ps1 deja el ZIP y version.txt.
cmake_minimum_required(VERSION 3.21)
project(MitisInstalador LANGUAGES C CXX)

if(NOT WIN32)
    message(FATAL_ERROR "El instalador de Mitis es solo para Windows")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# CRT estático: el instalador funciona sin el runtime de Visual C++, que
# viaja dentro del paquete y aún no está en el equipo
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

set(MITIS_VERSION "0.0.0" CACHE STRING "Versión de Mitis con la que se compila el instalador")
# Dónde están version.txt y los paquetes (sin barra final). Pruebas: el
# servidor de la red de Tailscale, por IP
set(MITIS_SERVIDOR "http://100.67.58.55/mitis" CACHE STRING "Servidor de descargas de Mitis")

# miniz (MIT): lectura de ZIP en un solo archivo de C
include(FetchContent)
FetchContent_Declare(miniz
    URL https://github.com/richgel999/miniz/releases/download/3.0.2/miniz-3.0.2.zip
    URL_HASH SHA256=ada38db0b703a56d3dd6d57bf84a9c5d664921d870d8fea4db153979fb5332c5
    # Sin CMakeLists propio: solo se descarga
    SOURCE_SUBDIR sin-cmake
)
FetchContent_MakeAvailable(miniz)
add_library(miniz STATIC ${miniz_SOURCE_DIR}/miniz.c)
target_include_directories(miniz PUBLIC ${miniz_SOURCE_DIR})

# Recursos: manifiesto, fuente Nunito y logo de StartCode (rutas absolutas)
set(MITIS_FUENTE "${CMAKE_CURRENT_SOURCE_DIR}/../assets/fonts/Nunito.ttf")
set(MITIS_STARTCODE "${CMAKE_CURRENT_SOURCE_DIR}/../assets/branding/startcode.png")
set(MITIS_ICONO "${CMAKE_CURRENT_SOURCE_DIR}/../assets/branding/mitis.ico")
set(MITIS_LOGO "${CMAKE_CURRENT_SOURCE_DIR}/../assets/branding/mitis.png")
set(MITIS_MANIFIESTO "${CMAKE_CURRENT_SOURCE_DIR}/instalador.manifest")
configure_file(recursos.rc.in "${CMAKE_CURRENT_BINARY_DIR}/recursos.rc")

add_executable(MitisInstalador WIN32
    src/main.cpp
    src/instalacion.h
    src/instalacion.cpp
    src/red.h
    src/red.cpp
    "${CMAKE_CURRENT_BINARY_DIR}/recursos.rc"
)
target_compile_definitions(MitisInstalador PRIVATE
    UNICODE _UNICODE NOMINMAX
    # _wfopen y compañía: se usan con rutas propias, sin riesgo
    _CRT_SECURE_NO_WARNINGS
    MITIS_VERSION="${MITIS_VERSION}"
    MITIS_SERVIDOR="${MITIS_SERVIDOR}"
)
target_link_libraries(MitisInstalador PRIVATE
    miniz gdiplus winhttp bcrypt shlwapi ole32 shell32 uuid dwmapi advapi32 user32 gdi32
)
if(MSVC)
    # Fuentes en UTF-8 (textos con tildes); el manifiesto va en recursos.rc
    target_compile_options(MitisInstalador PRIVATE /utf-8 /W4)
    target_link_options(MitisInstalador PRIVATE /MANIFEST:NO)
endif()

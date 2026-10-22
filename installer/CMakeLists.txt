# Instalador de Mitis para Windows (ver src/main.cpp). Proyecto aparte del
# navegador: Win32 y GDI+, sin Qt, porque se ejecuta antes de que Qt esté
# instalado. Lo compila GitHub Actions (.github/workflows/compilar.yml) y
# empaquetar.ps1 le pega al final el ZIP con Mitis.
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

set(MITIS_VERSION "0.0.0" CACHE STRING "Versión de Mitis que instala")

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
set(MITIS_MANIFIESTO "${CMAKE_CURRENT_SOURCE_DIR}/instalador.manifest")
configure_file(recursos.rc.in "${CMAKE_CURRENT_BINARY_DIR}/recursos.rc")

add_executable(MitisInstalador WIN32
    src/main.cpp
    src/instalacion.h
    src/instalacion.cpp
    "${CMAKE_CURRENT_BINARY_DIR}/recursos.rc"
)
target_compile_definitions(MitisInstalador PRIVATE
    UNICODE _UNICODE NOMINMAX
    MITIS_VERSION="${MITIS_VERSION}"
)
target_link_libraries(MitisInstalador PRIVATE
    miniz gdiplus shlwapi ole32 shell32 uuid dwmapi advapi32 user32 gdi32
)
if(MSVC)
    # Fuentes en UTF-8 (textos con tildes); el manifiesto va en recursos.rc
    target_compile_options(MitisInstalador PRIVATE /utf-8 /W4)
    target_link_options(MitisInstalador PRIVATE /MANIFEST:NO)
endif()

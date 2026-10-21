cmake_minimum_required(VERSION 3.21)

project(Mitis
    VERSION 0.1.0
    DESCRIPTION "Navegador web ligero, multiplataforma y con interfaz propia"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick WebEngineQuick)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(mitis
    src/main.cpp
)

# Los QML viven en qml/, pero se registran en la raíz del módulo
set_source_files_properties(qml/Main.qml PROPERTIES QT_RESOURCE_ALIAS Main.qml)

qt_add_qml_module(mitis
    URI Mitis
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

target_compile_definitions(mitis PRIVATE MITIS_VERSION="${PROJECT_VERSION}")

target_link_libraries(mitis PRIVATE
    Qt6::Quick
    Qt6::WebEngineQuick
)

set_target_properties(mitis PROPERTIES
    OUTPUT_NAME "Mitis"
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_NAME "Mitis"
    MACOSX_BUNDLE_GUI_IDENTIFIER "app.mitis.browser"
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
)

include(GNUInstallDirs)
install(TARGETS mitis
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

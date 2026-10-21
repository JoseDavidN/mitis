cmake_minimum_required(VERSION 3.21)

project(Mitis
    VERSION 0.1.0
    DESCRIPTION "Navegador web ligero, multiplataforma y con interfaz propia"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Network WebEngineQuick Svg)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(mitis
    src/main.cpp
    src/devreloader.h
    src/devreloader.cpp
    src/iconprovider.h
    src/iconprovider.cpp
    src/networkfactory.h
    src/networkfactory.cpp
)

# Iconos SVG (Lucide, ISC: assets/icons/LICENSE), empaquetados en :/icons
file(GLOB MITIS_ICON_FILES RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" CONFIGURE_DEPENDS assets/icons/*.svg)
qt_add_resources(mitis "icons"
    PREFIX "/icons"
    BASE assets/icons
    FILES ${MITIS_ICON_FILES}
)

# Scripts que Mitis inyecta en las páginas (puente multimedia), en :/scripts
qt_add_resources(mitis "scripts"
    PREFIX "/scripts"
    BASE assets/scripts
    FILES assets/scripts/media.js
)

# Fuente de la interfaz: Nunito (SIL OFL: assets/fonts/OFL.txt), en :/fonts
qt_add_resources(mitis "fonts"
    PREFIX "/fonts"
    BASE assets/fonts
    FILES assets/fonts/Nunito.ttf
)

# Los QML viven en qml/, pero se registran en la raíz del módulo
set(MITIS_QML_FILES
    qml/Main.qml
    qml/Theme.qml
    qml/TitleBar.qml
    qml/BottomBar.qml
    qml/AddressBar.qml
    qml/TabsPopup.qml
    qml/OptionsPopup.qml
    qml/PopupBackground.qml
    qml/PopupAction.qml
    qml/IconButton.qml
    qml/Icon.qml
    qml/Tooltip.qml
    qml/TextButton.qml
    qml/FormField.qml
    qml/NewTabPage.qml
    qml/QuickLinkTile.qml
    qml/QuickLinkEditor.qml
    qml/NewsCard.qml
    qml/News.qml
    qml/MiniPlayer.qml
    qml/urls.js
    qml/ResizeHandles.qml
)
set_source_files_properties(qml/Theme.qml qml/News.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
foreach(qml_file IN LISTS MITIS_QML_FILES)
    get_filename_component(qml_name ${qml_file} NAME)
    set_source_files_properties(${qml_file} PROPERTIES QT_RESOURCE_ALIAS ${qml_name})
endforeach()

qt_add_qml_module(mitis
    URI Mitis
    VERSION 1.0
    QML_FILES ${MITIS_QML_FILES}
)

target_compile_definitions(mitis PRIVATE
    MITIS_VERSION="${PROJECT_VERSION}"
    # Ruta a qml/ en el código fuente, usada por el modo desarrollo (--dev)
    MITIS_QML_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml"
    # Iconos desde el código fuente en modo desarrollo
    MITIS_ICONS_DIR="${CMAKE_CURRENT_SOURCE_DIR}/assets/icons"
)

target_link_libraries(mitis PRIVATE
    Qt6::Quick
    Qt6::Network
    Qt6::WebEngineQuick
    Qt6::Svg
)

set_target_properties(mitis PROPERTIES
    OUTPUT_NAME "Mitis"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
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
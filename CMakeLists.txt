cmake_minimum_required(VERSION 3.21)

project(Mitis
    VERSION 0.1.0
    DESCRIPTION "Navegador web ligero, multiplataforma y con interfaz propia"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Quick Network Sql WebEngineCore WebEngineQuick Svg)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(mitis
    src/main.cpp
    src/devreloader.h
    src/devreloader.cpp
    src/iconprovider.h
    src/iconprovider.cpp
    src/networkfactory.h
    src/networkfactory.cpp
    src/requestinterceptor.h
    src/requestinterceptor.cpp
    src/enginebridge.h
    src/enginebridge.cpp
    src/widevine.h
    src/widevine.cpp
)

# Tipos de C++ para QML (Settings…), en un módulo propio, Mitis.Core: el modo
# --dev carga los QML desde qml/ y no ve los tipos del módulo Mitis, pero sí
# puede importar este (va en el ejecutable, en qrc:/qt/qml/Mitis/Core)
qt_add_library(mitiscore STATIC)
qt_add_qml_module(mitiscore
    URI Mitis.Core
    VERSION 1.0
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/Mitis/Core"
    SOURCES
        src/settings.h
        src/settings.cpp
        src/history.h
        src/history.cpp
        src/bookmarks.h
        src/bookmarks.cpp
)
# El registro de tipos generado incluye "settings.h" sin ruta
target_include_directories(mitiscore PRIVATE src)
target_link_libraries(mitiscore PRIVATE Qt6::Sql)

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
    FILES assets/scripts/media.js assets/scripts/devtools.js assets/scripts/drm.js
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
    qml/BrowserTab.qml
    qml/BrowserProfile.qml
    qml/Downloads.qml
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
    qml/FindBar.qml
    qml/ZoomIndicator.qml
    qml/DownloadPanel.qml
    qml/ProgressBar.qml
    qml/ProgressRing.qml
    qml/DownloadsPopup.qml
    qml/urls.js
    qml/SearchEngines.qml
    qml/SettingsPage.qml
    qml/ThemeBackground.qml
    qml/Toggle.qml
    qml/RadioMark.qml
    qml/CheckMark.qml
    qml/PageRow.qml
    qml/BookmarksPopup.qml
    qml/HistoryPopup.qml
    qml/ResizeHandles.qml
    qml/FullscreenHint.qml
    qml/DevToolsWindow.qml
    qml/ProtectedContentNotice.qml
    qml/PageDialog.qml
    qml/PermissionDialog.qml
    qml/CertificateDialog.qml
    qml/JsDialog.qml
    qml/FilePicker.qml
    qml/ContextMenu.qml
)
set_source_files_properties(qml/Theme.qml qml/News.qml qml/BrowserProfile.qml qml/Downloads.qml qml/SearchEngines.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
foreach(qml_file IN LISTS MITIS_QML_FILES)
    get_filename_component(qml_name ${qml_file} NAME)
    set_source_files_properties(${qml_file} PROPERTIES QT_RESOURCE_ALIAS ${qml_name})
endforeach()

qt_add_qml_module(mitis
    URI Mitis
    VERSION 1.0
    QML_FILES ${MITIS_QML_FILES}
    IMPORTS Mitis.Core
)

target_compile_definitions(mitis PRIVATE
    MITIS_VERSION="${PROJECT_VERSION}"
    # Ruta a qml/ en el código fuente, usada por el modo desarrollo (--dev)
    MITIS_QML_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml"
    # Iconos desde el código fuente en modo desarrollo
    MITIS_ICONS_DIR="${CMAKE_CURRENT_SOURCE_DIR}/assets/icons"
)

target_link_libraries(mitis PRIVATE
    mitiscoreplugin
    Qt6::Quick
    Qt6::Network
    Qt6::WebEngineCore
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
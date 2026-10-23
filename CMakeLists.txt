cmake_minimum_required(VERSION 3.21)

project(Mitis
    VERSION 0.5.0
    DESCRIPTION "Navegador web ligero, multiplataforma y con interfaz propia"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Quick Network Sql WebEngineCore WebEngineQuick Svg)

qt_standard_project_setup(REQUIRES 6.8)

# Etapa de la versión: con "-beta", Mitis se presenta como beta (versión
# 0.5.0-beta, «Beta» en la barra de título). Vacío en las versiones finales.
set(MITIS_VERSION_SUFFIX "-beta" CACHE STRING "Sufijo de la versión (-beta, vacío en las finales)")

# Windows: <windows.h> (memorymonitor.cpp) no debe definir min/max, y MSVC
# debe leer el código como UTF-8 (textos con tildes)
if(WIN32)
    add_compile_definitions(NOMINMAX)
endif()
if(MSVC)
    add_compile_options(/utf-8)
endif()

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
    src/filterengine.h
    src/filterengine.cpp
    src/contentblocker.h
    src/contentblocker.cpp
    src/enginebridge.h
    src/enginebridge.cpp
    src/widevine.h
    src/widevine.cpp
    src/notifier.h
    src/notifier.cpp
)

# Notificaciones del sistema (src/notifier.*): D-Bus en Linux,
# UserNotifications en macOS; en Windows, Shell_NotifyIcon (shell32)
if(APPLE)
    enable_language(OBJCXX)
    target_sources(mitis PRIVATE src/notifier_mac.mm)
    set_source_files_properties(src/notifier_mac.mm PROPERTIES COMPILE_OPTIONS "-fobjc-arc")
    target_link_libraries(mitis PRIVATE "-framework Foundation" "-framework UserNotifications")
elseif(WIN32)
    target_link_libraries(mitis PRIVATE shell32)
else()
    find_package(Qt6 REQUIRED COMPONENTS DBus)
    target_link_libraries(mitis PRIVATE Qt6::DBus)
    target_compile_definitions(mitis PRIVATE MITIS_DBUS_NOTIFICATIONS)
endif()

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
        src/memorymonitor.h
        src/memorymonitor.cpp
        src/links.h
        src/links.cpp
        src/captureindicator.h
        src/captureindicator.cpp
)
# El registro de tipos generado incluye "settings.h" sin ruta
target_include_directories(mitiscore PRIVATE src)
target_link_libraries(mitiscore PRIVATE Qt6::Sql Qt6::Network Qt6::Gui Qt6::Svg)

# Iconos SVG (Lucide, ISC: assets/icons/LICENSE), empaquetados en :/icons
file(GLOB MITIS_ICON_FILES RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" CONFIGURE_DEPENDS assets/icons/*.svg)
qt_add_resources(mitis "icons"
    PREFIX "/icons"
    BASE assets/icons
    FILES ${MITIS_ICON_FILES}
)

# Scripts que Mitis inyecta en las páginas (puente multimedia), en :/scripts
# Icono de la aplicación: ventana en todos los sistemas (:/branding/mitis.png)
# y, en Windows, el del ejecutable. Nombre de Mitis (sin icono) en la barra
# de título; logo completo al pie del índice de Configuración (versiones para
# temas oscuros y claros), y el de StartCode al final de sus ajustes
qt_add_resources(mitis "branding"
    PREFIX "/branding"
    BASE assets/branding
    FILES assets/branding/mitis.png assets/branding/mitis-logo-dark.png
          assets/branding/mitis-logo-light.png assets/branding/startcode.png
          assets/branding/startcode-light.png assets/branding/mitis-wordmark-dark.png
          assets/branding/mitis-wordmark-light.png
)
if(WIN32)
    target_sources(mitis PRIVATE assets/branding/mitis.rc)
endif()

qt_add_resources(mitis "scripts"
    PREFIX "/scripts"
    BASE assets/scripts
    FILES assets/scripts/media.js assets/scripts/devtools.js assets/scripts/drm.js assets/scripts/google.js
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
    qml/MemoryPanel.qml
    qml/Avatar.qml
    qml/ControlsTab.qml
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
    MITIS_VERSION="${PROJECT_VERSION}${MITIS_VERSION_SUFFIX}"
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
    # Con http/https y HTML: se puede elegir como navegador predeterminado
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/packaging/macos/Info.plist.in"
)

include(GNUInstallDirs)
install(TARGETS mitis
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Linux: entrada de escritorio, icono y licencias (la de Mitis y las de
# terceros, en share/licenses/mitis)
if(UNIX AND NOT APPLE)
    install(FILES packaging/linux/mitis.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
    install(FILES packaging/linux/mitis.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
    install(FILES LICENSE DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/licenses/mitis)
    install(DIRECTORY licencias/ DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/licenses/mitis)
endif()

cmake_minimum_required(VERSION 3.21)

project(Qupil VERSION 1.5.28 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

include(CTest)
include(GNUInstallDirs)

find_package(Qt6 6.5 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    Sql
    Multimedia
)

qt_standard_project_setup(REQUIRES 6.5)

if(QT_KNOWN_POLICY_QTP0004)
    qt_policy(SET QTP0004 NEW)
endif()

qt_add_executable(qupil
    src/app/main.cpp
    src/app/databasemanager.cpp
    src/app/databasemanager.h
    src/app/variantlistmodel.cpp
    src/app/variantlistmodel.h
    src/app/appcontroller.cpp
    src/app/appcontroller.h
    src/app/metronomecontroller.cpp
    src/app/metronomecontroller.h
    src/app/native_share.h
)


# Qupil v28 PDF sharing
if(IOS)
    enable_language(OBJCXX)
    target_sources(qupil PRIVATE src/app/native_share_ios.mm)
    set_source_files_properties(src/app/native_share_ios.mm PROPERTIES COMPILE_FLAGS "-fobjc-arc")
    target_link_libraries(qupil PRIVATE "-framework UIKit")
else()
    target_sources(qupil PRIVATE src/app/native_share.cpp)
endif()

if(NOT ANDROID AND NOT IOS)
    find_package(Qt6 6.5 REQUIRED COMPONENTS PrintSupport)
    target_link_libraries(qupil PRIVATE Qt6::PrintSupport)
    target_compile_definitions(qupil PRIVATE QUPIL_DESKTOP_PRINTING=1)

    # QUPIL_NATIVE_PRINT_DIALOG_V1
    # Linux uses the desktop Print portal directly. On Plasma this is handled
    # by xdg-desktop-portal-kde and therefore displays the KDE print dialog.
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        find_package(Qt6 6.5 REQUIRED COMPONENTS DBus)
        target_link_libraries(qupil PRIVATE Qt6::DBus)
        target_compile_definitions(qupil PRIVATE QUPIL_XDG_PORTAL_PRINTING=1)
    endif()

    # QUPIL_NATIVE_PRINT_DIALOG_DESKTOP_V3
    # Qt documents QPrintDialog as the native print dialog on Windows/macOS.
    # QApplication is required because QPrintDialog is QWidget based.
    # This block is inside NOT ANDROID/NOT IOS, so APPLE here means desktop macOS.
    if(WIN32 OR APPLE)
        find_package(Qt6 6.5 REQUIRED COMPONENTS Widgets)
        target_link_libraries(qupil PRIVATE Qt6::Widgets)
        target_compile_definitions(qupil PRIVATE QUPIL_NATIVE_WIDGET_PRINTING=1)
    endif()
endif()

qt_add_qml_module(qupil
    URI Qupil
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/SectionCard.ui.qml
        qml/components/EmptyState.ui.qml
        qml/components/LabeledField.ui.qml
        qml/components/DocumentActions.qml
        qml/components/DocumentPreviewDialog.qml
        qml/components/DailyScheduleDialog.qml
        qml/pages/DashboardPage.qml
        qml/pages/DashboardPageForm.ui.qml
        qml/pages/SchedulePage.qml
        qml/pages/SchedulePageForm.ui.qml
        qml/pages/PupilsPage.qml
        qml/pages/PupilsPageForm.ui.qml
        qml/pages/PupilDetailPage.qml
        qml/pages/PupilDetailPageForm.ui.qml
        qml/pages/LessonsPage.qml
        qml/pages/LessonsPageForm.ui.qml
        qml/pages/LessonDetailPage.qml
        qml/pages/LessonDetailPageForm.ui.qml
        qml/pages/RemindersPage.qml
        qml/pages/RemindersPageForm.ui.qml
        qml/pages/LibraryPage.qml
        qml/pages/LibraryPageForm.ui.qml
        qml/pages/RecitalsPage.qml
        qml/pages/RecitalsPageForm.ui.qml
        qml/pages/RecitalDetailPage.qml
        qml/pages/RecitalDetailPageForm.ui.qml
        qml/pages/ArchivePage.qml
        qml/pages/ArchivePageForm.ui.qml
        qml/pages/MetronomePage.qml
        qml/pages/MetronomePageForm.ui.qml
        qml/pages/SettingsPage.qml
        qml/pages/SettingsPageForm.ui.qml
        qml/pages/ReportsPage.qml
        qml/pages/ReportsPageForm.ui.qml
        qml/pages/CsvImportPage.qml
        qml/pages/CsvImportPageForm.ui.qml
    RESOURCES
        data/sounds/s1.wav
        data/sounds/s2.wav
        data/sounds/s3.wav
        data/sounds/reminder.wav
        data/sounds/lesson-end.wav
        data/sounds/tuning/a438.wav
        data/sounds/tuning/a439.wav
        data/sounds/tuning/a440.wav
        data/sounds/tuning/a441.wav
        data/sounds/tuning/a442.wav
        data/sounds/tuning/a443.wav
        data/sounds/tuning/a444.wav
        data/sounds/tuning/a445.wav
        data/sounds/tuning/b438.wav
        data/sounds/tuning/b439.wav
        data/sounds/tuning/b440.wav
        data/sounds/tuning/b441.wav
        data/sounds/tuning/b442.wav
        data/sounds/tuning/b443.wav
        data/sounds/tuning/b444.wav
        data/sounds/tuning/b445.wav
        qupil.png
)

# Qupil v11 pinned Android deployment properties
if(ANDROID)
    set_target_properties(qupil PROPERTIES
        QT_ANDROID_COMPILE_SDK_VERSION "36"
        QT_ANDROID_TARGET_SDK_VERSION "36"
        QT_ANDROID_SDK_BUILD_TOOLS_REVISION "36.0.0"
    )
endif()

# Qupil v13 language controller
target_sources(qupil PRIVATE
    src/app/languagecontroller.cpp
    src/app/languagecontroller.h
)

# Qupil v13 explicit translation resource
qt_add_resources(qupil "qupil_i18n"
    PREFIX "/i18n"
    BASE "${CMAKE_CURRENT_SOURCE_DIR}/i18n"
    FILES
        "${CMAKE_CURRENT_SOURCE_DIR}/i18n/qupil_de.qm"
)

target_link_libraries(qupil PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    Qt6::Multimedia
)

# Qupil only needs SQLite. Importing the Qt-provided driver explicitly keeps
# desktop/mobile packages self-contained and avoids accidental dependencies on
# system SQL drivers. Official Qt binary packages ship this plugin.
if(NOT TARGET Qt6::QSQLiteDriverPlugin)
    message(FATAL_ERROR "Qt was installed without the QSQLITE driver plugin")
endif()
qt_import_plugins(qupil
    INCLUDE_BY_TYPE sqldrivers Qt6::QSQLiteDriverPlugin
)

# Qupil iOS: Qt Multimedia FFmpeg frameworks
# Official Qt iOS binary packages with Multimedia include an FFmpeg backend.
# Those FFmpeg XCFrameworks must be linked/embedded explicitly on iOS.
if(IOS)
    if(NOT COMMAND qt_add_ios_ffmpeg_libraries)
        message(FATAL_ERROR
            "Qupil iOS requires Qt >= 6.8 for qt_add_ios_ffmpeg_libraries() "
            "when using the prebuilt Qt Multimedia package")
    endif()
    set(QT_NO_FFMPEG_XCODE_EMBED_FRAMEWORKS_CODE_SIGN_ON_COPY ON)
    qt_add_ios_ffmpeg_libraries(qupil)
endif()

target_compile_definitions(qupil PRIVATE
    QUPIL_VERSION="${PROJECT_VERSION}"
)

# Build identity shown in the navigation footer and startup log.  The helper
# runs for every build, so commit/timestamp describe the binary being tested
# rather than the time at which CMake was configured.
set(QUPIL_GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(QUPIL_BUILD_INFO_HEADER "${QUPIL_GENERATED_DIR}/qupil_build_info.h")
add_custom_target(qupil_build_info ALL
    COMMAND "${CMAKE_COMMAND}"
        "-DQUPIL_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
        "-DQUPIL_OUTPUT_FILE=${QUPIL_BUILD_INFO_HEADER}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateBuildInfo.cmake"
    BYPRODUCTS "${QUPIL_BUILD_INFO_HEADER}"
    COMMENT "Generating Qupil build identity"
    VERBATIM
)
add_dependencies(qupil qupil_build_info)
target_include_directories(qupil PRIVATE "${QUPIL_GENERATED_DIR}")

set_target_properties(qupil PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_NAME "Qupil"
    MACOSX_BUNDLE_GUI_IDENTIFIER "org.qupil.app"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
)

if(ANDROID)
    set_target_properties(qupil PROPERTIES
        QT_ANDROID_VERSION_CODE 10528
        QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
        QT_ANDROID_MIN_SDK_VERSION 26
    )
    # QT_ANDROID_PACKAGE_NAME was introduced in Qt 6.8. On older supported
    # Qt releases, the package name falls back to Qt's default unless a
    # custom Android package template is supplied.
    if(Qt6_VERSION VERSION_GREATER_EQUAL 6.8)
        set_target_properties(qupil PROPERTIES
            QT_ANDROID_PACKAGE_NAME "org.qupil.app"
        )
    endif()
endif()

if(IOS)
    set_target_properties(qupil PROPERTIES
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "org.qupil.app"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    )
endif()


# Qupil v27-r8 native application icons
if(ANDROID)
    set_target_properties(qupil PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
        QT_ANDROID_APP_NAME "Qupil"
        QT_ANDROID_APP_ICON "@mipmap/ic_launcher"
    )
endif()

if(IOS)
    set(QUPIL_IOS_ASSET_CATALOG "${CMAKE_CURRENT_SOURCE_DIR}/ios/Assets.xcassets")
    target_sources(qupil PRIVATE "${QUPIL_IOS_ASSET_CATALOG}")
    set_source_files_properties(
        "${QUPIL_IOS_ASSET_CATALOG}"
        PROPERTIES MACOSX_PACKAGE_LOCATION Resources
    )
    set_target_properties(qupil PROPERTIES
        MACOSX_BUNDLE_BUNDLE_NAME "Qupil"
        XCODE_ATTRIBUTE_PRODUCT_NAME "Qupil"
        XCODE_ATTRIBUTE_INFOPLIST_KEY_CFBundleDisplayName "Qupil"
        XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
    )
endif()

if(UNIX AND NOT APPLE AND NOT ANDROID AND NOT IOS)
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/packaging/linux/qupil.desktop"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/applications")
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/assets/icons/qupil.svg"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps")
endif()
# End Qupil v27-r8 native application icons

if(BUILD_TESTING)
    find_package(Python3 QUIET COMPONENTS Interpreter)
    if(Python3_Interpreter_FOUND)
        add_test(NAME source_sanity
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/source_sanity.py")
        add_test(NAME sql_static_smoke
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/sql_static_smoke.py")
        add_test(NAME i18n_static_smoke
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/i18n_static_smoke.py")
        add_test(NAME i18n_catalog_smoke
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/i18n_catalog_smoke.py")
    endif()
endif()

if(NOT ANDROID AND NOT IOS)
    install(TARGETS qupil
        BUNDLE DESTINATION .
        RUNTIME DESTINATION bin
        LIBRARY DESTINATION lib
    )
endif()

# Desktop installs get the Qt runtime, QML modules and plugins (including the
# QSQLITE driver) from Qt's deployment tooling. Android/iOS packaging is done
# by their respective Qt platform deployment steps.
if(NOT ANDROID AND NOT IOS)
    qt_generate_deploy_qml_app_script(
        TARGET qupil
        OUTPUT_SCRIPT qupil_deploy_script
        NO_UNSUPPORTED_PLATFORM_ERROR
    )
    install(SCRIPT ${qupil_deploy_script})
endif()


# Desktop packaging uses CMake/CPack on top of Qt's deployment script. This
# replaces the historic BitRock/InstallBuilder + SVN/SCP release scripts.
if(NOT ANDROID AND NOT IOS)
    set(CPACK_PACKAGE_NAME "Qupil")
    set(CPACK_PACKAGE_VENDOR "Qupil")
    set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
    set(CPACK_PACKAGE_FILE_NAME "Qupil-${PROJECT_VERSION}-${CMAKE_SYSTEM_NAME}")

    if(WIN32)
        set(CPACK_GENERATOR "ZIP")
    elseif(APPLE)
        set(CPACK_GENERATOR "DragNDrop")
    else()
        set(CPACK_GENERATOR "TGZ")
    endif()

    include(CPack)
endif()

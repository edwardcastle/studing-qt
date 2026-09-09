# ---------------------------------------------------------------------------
# DevBoard -- a Qt 6 / C++ learning example.
#
# TEACHING NOTE
# CMake is the supported build system for Qt 6 (qmake still works, but every new
# Qt feature lands in the CMake API first). Three Qt-specific things happen here:
#
#   find_package(Qt6 ...)      finds Qt and defines the Qt6::Core, Qt6::Quick …
#                              imported targets.
#   qt_standard_project_setup() turns on AUTOMOC/AUTOUIC/AUTORCC. AUTOMOC is the
#                              important one: it runs the meta-object compiler
#                              on every header containing Q_OBJECT, which is
#                              what makes signals, slots and properties work.
#   qt_add_qml_module()        declares a QML module: it compiles the .qml files
#                              into the binary, writes the qmldir, and registers
#                              the C++ types marked QML_ELEMENT.
# ---------------------------------------------------------------------------

cmake_minimum_required(VERSION 3.21)

project(DevBoard
    VERSION 1.0.0
    DESCRIPTION "A Qt Quick front end on a plain C++ backend"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Qt Creator and clangd both read this file to understand the project.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

qt_standard_project_setup()

# ---------------------------------------------------------------------------
# The application
# ---------------------------------------------------------------------------

qt_add_executable(devboard
    src/main.cpp

    src/core/Task.h                 src/core/Task.cpp
    src/core/TaskStore.h            src/core/TaskStore.cpp

    src/scanner/ScanTypes.h
    src/scanner/ScanWorker.h        src/scanner/ScanWorker.cpp

    src/models/TaskListModel.h      src/models/TaskListModel.cpp
    src/models/TaskFilterModel.h    src/models/TaskFilterModel.cpp
    src/models/ScanResultModel.h    src/models/ScanResultModel.cpp

    src/app/AppInfo.h               src/app/AppInfo.cpp
    src/app/ScannerController.h     src/app/ScannerController.cpp
)

# Headers are included as "core/TaskStore.h", not "../core/TaskStore.h".
#
# The per-folder entries look redundant, but they are not: qmltyperegistrar
# generates a file that includes every QML_ELEMENT header by its *base name*
# (#include <AppInfo.h>), so each folder holding such a header must be on the
# include path. Without them the build fails with
# "devboard_qmltyperegistrations.cpp: fatal error: AppInfo.h: No such file".
target_include_directories(devboard PRIVATE
    src
    src/app
    src/core
    src/models
    src/scanner
)

set(DEVBOARD_QML_FILES
    src/qml/Main.qml
    src/qml/TasksPage.qml
    src/qml/TaskDelegate.qml
    src/qml/TaskEditorDialog.qml
    src/qml/ScannerPage.qml
    src/qml/AboutPage.qml
    src/qml/StatTile.qml
    src/qml/Theme.qml
)

# Two source-file properties that qt_add_qml_module reads:
#
#   QT_RESOURCE_ALIAS     -- without it every file would end up at
#                            :/qt/qml/DevBoard/src/qml/Main.qml. Flattening the
#                            path keeps the URL in main.cpp short.
#   QT_QML_SINGLETON_TYPE -- marks a `pragma Singleton` file so the generated
#                            qmldir says "singleton Theme". Forget it and you
#                            get the runtime error
#                            "Theme is not a type" / "pragma Singleton used in
#                            a non-singleton type".
foreach(qml_file IN LISTS DEVBOARD_QML_FILES)
    get_filename_component(qml_name "${qml_file}" NAME)
    set_source_files_properties("${qml_file}" PROPERTIES QT_RESOURCE_ALIAS "${qml_name}")
endforeach()

set_source_files_properties(src/qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# RESOURCE_PREFIX is stated explicitly because the default changed: Qt 6.5 and
# newer use "/qt/qml", older versions use "/". Pinning it here means the URL in
# main.cpp (qrc:/qt/qml/DevBoard/Main.qml) is correct on every Qt 6 version.
qt_add_qml_module(devboard
    URI DevBoard
    VERSION 1.0
    RESOURCE_PREFIX "/qt/qml"
    QML_FILES ${DEVBOARD_QML_FILES}

    # DEPENDENCIES writes "depends" lines into the generated qmldir. It is not
    # needed at runtime (the engine already links these modules), but it is what
    # lets qmllint and Qt Creator resolve the *base classes* of our C++ types --
    # without it they report "QAbstractItemModel was not found" and then give up
    # on TaskListModel and TaskFilterModel.
    DEPENDENCIES
        QtQuick
        QtQml.Models
)

target_link_libraries(devboard PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

# Warnings are free bug reports. Turn them on and keep the output clean.
if(MSVC)
    target_compile_options(devboard PRIVATE /W4 /permissive-)
else()
    target_compile_options(devboard PRIVATE -Wall -Wextra -Wpedantic)
endif()

# ---------------------------------------------------------------------------
# Tests -- built only when you ask for them:  cmake -DDEVBOARD_BUILD_TESTS=ON ..
# ---------------------------------------------------------------------------

option(DEVBOARD_BUILD_TESTS "Build the unit tests" ON)

if(DEVBOARD_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

# ---------------------------------------------------------------------------
# Installation (so `cmake --install build` produces something runnable)
# ---------------------------------------------------------------------------

include(GNUInstallDirs)
install(TARGETS devboard
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    BUNDLE  DESTINATION .
)

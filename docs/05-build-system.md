# 5 — CMake, moc and QML modules

## 5.1 The three code generators

A Qt build is a normal C++ build plus three generators that CMake runs for you.
`qt_standard_project_setup()` turns them all on.

| Tool | Input | Output | Why |
|---|---|---|---|
| **moc** (meta-object compiler) | headers containing `Q_OBJECT`, `Q_GADGET`, `Q_NAMESPACE` | `moc_Foo.cpp` | implements signals, the `QMetaObject`, property access, `Q_ENUM` reflection |
| **rcc** (resource compiler) | `.qrc` files, `QML_FILES` | `qrc_*.cpp` | embeds files in the executable |
| **qmltyperegistrar** | moc's JSON output | `*_qmltyperegistrations.cpp` | registers `QML_ELEMENT` classes with the QML engine |

C++ has no reflection, and Qt needs some. moc is how Qt gets it. When you write

```cpp
signals:
    void countsChanged();
```

you never write the body — moc does, and it walks the connection list and
invokes every connected slot.

**Practical consequence:** a header with `Q_OBJECT` must be visible to AUTOMOC.
Listing headers in your target's sources (as this project does) is the reliable
way. If moc does not run, you get `undefined reference to vtable for TaskListModel`.

## 5.2 Walking through this project's CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.21)
project(DevBoard VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)          # -std=c++17, not -std=gnu++17
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)  # clangd / Qt Creator read this
```

```cmake
find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)
```

Each component becomes an imported target (`Qt6::Quick`) that carries its own
include paths, defines and dependencies. List only what you use: every extra
component is a library your users must ship.

```cmake
qt_standard_project_setup()
```

Turns on `CMAKE_AUTOMOC`, `AUTOUIC`, `AUTORCC` and sets sensible output
directories. One line instead of six.

```cmake
qt_add_executable(devboard  src/main.cpp  src/core/Task.h src/core/Task.cpp  … )
```

`qt_add_executable`, not plain `add_executable`: it handles platform details
(Windows `WIN32` subsystem, Android/iOS packaging, static-plugin import).

```cmake
target_include_directories(devboard PRIVATE src src/app src/core src/models src/scanner)
```

`src` is there so headers can be included as `"core/TaskStore.h"`. The
per-folder entries look redundant but are not: qmltyperegistrar generates a file
that includes every `QML_ELEMENT` header **by base name** (`#include <AppInfo.h>`),
so each folder holding such a header must be on the include path. Leave them out
and the build fails with
`devboard_qmltyperegistrations.cpp: fatal error: AppInfo.h: No such file or directory`.

## 5.3 The QML module

```cmake
qt_add_qml_module(devboard
    URI DevBoard
    VERSION 1.0
    RESOURCE_PREFIX "/qt/qml"
    QML_FILES ${DEVBOARD_QML_FILES}
)
```

This single call does four things:

1. compiles every `.qml` into the executable as a resource under
   `:/qt/qml/DevBoard/`;
2. runs **qmlcachegen**, which compiles the QML to bytecode ahead of time (faster
   startup, and syntax errors become *build* errors);
3. generates a `qmldir` listing every type in the module;
4. generates the registration code for the C++ types marked `QML_ELEMENT`.

`RESOURCE_PREFIX` is stated explicitly because the default changed: Qt 6.5+ uses
`/qt/qml`, older versions use `/`. Pinning it means the URL in `main.cpp` is
right on every Qt 6 version:

```cpp
engine.load(QUrl(QStringLiteral("qrc:/qt/qml/DevBoard/Main.qml")));
```

On Qt 6.5 and newer you can write `engine.loadFromModule("DevBoard", "Main")`
instead; this project keeps the explicit URL so it also builds on 6.4.

### Two source-file properties

```cmake
foreach(qml_file IN LISTS DEVBOARD_QML_FILES)
    get_filename_component(qml_name "${qml_file}" NAME)
    set_source_files_properties("${qml_file}" PROPERTIES QT_RESOURCE_ALIAS "${qml_name}")
endforeach()

set_source_files_properties(src/qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
```

* **`QT_RESOURCE_ALIAS`** — without it the files land at
  `:/qt/qml/DevBoard/src/qml/Main.qml`, mirroring the source tree. Flattening
  keeps the URL short.
* **`QT_QML_SINGLETON_TYPE`** — marks a `pragma Singleton` file so the generated
  `qmldir` says `singleton Theme 1.0 Theme.qml`. Forget it and you get
  *"Theme is not a type"* or *"pragma Singleton used in a non-singleton type"*.

You can inspect the results after a build:

```bash
cat build/DevBoard/qmldir
cat build/.rcc/devboard_raw_qml_0.qrc
```

### A QML file must import its own module to see C++ types

`Theme.qml` lives inside the DevBoard module and still needs

```qml
import DevBoard
```

to use the `Priority` enum namespace. Sibling `.qml` types are found
automatically; C++ types registered under the URI are not.

## 5.4 Build types

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug        # -g, assertions
cmake -S . -B build-rel -G Ninja -DCMAKE_BUILD_TYPE=Release  # -O3, -DNDEBUG
cmake --build build -j
```

Ninja is worth installing; it is noticeably faster than Make for incremental
builds. Keep separate build directories rather than reconfiguring one in place.

`Debug` also defines `QT_DEBUG`, which `AppInfo::buildType()` reports.

## 5.5 Warnings

```cmake
if(MSVC)
    target_compile_options(devboard PRIVATE /W4 /permissive-)
else()
    target_compile_options(devboard PRIVATE -Wall -Wextra -Wpedantic)
endif()
```

This project builds clean with those on. Keep it that way: a warning you have
decided to ignore is a warning you will not notice when it becomes real.

Useful additions once you are comfortable:

```cmake
target_compile_definitions(devboard PRIVATE
    QT_NO_CAST_FROM_ASCII        # forces QStringLiteral / QLatin1String
    QT_DISABLE_DEPRECATED_UP_TO=0x060400
)
```

## 5.6 Static analysis for QML

```bash
cmake --build build --target all_qmllint     # or: qmllint src/qml/*.qml
```

`qmllint` catches unqualified property access, missing imports and bindings that
can never resolve — the QML equivalent of compiler warnings. This project is
clean; run it before you commit.

Two things were needed to get there, and both are worth knowing:

* **`DEPENDENCIES QtQuick QtQml.Models`** in `qt_add_qml_module`. It writes
  `depends` lines into the generated `qmldir`. The runtime does not need them
  (the modules are already linked), but without them the linter cannot resolve
  the *base classes* of our C++ types: it reports
  `QAbstractItemModel was not found` and then gives up on `TaskListModel` and
  `TaskFilterModel` entirely.
* **No unqualified access in delegates.** A delegate is its own scope, so
  `width: listView.width` reaches out to an id it should not assume. Use the
  attached property instead:

  ```qml
  delegate: TaskDelegate { width: ListView.view.width }
  ```

  The same rule is why `StatTile.qml` gives its root an `id` and writes
  `text: tile.caption` rather than bare `caption`.

## 5.7 Growing the project

When `src/` gets big, split it into libraries:

```cmake
qt_add_library(devboard_core STATIC src/core/Task.cpp src/core/TaskStore.cpp)
target_link_libraries(devboard_core PUBLIC Qt6::Core)

qt_add_qml_module(devboard_ui STATIC URI DevBoard VERSION 1.0 SOURCES … QML_FILES …)

qt_add_executable(devboard src/main.cpp)
target_link_libraries(devboard PRIVATE devboard_core devboard_uiplugin)
```

The tests here compile the production `.cpp` files directly instead, because at
this size that is simpler and there is nothing to explain. Once you have a
library, tests link it.

## 5.8 Shipping

| Platform | Tool |
|---|---|
| Windows | `windeployqt build/devboard.exe` |
| macOS | `macdeployqt devboard.app -dmg` |
| Linux | `linuxdeployqt`, or an AppImage / Flatpak |
| Any | `cmake --install build --prefix /where` (this project defines `install()`) |

Deploying a QML app means shipping the QML plugins too — the deploy tools scan
your `.qml` files to find them, which is another reason to let
`qt_add_qml_module` manage them.

Next: [06-testing.md](06-testing.md).

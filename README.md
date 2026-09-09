# DevBoard — learning Qt 6 and C++ by reading a real application

This repository is a small but complete desktop application whose only purpose
is to be **read**. Every file is commented with *why* it is written the way it
is, and the `docs/` folder walks you through the whole thing in order.

The application itself does two things:

| Tab | What it does | What it teaches |
|---|---|---|
| **Tasks** | A task list: add, edit, delete, complete, search, sort, auto-save to JSON | value types, `QAbstractListModel`, `QSortFilterProxyModel`, `Q_PROPERTY`, `Q_INVOKABLE`, persistence |
| **Scanner** | Walks a folder in the background and shows a size breakdown per file extension | `QThread` + worker objects, queued signals, cancellation, progress reporting |
| **How it works** | An in-app summary of the architecture | `Repeater`, layouts, `ScrollView` |

Everything you see on screen is QML. Everything that decides *anything* is C++.

```
┌──────────────────────────────────────────────┐
│  QML  (src/qml)          what the user sees  │
│    ▲ bindings to Q_PROPERTY                  │
│    │ calls to Q_INVOKABLE                    │
├──────────────────────────────────────────────┤
│  Models & controllers (src/models, src/app)  │
│    ▲ plain C++ calls                         │
├──────────────────────────────────────────────┤
│  Core logic (src/core, src/scanner)          │
│    no GUI classes at all — fully unit tested │
└──────────────────────────────────────────────┘
```

---

## 1. Build and run

You need **Qt 6.4 or newer**, **CMake 3.21+** and a C++17 compiler.

<details>
<summary>Installing Qt</summary>

* **Ubuntu / Debian**
  ```bash
  sudo apt install cmake ninja-build g++ \
       qt6-base-dev qt6-declarative-dev \
       qml6-module-qtquick qml6-module-qtquick-controls \
       qml6-module-qtquick-layouts qml6-module-qtquick-window \
       qml6-module-qtquick-templates qml6-module-qtquick-dialogs \
       qml6-module-qtqml-models
  ```
* **Fedora**: `sudo dnf install cmake ninja-build gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel`
* **macOS / Windows / anything else**: install the
  [Qt Online Installer](https://www.qt.io/download-qt-installer) and tick
  *Qt 6.x → Desktop*. Then pass the path to CMake:
  `-DCMAKE_PREFIX_PATH=$HOME/Qt/6.8.0/gcc_64`
</details>

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
./build/devboard
```

Run the tests and the QML linter — both are clean, keep them that way:

```bash
ctest --test-dir build --output-on-failure
cmake --build build --target all_qmllint
```

Opening the top-level `CMakeLists.txt` in **Qt Creator** also works and gives
you the QML debugger, the profiler and code completion for both languages.

---

## 2. Read it in this order

| # | File | Topic |
|---|---|---|
| 0 | [docs/00-start-here.md](docs/00-start-here.md) | how to use this repository, and the mental model |
| 1 | [docs/01-architecture.md](docs/01-architecture.md) | the layers, and why the dependencies point one way |
| 2 | [docs/02-cpp-and-qml.md](docs/02-cpp-and-qml.md) | the bridge: properties, invokables, signals, ownership |
| 3 | [docs/03-models.md](docs/03-models.md) | `QAbstractListModel`, roles, delegates, proxy models |
| 4 | [docs/04-threading.md](docs/04-threading.md) | keeping the UI responsive, the right way |
| 5 | [docs/05-build-system.md](docs/05-build-system.md) | CMake, moc, QML modules, resources |
| 6 | [docs/06-testing.md](docs/06-testing.md) | Qt Test, `QSignalSpy`, `QAbstractItemModelTester` |
| 7 | [docs/07-cpp-notes.md](docs/07-cpp-notes.md) | the C++ idioms used here, explained |
| 8 | [docs/08-exercises.md](docs/08-exercises.md) | graded exercises, from 10 minutes to a weekend |
| 9 | [docs/09-troubleshooting.md](docs/09-troubleshooting.md) | the errors you *will* hit, and what they mean |

---

## 3. Project map

```
CMakeLists.txt              build definition, heavily commented
src/
  main.cpp                  application object, metatypes, QML engine
  core/                     ── no Qt GUI classes, no QML ──
    Task.h/.cpp             the value type + JSON
    TaskStore.h/.cpp        the rules: ids, validation, counting, files
  scanner/
    ScanTypes.h             values sent across the thread boundary
    ScanWorker.h/.cpp       the blocking directory walk
  models/                   ── adapts C++ data to Qt's model/view protocol ──
    TaskListModel.h/.cpp    rows, roles, commands, auto-save
    TaskFilterModel.h/.cpp  search / filter / sort proxy
    ScanResultModel.h/.cpp  a second, minimal model
  app/                      ── glue exposed to QML ──
    AppInfo.h/.cpp          a QML singleton written in C++
    ScannerController.*     owns the worker thread, publishes progress
  qml/
    Main.qml                window, tabs, the C++ objects
    TasksPage.qml           toolbar + list
    TaskDelegate.qml        one row
    TaskEditorDialog.qml    new / edit dialog
    ScannerPage.qml         progress + results
    AboutPage.qml           in-app explanation
    StatTile.qml            tiny reusable component
    Theme.qml               QML singleton: colours and metrics
tests/
  tst_taskstore.cpp         pure logic
  tst_tasklistmodel.cpp     model contract + signals + proxy
  tst_scanworker.cpp        threaded code
docs/                       the written course
```

---

## 4. The shortest possible summary of Qt

* A Qt program is an **event loop**. `main()` sets things up and calls
  `exec()`; from then on everything happens in reaction to events.
* `QObject` is the base class that gives you **signals, slots, properties and
  parent/child ownership**. The `Q_OBJECT` macro is what makes it work, and
  **moc** (the meta-object compiler, run automatically by CMake) generates the
  code behind it.
* **Signals and slots** are how objects talk without knowing about each other.
  Across threads, Qt turns a signal into a posted event automatically.
* **Models** hold data, **views** display it, **delegates** decide what one item
  looks like. Views never own data.
* **QML** describes the interface declaratively; a *binding* like
  `text: model.openCount` re-evaluates itself whenever anything it reads
  changes.

Everything else is detail — and all of that detail is in `docs/`.

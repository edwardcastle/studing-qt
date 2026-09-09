# 9 — Errors you will meet, and what they mean

A reference page. Skim it now; come back when something breaks.

---

## Build errors

### `undefined reference to vtable for MyClass`

moc did not run on that class.

* Is `Q_OBJECT` inside the class body, in a **header**?
* Is that header listed in the target's sources? (This project lists every
  `.h` in `qt_add_executable` for exactly this reason.)
* Defining a `Q_OBJECT` class inside a `.cpp`? Add `#include "myfile.moc"` at
  the bottom — that is what the test files do.
* Still stuck: `rm -rf build` and reconfigure. AUTOMOC caches aggressively.

### `fatal error: AppInfo.h: No such file or directory` in `*_qmltyperegistrations.cpp`

qmltyperegistrar includes `QML_ELEMENT` headers by **base name**. Add the folder
containing the header to `target_include_directories`.

### `No matching function for call to 'compare_helper'`

`QCOMPARE` found a free `toString()` in the compared type's namespace by ADL and
tried to use it for failure output. Rename yours (this project's
`Priority::label()` used to be `toString()`), or compare the underlying type:
`QCOMPARE(int(a), int(b))`.

### `error: 'Q_OBJECT' does not name a type` / `Q_NAMESPACE` errors

Missing `#include <QObject>`, or the macro is at the wrong scope.
`Q_NAMESPACE`, `Q_DECLARE_METATYPE` and `Q_ENUM_NS` all have specific placement
rules — `Q_DECLARE_METATYPE` in particular must be at **global** scope, outside
every namespace.

### `Cannot assign to non-existent property "xyz"` at build time

qmlcachegen compiles your QML at build time, so QML errors are now build errors.
This is a feature. Check spelling and imports.

---

## Runtime: QML

### `QQmlApplicationEngine failed to load component` / `qrc:/…: No such file or directory`

The URL does not match where `qt_add_qml_module` put the file. Check:

```bash
cat build/DevBoard/qmldir
cat build/.rcc/devboard_raw_qml_0.qrc
```

Qt 6.5+ defaults to the `/qt/qml` prefix; older versions use `/`. This project
pins it with `RESOURCE_PREFIX "/qt/qml"`.

### `module "DevBoard" is not installed`

The QML module URI does not match the `import`, or the engine has no import path
for it. With `qt_add_qml_module` in the same target as `main()`, this usually
means a typo in `URI`.

### `ReferenceError: Priority is not defined`

A QML file in your own module still has to `import DevBoard` to see C++ types
registered under that URI. Only sibling `.qml` types are found automatically.
(`Theme.qml` has a comment about exactly this.)

### `Theme is not a type` / `pragma Singleton used in a non-singleton type`

The file has `pragma Singleton` but CMake was not told:

```cmake
set_source_files_properties(src/qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
```

### `TypeError: Cannot read property 'x' of undefined`

A binding ran before the object existed. Guard it (`model ? model.count : 0`),
or move the work into `Component.onCompleted`.

### `QML …: Binding loop detected for property "height"`

Two bindings depend on each other — usually a delegate whose height depends on
its parent while the parent's height depends on the children. Set the delegate's
**width** from the view and let its height come from `implicitHeight`.

### The list is empty but the model has rows

* Is `model:` pointing at the right object (proxy vs source)?
* Does the delegate have a non-zero width and height?
* Do the `required property` names match `roleNames()` exactly? They are
  case-sensitive.

### A property does not update in the UI

The `NOTIFY` signal is missing, or the setter returns early because it thinks
nothing changed, or QML overwrote the binding with a direct assignment
(`label.text = "…"` destroys the binding on `text`).

---

## Runtime: models

### `QAbstractItemModelTester` warnings, or random crashes in the view

A `begin…`/`end…` pair is missing or mismatched. Remember the ranges are
**inclusive**: appending one row to a 3-row model is `(3, 3)`, not `(3, 4)`.

### Rows shift or the wrong task is deleted

Proxy row used where a source row was expected. Convert with
`TaskFilterModel::sourceRow()` (or `mapToSource()` in C++).

### The view flickers or loses the scroll position

You called `beginResetModel()`/`endResetModel()` where an insert or remove would
have done.

---

## Runtime: threads

### `QObject::connect: Cannot queue arguments of type 'ScanSummary'`

The type is not registered. Add `Q_DECLARE_METATYPE` in the header and
`qRegisterMetaType<T>()` in `main()`. The slot is silently never called until
you do.

### `QThread: Destroyed while thread is still running` (then abort)

Missing `quit()` **and** `wait()` in the owner's destructor.

### `QObject: Cannot create children for a parent that is in a different thread`

You created an object on the wrong thread. Objects must be created by the thread
that will own them, or moved with `moveToThread()` before use.

### `QObject::moveToThread: Cannot move objects with a parent`

Construct the worker with `new ScanWorker` — no parent argument.

### `Cannot send events to objects owned by a different thread`

Something touched a GUI object from a worker. Send a signal instead.

### The worker never stops when you press Cancel

The flag is not `std::atomic`, or the loop does not check it, or you tried to
cancel through a queued signal that cannot be delivered while the loop runs.

---

## qmllint

### `QAbstractItemModel was not found. Did you add all import paths?` / `Type TaskListModel is used but it is not resolved`

The linter cannot see the base classes of your C++ types. Declare the modules
they come from in `qt_add_qml_module`:

```cmake
DEPENDENCIES
    QtQuick
    QtQml.Models
```

Also make sure the QML modules themselves are installed — on Debian/Ubuntu,
`qml6-module-qtqml-models` is a separate package from the development headers.

### `Unqualified access`

A binding reads a name from an enclosing scope. Inside a delegate use
`ListView.view.width` instead of an outer id; inside a component give the root
an `id` and qualify (`tile.caption`).

### `qmllint directive on unknown category "…"`

A comment of yours starts with the word `qmllint`, and the linter tried to read
it as a directive such as `// qmllint disable unqualified`. Reword the comment.

---

## Diagnostics worth knowing

```bash
# Log every QML warning with more context
export QT_LOGGING_RULES="qt.qml.binding.removal.info=true;js.debug=true"

# Which QML files/plugins are actually being loaded
export QML_IMPORT_TRACE=1

# Run without a display (CI, containers)
export QT_QPA_PLATFORM=offscreen

# Try a different Controls style without touching the code
export QT_QUICK_CONTROLS_STYLE=Material

# Static analysis
qmllint src/qml/*.qml
qmlformat -i src/qml/*.qml
```

In C++, `qDebug() << object;` prints a useful summary for most Qt types, and
`qDebug() << QThread::currentThread();` answers "which thread am I on?".

For QML profiling and step-debugging, open the project in **Qt Creator** —
*Analyze → QML Profiler* shows you exactly which binding is re-evaluating 400
times a second.

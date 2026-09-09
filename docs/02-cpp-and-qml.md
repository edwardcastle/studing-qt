# 2 — The bridge between C++ and QML

This is the chapter that matters most. Everything a QML file can see about a
C++ object is something the C++ side deliberately published. There are exactly
four mechanisms.

---

## 2.1 `Q_PROPERTY` — values QML can bind to

```cpp
// src/models/TaskListModel.h
Q_PROPERTY(int openCount READ openCount NOTIFY countsChanged)
```

```qml
// Main.qml — re-evaluates itself whenever countsChanged() is emitted
TabButton { text: qsTr("Tasks (%1)").arg(taskModel.openCount) }
```

The parts:

| Keyword | Meaning |
|---|---|
| `READ getter` | how to read it |
| `WRITE setter` | optional; without it the property is read-only from QML |
| `NOTIFY signal` | **emitted when the value changes** — this is what makes bindings live |
| `CONSTANT` | never changes; no NOTIFY needed (e.g. `storagePath`) |
| `MEMBER field` | shortcut when you want no getter at all |

### The one rule you must not break

**A `WRITE` setter must not emit its `NOTIFY` signal when the value did not
actually change.** Every setter in this project starts the same way:

```cpp
void TaskFilterModel::setSearchText(const QString &text)
{
    if (m_searchText == text)
        return;                 // ← the guard
    m_searchText = text;
    invalidateFilter();
    emit searchTextChanged();
}
```

Without the guard you get redundant repaints at best, and infinite loops at
worst (QML writes the property → you emit → QML re-evaluates a binding → it
writes the property again → …).

### Several properties can share one NOTIFY signal

`count`, `openCount`, `doneCount` and `overdueCount` all use `countsChanged`.
That is legal and often the honest thing to do: they all change together. The
cost is that QML re-evaluates all four bindings when any one changes — for four
integers, irrelevant.

### Exposing a whole object

```cpp
Q_PROPERTY(devboard::ScanResultModel *results READ results CONSTANT)
```

```qml
ListView { model: root.controller.results }
```

This is how QML gets a model that C++ owns. Note the fully-qualified type name
in the macro: moc does not know your `using namespace` declarations.

---

## 2.2 `Q_INVOKABLE` — functions QML can call

```cpp
Q_INVOKABLE int addTask(const QString &title,
                        const QString &notes = QString(),
                        int priority = Priority::Normal,
                        const QDateTime &dueDate = QDateTime());
```

```qml
taskModel.addTask(titleField.text, notesField.text, priorityBox.currentIndex, dueDate);
```

* Public **slots** are callable from QML too. Use `Q_INVOKABLE` for "do this"
  and `slots` for "react to that"; the distinction is for humans, not the
  compiler.
* Argument and return types must be types the meta-object system knows:
  `int`, `bool`, `QString`, `QDateTime`, `QVariantMap`, `QVariantList`,
  `QObject*`, or anything you registered with `Q_DECLARE_METATYPE`.
* `QVariantMap` arrives in QML as a plain JavaScript object — that is what
  `TaskListModel::get()` returns and how `TaskEditorDialog` fills its fields:

  ```qml
  const task = taskModel.get(row);
  titleField.text = task.title;
  ```

* Default arguments work; QML simply omits the trailing ones.

---

## 2.3 Signals — C++ telling QML something happened

Any signal `somethingChanged()` on a C++ object can be handled in QML as
`onSomethingChanged:`. In practice you rarely need this for *values* — that is
what properties and bindings are for. Use signals for **events**:

```qml
ScannerController {
    id: scanner
    onRunningChanged: if (!running) console.log("scan finished")
}
```

`Connections` does the same for an object you did not declare inline:

```qml
Connections {
    target: scanner
    function onRunningChanged() { /* … */ }
}
```

(The `function onXxx()` spelling is the Qt 6 one. The old `onXxx: { }` form
inside `Connections` still works but is deprecated.)

---

## 2.4 Registration — how a C++ class becomes a QML type

Qt 6 does this with macros in the header plus one CMake call. Three variants,
all three used in this project:

### a) Instantiable type — `QML_ELEMENT`

```cpp
// src/models/TaskListModel.h
class TaskListModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    // …
};
```

```qml
import DevBoard
TaskListModel { id: taskModel }
```

The type name in QML is the C++ class name. `QML_NAMED_ELEMENT(OtherName)` if
you want a different one.

### b) Singleton — `QML_ELEMENT` + `QML_SINGLETON`

```cpp
// src/app/AppInfo.h
class AppInfo : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // …
};
```

```qml
Label { text: AppInfo.qtVersion }
```

One instance, created by the engine on first use. Good for
application-wide read-only facts and small helper functions. **Not** a licence
to build a god object: singletons are as awkward to test in QML as anywhere
else.

### c) Enum namespace

```cpp
// src/core/Task.h
namespace Priority {
Q_NAMESPACE
QML_ELEMENT
enum Level { Low = 0, Normal = 1, High = 2 };
Q_ENUM_NS(Level)
}
```

```qml
color: level === Priority.High ? Theme.danger : Theme.accent
```

`Q_ENUM` (inside a class) and `Q_ENUM_NS` (inside a namespace) also give you
`QMetaEnum`, so `QVariant(Priority::High).toString()` prints `"High"` instead of
`"2"` — very useful in debug output.

### The CMake half

```cmake
qt_add_qml_module(devboard
    URI DevBoard
    VERSION 1.0
    RESOURCE_PREFIX "/qt/qml"
    QML_FILES ${DEVBOARD_QML_FILES}
)
```

This one call: scans the target's moc output for `QML_ELEMENT`, generates the
registration code, generates a `qmldir`, and compiles the `.qml` files into the
binary as resources. Details in [05-build-system.md](05-build-system.md).

### The old way, for when you meet it

```cpp
engine.rootContext()->setContextProperty("taskModel", &model);   // Qt 5 style
```

It still works, and you will see it in every tutorial written before 2021.
Avoid it in new code: the type is invisible to tooling (no completion, no
`qmllint`), the object is global to every QML file, and lifetime is up to you.

---

## 2.5 Type conversions you will actually hit

| C++ | QML / JavaScript |
|---|---|
| `int`, `double`, `bool` | number, boolean |
| `QString` | string |
| `QDateTime`, `QDate` | `Date` |
| `QUrl` | url — `Qt.resolvedUrl()`, `url.toString()` |
| `QVariantMap` | plain object `{ }` |
| `QVariantList`, `QList<T>` | array |
| `QObject *` | object with its properties/methods |
| `std::vector<T>`, custom struct | **nothing** — not visible until you convert or register it |

That last row is why `TaskListModel::get()` returns a `QVariantMap` and why
`ScanSummary` is turned into a model rather than handed to QML directly.

An invalid `QDateTime` reaches QML as an invalid `Date`. That is awkward to
test in JavaScript, so `TaskListModel` also exposes a `dueDateLabel` role that
is simply empty when there is no date — the dialog checks that instead. Pushing
formatting and edge cases into C++ keeps the QML honest and simple.

---

## 2.6 A checklist for adding a new field end to end

Say you want a `tags` field. The full path:

1. `src/core/Task.h` — add `QStringList tags;`
2. `src/core/Task.cpp` — read and write it in `toJson()` / `fromJson()`, and add
   it to `operator==`
3. `src/models/TaskListModel.h` — add `TagsRole` to the `Roles` enum
4. `src/models/TaskListModel.cpp` — handle it in `data()`, `setData()` and
   `roleNames()`
5. `src/models/TaskFilterModel.cpp` — search tags too, if you want
6. `src/qml/TaskDelegate.qml` — `required property var tags` and something to
   draw them
7. `src/qml/TaskEditorDialog.qml` — a field to edit them
8. `tests/` — a test for the JSON round trip and one for the new role

Doing this once, by hand, teaches more than reading the rest of this document.
It is exercise 3 in [08-exercises.md](08-exercises.md).

Next: [03-models.md](03-models.md).

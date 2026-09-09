# 1 — Architecture

## The layers

```
        ┌─────────────────────────────────────────────────────┐
        │ src/qml            Main.qml, TasksPage.qml, …        │
        │                    appearance and interaction only   │
        └───────────────▲─────────────────────┬────────────────┘
      bindings read      │                     │  calls to Q_INVOKABLE
      Q_PROPERTY values  │                     ▼
        ┌───────────────┴─────────────────────────────────────┐
        │ src/models      TaskListModel, TaskFilterModel,      │
        │                 ScanResultModel                      │
        │ src/app         ScannerController, AppInfo           │
        │                 adapters: they translate, they do    │
        │                 not decide                           │
        └───────────────▲─────────────────────┬────────────────┘
              return     │                     │  plain function calls
              values     │                     ▼
        ┌───────────────┴─────────────────────────────────────┐
        │ src/core        Task, TaskStore                      │
        │ src/scanner     ScanWorker, ScanTypes                │
        │                 the rules. No QML, no widgets.       │
        └─────────────────────────────────────────────────────┘
```

**Dependencies only point downwards.** `TaskStore` has never heard of
`TaskListModel`; `TaskListModel` has never heard of `TasksPage.qml`. When a
lower layer needs to tell an upper layer something, it returns a value or emits
a signal — it never calls up.

Check it yourself:

```bash
grep -rn "include <Q" src/core/     # QtCore only: QString, QDateTime, QJson…
grep -rn "qml\|Qml\|Quick" src/core/  # nothing
```

## Why bother, in a program this small?

Three concrete payoffs, all visible in this repository:

**1. Tests run in milliseconds.** `tests/tst_taskstore.cpp` never creates a
window, an application object or a QML engine. The whole suite finishes in about
20 ms, so you can run it after every single edit.

**2. You can change the UI without touching the rules.** Everything in
`src/qml` could be deleted and rewritten in Qt Widgets, and `src/core` would not
change by one character. (`TaskListModel` would not change either — Widgets
views speak the same model protocol.)

**3. Bugs have one home.** "Blank titles get rejected" is one rule, implemented
once, in `TaskStore::addTask()`. The dialog *also* greys out its Save button,
but that is a convenience, not the rule. If the two ever disagree, the store
wins — and there is a test for it.

## The four kinds of object in this project

| Kind | Example | Rule of thumb |
|---|---|---|
| **Value** | `Task`, `ExtensionStat`, `ScanSummary` | plain struct, copyable, no `QObject`. Data that gets stored, copied, compared, sent between threads. |
| **Logic** | `TaskStore` | plain C++ class. Owns data and rules. No signals — it just returns whether something happened. |
| **Model** | `TaskListModel`, `ScanResultModel` | `QObject` subclass implementing Qt's model protocol. Adapts *values* for *views*. |
| **Controller** | `ScannerController` | `QObject` that owns a resource (a thread) and publishes its state as properties. Contains no algorithm. |

The mistake almost everyone makes at the start is to reach for `QObject` for
everything, including individual rows. Do not. A `QObject` is not copyable,
costs an allocation plus meta-object bookkeeping, and drags lifetime questions
into what should be plain data.

## Ownership: who deletes what

Qt mixes three ownership styles, and knowing which one applies is most of
avoiding crashes.

**Parent/child.** `new QTimer(this)` — the parent deletes the child. Used all
over Qt. In this project, `ScanResultModel m_results` is a plain member of
`ScannerController`, which is even simpler: it dies with its owner.

**QML engine ownership.** An object *created in QML*
(`TaskListModel { id: taskModel }` in `Main.qml`) belongs to the QML engine and
is destroyed with the component that created it. That is why `Main.qml` can
declare the models without any cleanup code.

**Objects returned to QML from C++.** `ScannerController::results()` returns a
pointer to a member. QML must not delete it. Because the property is declared
`CONSTANT` and the object has a C++ owner, the engine treats it as
C++-owned and leaves it alone. (If you ever return a freshly `new`-ed object
from a `Q_INVOKABLE`, QML takes ownership of it — a classic source of
double-free bugs. `QQmlEngine::setObjectOwnership()` lets you state the rule
explicitly.)

**Thread-owned.** `ScanWorker` is created with **no parent**, moved to
`m_thread`, and deleted by `deleteLater()` when the thread finishes. Never
`delete` an object that lives on another thread from the outside.

## Where state lives

| State | Lives in | Why |
|---|---|---|
| the tasks themselves | `TaskStore` | one owner, testable |
| "which rows are visible" | `TaskFilterModel` | a view concern, not data |
| "is a scan running" | `ScannerController` | the controller owns the thread |
| "is the editor dialog open" | `TaskEditorDialog.qml` | transient view state |
| the dialog's draft values | `TaskEditorDialog.qml` | thrown away on Cancel |
| colours and spacing | `Theme.qml` | one place to restyle |

Note the pattern: QML keeps only what is *temporary and local*. Everything with
a lifetime longer than a mouse click lives in C++.

Next: [02-cpp-and-qml.md](02-cpp-and-qml.md).

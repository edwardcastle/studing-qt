# 8 — Exercises

Work through these in order. Each one names the files you will touch and what
"done" looks like. Run `ctest --test-dir build --output-on-failure` after every
change.

---

## Warm-up: break things on purpose (15 minutes)

The fastest way to understand a mechanism is to watch it fail. Do each of these,
observe, then undo it.

| Break this | Where | What you should see |
|---|---|---|
| Delete `NOTIFY countsChanged` from the `openCount` property | `TaskListModel.h` | the tab label stops updating; the value is still correct when the window is rebuilt |
| Remove `beginInsertRows`/`endInsertRows` around the store call | `TaskListModel::addTask` | new tasks do not appear, or the view corrupts; the model tester complains |
| Rename the `"title"` role to `"name"` | `TaskListModel::roleNames` | `TaskDelegate.qml` fails at startup — because it uses `required property` |
| Comment out `sort(0)` in the constructor | `TaskFilterModel.cpp` | the sort combo box does nothing |
| Replace `emit scanRequested(path)` with `m_worker->scan(path)` | `ScannerController::start` | the window freezes for the whole scan |
| Remove `m_thread.wait()` | `~ScannerController` | `QThread: Destroyed while thread is still running` on exit |
| Change `std::atomic_bool` to `bool` | `ScanWorker.h` | still "works" — which is the point: data races do not announce themselves. Try a Release build, or `-fsanitize=thread` |

---

## 1. A data-driven test (20 minutes) — *easy*

**Files:** `tests/tst_taskstore.cpp`

Add `priorityRoundTrip()` and `priorityRoundTrip_data()` verifying that
`Priority::label()` and `Priority::fromLabel()` are inverses for all three
levels, plus that unknown text maps to `Normal`. The skeleton is in
[06-testing.md](06-testing.md) §6.6.

**Done when:** `./build/tests/tst_taskstore` shows one `PASS` line per row.

---

## 2. Validate before announcing (30 minutes) — *easy*

**Files:** `src/models/TaskListModel.cpp`, `tests/tst_tasklistmodel.cpp`

`addTask()` currently announces an insertion and then retracts it if the store
rejects the task. Restructure it so a blank title is rejected *before*
`beginInsertRows()` is called.

**Done when:** `addTaskRejectsBlankTitle` passes with
`QCOMPARE(insertSpy.count(), 0)` instead of comparing insert and remove counts.

---

## 3. Add a field, end to end (1–2 hours) — *medium*

**Files:** eight of them — the checklist is in
[02-cpp-and-qml.md](02-cpp-and-qml.md) §2.6.

Add `QStringList tags` to `Task`. It must be stored, serialised, searchable,
visible in the delegate and editable in the dialog.

**Done when:**
* a JSON round-trip test covers tags;
* `TaskFilterModel` matches on them;
* the delegate shows them as small pills;
* an old `tasks.json` without a `tags` key still loads.

That last point is the real lesson: file formats have to survive their own
history.

---

## 4. Undo (2–3 hours) — *medium*

**Files:** new `src/core/`, `TaskListModel`, `Main.qml`

Add undo for delete and for "clear completed". Two routes:

* **By hand:** keep a `std::vector<Task>` of removed tasks plus their positions,
  and add `Q_INVOKABLE bool undo()`.
* **With Qt's framework:** `QUndoStack` + `QUndoCommand`. In Qt 6 these live in
  `Qt6::Gui`, which this project already links, so there is nothing to add.

Wire it to Ctrl+Z with a `Shortcut { sequence: StandardKey.Undo }`.

**Done when:** deleting three tasks and pressing Ctrl+Z three times restores
them in the right positions, and there is a test that proves it.

---

## 5. Group the scan results by folder (2 hours) — *medium*

**Files:** `src/scanner/`, `src/models/ScanResultModel.*`, `ScannerPage.qml`

Currently the scanner aggregates by extension. Add a second aggregation by
immediate subfolder, and a toggle in the UI.

**Watch out for:** the worker must still emit progress at the same rate, and
`ScanSummary` gains a field — which means the metatype registration and the
tests both need attention.

---

## 6. A second window (1 hour) — *medium*

**Files:** new QML file, `Main.qml`

Open the task editor in its own `Window` instead of a `Dialog`, so the user can
keep editing while scrolling the list.

**Watch out for:** who owns the window, and what happens when the main window
closes first. This is a good exercise in QML object lifetime.

---

## 7. Swap the whole UI for Qt Widgets (half a day) — *hard, very instructive*

**Files:** a new `src/widgets/` and a new executable target

Build a second front end with `QListView`, `QLineEdit`, `QComboBox` and
`QPushButton` — reusing `TaskListModel` and `TaskFilterModel` **unchanged**.

```cpp
QListView view;
view.setModel(&filterModel);
view.setItemDelegate(new MyDelegate);
```

**Done when:** both executables build from the same model code and show the same
tasks. When that works, you have understood why models exist.

---

## 8. Persist to SQLite instead of JSON (half a day) — *hard*

**Files:** `src/core/`, `CMakeLists.txt` (add `Qt6::Sql`)

Put a `TaskRepository` interface behind `TaskStore` with two implementations:
JSON and SQLite (`QSqlDatabase`, `QSqlQuery`, prepared statements, a
transaction around bulk writes).

**Done when:** the existing `TaskStore` tests pass against *both* backends,
parameterised by a data-driven test.

---

## 9. Make it feel finished (open-ended)

* Keyboard shortcuts: `Shortcut { sequence: StandardKey.New }`.
* Translations: run `lupdate`, translate with Qt Linguist, load with
  `QTranslator`. Every string here already goes through `qsTr()`.
* Animations: `Behavior on opacity { NumberAnimation { duration: 120 } }` on the
  delegate.
* A settings file: `QSettings` for window size, last sort mode, last scanned
  folder.
* A system tray icon and notifications.
* `qmllint` clean, then a GitHub Actions workflow running build + `ctest`.

---

## Where to look things up

* **Qt documentation** — <https://doc.qt.io/qt-6/>. The class reference is
  genuinely excellent; read the overview page of any module before its classes.
* **Qt examples** — installed with Qt, and at
  <https://doc.qt.io/qt-6/qtexamplesandtutorials.html>. Real, maintained code.
* **The Qt source** — when a doc page is ambiguous, the implementation is one
  `git clone` away. This is a normal thing to do.
* **`qmllint` and `qmlformat`** — ship with Qt, cost nothing, catch a lot.

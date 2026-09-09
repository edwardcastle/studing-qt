# 3 — Models, views and delegates

Model/view is the part of Qt that repays study the most. Get it right once and
lists, tables, trees, filtering, sorting and selection all work the same way
forever after, in both QML and Widgets.

## 3.1 The idea

```
   ┌───────────┐  "how many rows?"   ┌──────────┐
   │           │◀────────────────────│          │
   │   MODEL   │  "row 7, role 3?"   │   VIEW   │──▶ DELEGATE (one per visible row)
   │           │◀────────────────────│          │
   └─────┬─────┘                     └──────────┘
         │ rowsInserted / rowsRemoved / dataChanged / modelReset
         └────────────────────────────────▶
```

* The **model** owns (or wraps) the data and answers questions.
* The **view** decides what is on screen, scrolls, and recycles delegates.
* The **delegate** draws one item.
* The **signals** are the only way the view learns anything changed.

The view *pulls* — it asks for the rows it needs, when it needs them. This is
what lets a `ListView` show a model with a million rows.

## 3.2 The minimum a list model must implement

```cpp
int rowCount(const QModelIndex &parent = {}) const override;
QVariant data(const QModelIndex &index, int role) const override;
QHash<int, QByteArray> roleNames() const override;    // for QML
```

Read `src/models/ScanResultModel.cpp` — it is about 75 lines and does exactly
this and nothing else. Then read `src/models/TaskListModel.cpp` for the full version.

### `rowCount()` and the parent check

```cpp
int TaskListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;                 // ← not optional
    return m_store.count();
}
```

`QAbstractItemModel` is a *tree* interface; a list is the special case where
only the invisible root has children. Forget this line and the model claims
every item has the same children as the root — infinite tree, confused views,
and `QAbstractItemModelTester` shouting at you.

### Roles

A role is "which piece of this row do you want". Custom roles start at
`Qt::UserRole`:

```cpp
enum Roles {
    IdRole = Qt::UserRole + 1,
    TitleRole,
    NotesRole,
    // …
};
```

`roleNames()` maps them to the names QML uses:

```cpp
return {
    { TitleRole, "title" },
    { DoneRole,  "done"  },
    // …
};
```

and the delegate declares exactly those names:

```qml
Rectangle {
    required property string title
    required property bool done
    // …
}
```

`required property` (Qt 6) is the modern spelling. It is faster than the old
implicit `model.title` lookup, and a typo becomes a startup error instead of
`undefined`. There is a test (`roleNamesMatchTheDelegate`) whose only job is to
remind you that renaming a role means editing the QML too.

Note that `TaskListModel` also answers `Qt::DisplayRole` with the title. That
costs one line and means a `QListView` in a Widgets application would show
something sensible without any extra work.

### Computed roles are fine, and often better

`PriorityLabelRole`, `DueDateLabelRole` and `OverdueRole` are not stored
anywhere — they are computed in `data()`. Doing the formatting and the
"is it overdue" decision in C++ keeps that logic testable and stops QML from
growing a pile of date arithmetic.

## 3.3 The contract: signals around every change

This is where models actually go wrong. Any structural change **must** be
bracketed:

| Change | Before | After |
|---|---|---|
| insert rows | `beginInsertRows(parent, first, last)` | `endInsertRows()` |
| remove rows | `beginRemoveRows(parent, first, last)` | `endRemoveRows()` |
| move rows | `beginMoveRows(...)` | `endMoveRows()` |
| replace everything | `beginResetModel()` | `endResetModel()` |
| edit in place | — | `emit dataChanged(topLeft, bottomRight, roles)` |

`first` and `last` are **inclusive**. Inserting one row at the end of a
3-row model is `beginInsertRows(QModelIndex(), 3, 3)`.

Look at `TaskListModel::addTask()` for an interesting case: the store may reject
the task (blank title) *after* we already announced the insertion. The model
then immediately announces a removal, so the two balance out and the view is
never left believing in a row that does not exist. The test
`addTaskRejectsBlankTitle` asserts exactly that.

> A cleaner design would validate before announcing. The version here is
> deliberate: it shows what "keeping the contract" means when things go wrong.
> Rewriting it to validate first is exercise 2.

### `dataChanged` and the roles argument

```cpp
emit dataChanged(idx, idx);                     // "every role of this row"
emit dataChanged(idx, idx, { DoneRole });       // "only the done role"
```

The second form lets views skip work. Pass the exact roles once your model gets
big enough for it to matter.

### Reset is the sledgehammer

`beginResetModel()` / `endResetModel()` tells views to throw away everything —
selection, scroll position, delegate state. It is correct but expensive, so use
it only for wholesale changes: `TaskListModel::load()` and `clearCompleted()`
here. Do not reach for it because working out the right insert/remove ranges is
annoying.

## 3.4 Editing through the model

`setData()` is the write side of `data()`:

```cpp
bool TaskListModel::setData(const QModelIndex &index, const QVariant &value, int role)
```

Three subtleties in the implementation, all of which matter:

1. It returns `false` for read-only roles (`OverdueRole` is computed).
2. If the new value equals the old one it returns `true` but emits **nothing** —
   success, no work.
3. `flags()` must include `Qt::ItemIsEditable`, or Widgets views will refuse to
   start an editor.

QML does not need `setData` for this app (it calls the `Q_INVOKABLE` commands
instead), but implementing it is what makes the model reusable and what the
`QAbstractItemModelTester` exercises.

## 3.5 Proxy models

`QSortFilterProxyModel` wraps a source model and presents a different view of
it. `src/models/TaskFilterModel.cpp` overrides two functions:

```cpp
bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;
bool lessThan(const QModelIndex &left, const QModelIndex &right) const override;
```

Things to notice:

* `sort(0)` is called in the constructor. Without it `lessThan()` is never
  used — a classic "my sorting does nothing" moment.
* Changing a rule calls `invalidateFilter()` (filter only) or `invalidate()`
  (filter and order). Otherwise the proxy keeps its cached answers.
* `lessThan()` sinks completed tasks in every mode. Composite ordering rules
  belong here, not in the data.
* The proxy exposes a `count` property, because QML wants one and
  `QSortFilterProxyModel` does not provide it. It is kept honest by connecting
  `rowsInserted`, `rowsRemoved` and `modelReset` to `countChanged`.

### Proxy rows are not source rows

The single most common bug when you introduce a proxy:

```qml
// WRONG: index is a proxy row, removeTask expects a source row
onRemoveClicked: taskModel.removeTask(index)

// RIGHT
onRemoveClicked: taskModel.removeTask(filterModel.sourceRow(index))
```

`TaskFilterModel::sourceRow()` exists purely so QML can do the conversion, and
`sourceRowMapsBackToTheRealRow` in the tests pins the behaviour down. In C++ the
equivalents are `mapToSource()` and `mapFromSource()`.

You can chain proxies (filter → sort → group). Each one only knows about the
model directly beneath it.

## 3.6 Delegates: the rules

```qml
delegate: TaskDelegate {
    width: listView.width          // set width, never height-from-parent
    onToggleRequested: (row) => { … }
}
```

* **Delegates are recycled.** The instance showing row 3 will show row 40 after
  you scroll. Never store anything in a delegate that must survive.
* **Keep them cheap.** No timers, no heavy JavaScript, no `Component.onCompleted`
  doing work. A stuttering list is almost always an expensive delegate.
* **Set the width, let the height follow the content** (`implicitHeight`).
  Binding a delegate's height to its parent's height creates a binding loop.
* **Delegates report, they do not act.** `TaskDelegate` emits
  `toggleRequested(row)`; `TasksPage` decides what that means. That keeps the
  delegate reusable and the proxy/source conversion in one place.
* **`clip: true` on the view**, or delegates paint outside it while scrolling.

## 3.7 When you need something else

| Situation | Use |
|---|---|
| a fixed handful of items | `Repeater` with a JS array (see `AboutPage.qml`) |
| a list that changes | `QAbstractListModel` (this chapter) |
| a table | `QAbstractTableModel` + `TableView` |
| a tree | `QAbstractItemModel` + `TreeView` — implement `index()` and `parent()` |
| data from SQL | `QSqlTableModel` / `QSqlQueryModel` |
| a quick prototype | `ListModel { }` in QML — fine to start, painful to keep |

Next: [04-threading.md](04-threading.md).

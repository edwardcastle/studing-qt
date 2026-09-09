# 7 — The C++ used in this project, explained

Qt has its own dialect. This page covers the C++ idioms that appear in the
source, why they were chosen, and where Qt's containers and the standard
library meet.

## 7.1 Value semantics and implicit sharing

`Task` is a plain struct you copy freely:

```cpp
std::optional<Task> stored = m_store.at(row);   // a copy
Task updated = *stored;                          // another copy
```

That looks wasteful and is not. Qt's containers — `QString`, `QList`,
`QByteArray`, `QHash` — are **implicitly shared** (copy-on-write): copying one
copies a pointer and bumps an atomic reference count. The deep copy happens only
when someone writes to a shared instance.

So passing `QString` by value is cheap, and returning containers by value is the
normal thing to do. Keep the classic rules anyway:

```cpp
void f(const QString &s);   // parameters: const reference
QString g() const;          // returns: by value, the compiler elides the copy
```

`std::string` and `std::vector` are **not** implicitly shared — copies there are
real. `TaskStore::tasks()` therefore returns `const std::vector<Task>&`.

## 7.2 `std::optional` instead of sentinel values

```cpp
std::optional<Task> TaskStore::at(int index) const
{
    if (index < 0 || index >= count())
        return std::nullopt;
    return m_tasks[static_cast<size_t>(index)];
}
```

Callers cannot forget to check:

```cpp
const auto stored = m_store.at(row);
if (!stored)
    return false;
Task updated = *stored;
```

The alternatives are worse: returning a default-constructed `Task` (is an empty
title "missing" or "empty"?), returning a pointer that might dangle, or throwing
(Qt code is generally written to be exception-neutral rather than
exception-driven).

## 7.3 Algorithms instead of loops

```cpp
const auto it = std::find_if(m_tasks.begin(), m_tasks.end(),
                             [id](const Task &task) { return task.id == id; });

const auto newEnd = std::remove_if(m_tasks.begin(), m_tasks.end(),
                                   [](const Task &task) { return task.done; });
m_tasks.erase(newEnd, m_tasks.end());          // the erase-remove idiom
```

`std::remove_if` does not remove anything — it shuffles the elements you keep to
the front and returns the new logical end. The `erase()` is what actually
shrinks the container. Forgetting it is a classic bug: the size never changes
and the tail holds moved-from values.

(In C++20 this is just `std::erase_if(m_tasks, pred)`. This project targets
C++17 so it stays portable to older toolchains.)

Lambda capture, briefly: `[id]` copies, `[&now]` refers, `[this]` captures the
object pointer, `[=]`/`[&]` capture everything — avoid those two, they hide
lifetime bugs, especially in lambdas that outlive the current scope.

## 7.4 `std::move` and where it matters

```cpp
int TaskStore::addTask(Task task)      // by value: the caller decides
{
    task.title = task.title.trimmed();
    // …
    m_tasks.push_back(std::move(task));   // steal the buffers, do not copy
    return m_tasks.back().id;
}
```

Taking the parameter **by value** and moving it into place means a caller who
passes a temporary pays nothing extra, and a caller who passes an lvalue pays
exactly one copy. `std::move` does not move anything; it casts to an rvalue
reference so the move constructor is selected. After moving from an object, it
is valid but unspecified — do not read it.

## 7.5 `QString` literals

```cpp
QStringLiteral("Low")               // builds the QString data at compile time
QLatin1String("High")               // no allocation; for comparisons
text.compare(QLatin1String("Low"), Qt::CaseInsensitive) == 0
```

Plain `"Low"` works too, but converts from `const char*` at runtime, every time.
In a loop or a `data()` implementation called thousands of times, that matters.
Rules of thumb: `QStringLiteral` when you need a `QString`, `QLatin1String` when
you only compare or append.

## 7.6 Enums

```cpp
enum class Priority { Low, Normal, High };   // scoped: no implicit int conversion
```

`Priority::Level` in this project is a plain (unscoped) enum inside a namespace,
because the QML side needs implicit conversion to `int` for
`Q_PROPERTY`/`Q_INVOKABLE` arguments. That is a deliberate trade-off; in code
that never crosses into QML, prefer `enum class`.

`Q_ENUM` / `Q_ENUM_NS` add reflection: names in `qDebug()` output, use in
`Q_PROPERTY`, and visibility in QML.

## 7.7 `const` correctness

Everything that does not modify state is `const`:

```cpp
int count() const;
QVariant data(const QModelIndex &index, int role) const override;
```

This is not decoration. `data()` is declared `const` by the base class, so if you
try to cache something inside it the compiler stops you — and that is exactly
the discipline you want in a function views call constantly. (`mutable` exists
for genuine caches; use it knowingly, and remember it is not thread-safe by
itself.)

## 7.8 `override`, `explicit`, `= default`

```cpp
explicit TaskListModel(QObject *parent = nullptr);      // no accidental conversions
int rowCount(const QModelIndex &parent = {}) const override;   // checked against the base
TaskStore() = default;
```

`override` is the one that will save you: misspell a virtual function's
signature and the compiler tells you, instead of your override silently never
being called.

## 7.9 Qt containers vs. the standard library

| Use | Reason |
|---|---|
| `QString` | Unicode, implicit sharing, the whole Qt API speaks it |
| `QList` / `QVector` (the same type in Qt 6) | needed at Qt API boundaries; implicitly shared |
| `QHash` | fast unordered map; `QMap` when you need ordering |
| `std::vector` | internal storage where no Qt API is involved (`TaskStore`) |
| `std::optional`, `std::atomic`, `std::unique_ptr` | no Qt equivalent worth using |

Do not agonise over this. Use Qt types at Qt boundaries, standard types inside
your own logic, and stop thinking about it.

## 7.10 RAII in the Qt world

```cpp
QSaveFile file(filePath);        // rolls back if commit() is never called
QTemporaryDir dir;               // deletes the tree in its destructor
QElapsedTimer timer;             // plain value, no cleanup needed
```

`QSaveFile` is worth calling out: it writes to a temporary file and renames it
on `commit()`. If the program dies mid-write, the previous file is untouched.
That is how you overwrite user data safely, and it is one line more than
`QFile`.

For heap objects, prefer Qt's parent/child ownership when the object is a
`QObject`, and `std::unique_ptr` when it is not. Raw owning pointers appear here
in exactly one place — `ScannerController::m_worker` — because its lifetime is
governed by a thread, and the comment there says so.

## 7.11 Two Qt-specific pitfalls

**Signals are `void`.** They have no return value, ever. If you need an answer
back, call a function instead.

**`emit` is nothing.** It expands to whitespace. It exists so a human reading
the code can see that a signal is being sent. Use it anyway.

Next: [08-exercises.md](08-exercises.md).

# 10 — A learning path, if Qt *and* C++ are both new

Every other page here assumes you already read C++ comfortably. This one does
not. It is the order I would actually follow, and roughly how long each part
takes.

## The trap to avoid first

The most common way to bounce off Qt is to try to learn four things at once:
C++, CMake, QML and the Qt framework itself. They interleave constantly, so it
feels like one impossible subject instead of four ordinary ones, and the usual
conclusion is "I'm not smart enough for this."

You are doing four things at once. Do them in order instead.

A second, gentler trap: reading. Reading code produces a feeling of
understanding that disappears the moment you have a blank editor. Every stage
below ends with something you have to **write** or **break**.

---

## Stage 0 — Enough C++ (2–4 weeks, part time)

You cannot learn Qt around C++. But you need far less of it than you think to
begin.

**Learn this much:**

* values vs. references vs. pointers — what `&` and `*` actually mean, and when
  a thing is copied
* the header / `.cpp` split, `#include`, and why declarations exist separately
  from definitions
* classes: constructors, destructors, member functions, `const`
* `std::vector` and `std::string`
* how to read a compiler error and how to read a *linker* error — they are
  different problems with different fixes

**Deliberately skip for now:** writing your own templates, move semantics,
smart pointers, exceptions, operator overloading, anything about the
preprocessor beyond `#include`.

**Resource:** [learncpp.com](https://www.learncpp.com/) — free, well sequenced,
and it explains *why*, not just *what*. Chapters 1–12 are plenty. Type every
example by hand; do not copy and paste.

**About this repository's C++.** The source does use `std::optional`,
`std::move`, lambdas and `<algorithm>`. That is fine — treat them as read-only
at this stage. [07-cpp-notes.md](07-cpp-notes.md) is exactly the glossary for
them, written to be read *after* you meet each one in the code rather than
before.

**Checkpoint.** Open `src/core/TaskStore.h` and say out loud what

```cpp
const std::vector<Task> &tasks() const;
```

means — all three `const`-ish parts of it — without looking anything up. When
that is easy, move on.

---

## Stage 1 — QObject and signals/slots (about a week)

This is the concept everything else in Qt sits on. Get it properly and the rest
of the framework stops feeling arbitrary.

**Read:** the *QObject* and *Signals and slots* sections of
[00-start-here.md](00-start-here.md).

**Then write, from scratch:** a ~40 line console program. No GUI at all.

```
QCoreApplication, two QObject subclasses.
One emits a signal with an int.
One has a slot that prints it.
connect() them in main(), fire the signal, run app.exec().
```

Getting this to build teaches you moc, `Q_OBJECT`, and the CMake `AUTOMOC`
machinery whether you wanted to learn them or not — which is the point.

**Checkpoint.** You can explain what `Q_OBJECT` is for, and what
`undefined reference to vtable for MyClass` means when you see it.

---

## Stage 2 — Models (about 2 weeks) — the highest-leverage skill

`QAbstractListModel` is the thing that separates people who fight Qt from people
who use it. Learn it once and lists, tables, trees, filtering, sorting and
selection all work the same way for the rest of your career — in QML *and* in
Widgets.

**Read:** [03-models.md](03-models.md).

**Then read, in this order:**

1. `src/models/ScanResultModel.cpp` — about 75 lines, implements the three
   required functions and nothing else. This is the shape of every model.
2. `src/models/TaskListModel.cpp` — the full version, with commands, editing,
   auto-save and the signal contract.

**Then do exercise 3** in [08-exercises.md](08-exercises.md): add a `tags` field
end to end. It touches eight files, from the struct to the QML delegate to the
tests. It is worth more than the two weeks of reading that preceded it.

**Checkpoint.** You can write a new list model from an empty file without
looking at an existing one, and explain why `rowCount()` must return 0 for a
valid parent.

---

## Stage 3 — QML and bindings (about a week)

**Read:** [02-cpp-and-qml.md](02-cpp-and-qml.md).

The whole idea is that `text: taskModel.openCount` keeps itself up to date. When
you understand why there is no `updateLabel()` function anywhere in this
project — and why writing `label.text = "…"` in a handler would be a step
backwards — you have the model right.

**Checkpoint.** Delete `NOTIFY countsChanged` from one property in
`TaskListModel.h`, rebuild, and predict what breaks *before* you run it.

---

## Stage 4 — Threading (about a week)

**Read:** [04-threading.md](04-threading.md).

**Then run the experiment in it**: in `ScannerController::start()`, replace

```cpp
emit scanRequested(path);
```

with

```cpp
m_worker->scan(path);
```

Rebuild, scan a large folder, and try to move the window. Five seconds of work,
and it teaches the whole chapter.

**Checkpoint.** You can say why cancellation uses a `std::atomic_bool` instead
of a queued signal.

---

## Stage 5 — Everything else

CMake ([05](05-build-system.md)), testing ([06](06-testing.md)), deployment.
Genuinely fine to leave until now: the build already works, and you will
understand the build file much faster once you know what it is building.

---

## Install this now, not later

**Qt Creator.** Open the top-level `CMakeLists.txt` in it. You get a working
debugger, offline documentation (press **F1** on any Qt class name), code
completion across C++ *and* QML, and the QML profiler. For someone starting out
this is a large difference, not a small one.

Also worth knowing about from day one, even if you do not use them yet:

```bash
qmllint src/qml/*.qml     # static analysis for QML — this project is clean
ctest --test-dir build --output-on-failure
```

---

## Two habits that beat any book

**1. Retype, don't read.** Retype `ScanResultModel.cpp` from a blank file
without copy-paste. You will find the parts you only *thought* you understood —
that is the entire exercise, and it takes twenty minutes.

**2. Break things on purpose.** The table at the top of
[08-exercises.md](08-exercises.md) lists seven one-line sabotages and what each
one should do. Working out *why* a tab label stops updating when you delete a
`NOTIFY` teaches you bindings permanently, in a way that reading about them
does not.

---

## A realistic timeline

About **three months of steady part-time work** to be genuinely comfortable:
writing models without a reference open, debugging your own signal/slot
problems, reading a Qt doc page and knowing which parts matter.

Faster if you have programmed seriously in another language. Slower if this is
your first one, and that is completely normal. Anyone promising less is selling
something.

---

## Summary

| Stage | Topic | Time | Ends when you can… |
|---|---|---|---|
| 0 | enough C++ | 2–4 weeks | read `TaskStore.h` without help |
| 1 | `QObject`, signals/slots | 1 week | write a console signal/slot program from scratch |
| 2 | models | 2 weeks | write a list model from an empty file |
| 3 | QML bindings | 1 week | predict what a missing `NOTIFY` breaks |
| 4 | threading | 1 week | explain the `std::atomic_bool` cancel flag |
| 5 | build, tests, shipping | ongoing | read `CMakeLists.txt` top to bottom |

Then go back to [00-start-here.md](00-start-here.md) and read the whole set
properly. It will read very differently the second time.

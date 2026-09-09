# 0 — Start here

## How to use this repository

Reading code beats reading tutorials, but only if you read it in the right
order and know what to look for. Here is the loop I suggest:

1. **Build and run it** (see the README). Click everything. Add a task, delete
   one, search, sort, scan a big folder and cancel it.
2. **Read one doc page**, then open the files it talks about. Every source file
   starts with a `TEACHING NOTE` block explaining the decisions in it.
3. **Break something on purpose.** Comment out an `emit`, delete a
   `beginInsertRows`, rename a role. Rebuild and watch what happens. This is the
   fastest way to learn what each piece is actually for — the suggestions are
   collected in [08-exercises.md](08-exercises.md).
4. **Run the tests** after every change: `ctest --test-dir build --output-on-failure`.

## The mental model you need first

Qt is not "a GUI library". It is a C++ framework with a GUI on top. Four ideas
carry almost everything:

### 1. The event loop

```cpp
int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);   // create the machinery
    /* ... build objects ... */
    return app.exec();                 // ← the program lives in here
}
```

`exec()` does not return until the application quits. Inside it, Qt takes
events off a queue (mouse, keyboard, timers, network, signals posted from other
threads) and dispatches them to objects. **Everything your code does is a
reaction to an event.**

Consequence: if one of your functions takes two seconds, the loop cannot
dispatch anything for two seconds, and the window freezes. That is the entire
reason `src/scanner/` exists.

### 2. QObject

`QObject` is the base class that provides:

* **signals and slots** — type-safe notifications between objects,
* **properties** — named, introspectable values (`Q_PROPERTY`),
* **object trees** — a parent deletes its children,
* **thread affinity** — which thread delivers this object's queued calls.

Any class that wants those must:

```cpp
class Thing : public QObject {
    Q_OBJECT            // ← this macro; without it nothing works
public:
    explicit Thing(QObject *parent = nullptr);
signals:
    void somethingHappened(int value);
};
```

The `Q_OBJECT` macro expands into declarations that **moc** (the meta-object
compiler) implements in a generated `moc_Thing.cpp`. CMake runs moc for you via
`CMAKE_AUTOMOC`, which `qt_standard_project_setup()` turns on.

> If you ever see `undefined reference to vtable for Thing`, it almost always
> means moc did not run on that header. See
> [09-troubleshooting.md](09-troubleshooting.md).

### 3. Signals and slots

```cpp
connect(sender, &Sender::valueChanged, receiver, &Receiver::onValueChanged);
```

* The sender does not know who is listening. Zero, one or ten receivers — same
  code.
* The connection is checked **at compile time** when you use the pointer-to-
  member syntax above. (The old `SIGNAL()`/`SLOT()` macro form is string-based
  and fails at runtime instead. Do not use it in new code.)
* If sender and receiver live on different threads, Qt automatically switches
  from a direct call to a **queued** one: the arguments are copied into an event
  and the slot runs on the receiver's thread. This is the single most useful
  thing Qt does for you, and [04-threading.md](04-threading.md) is about it.
* A connection dies automatically when either object is destroyed.

### 4. Declarative UI

QML describes *what the interface is*, not *what to do when something changes*:

```qml
Label {
    text: qsTr("%1 open").arg(taskModel.openCount)
    color: taskModel.overdueCount > 0 ? Theme.warning : Theme.textMuted
}
```

Those two lines are **bindings**. QML noticed that they read
`taskModel.openCount` and `taskModel.overdueCount`, and it re-evaluates them
whenever the C++ side emits the corresponding `NOTIFY` signal. There is no
`updateLabel()` function anywhere in this project, and there should not be one.

The moment you write `someLabel.text = "..."` in an event handler, you have
destroyed the binding on that property and taken over manual updating. Sometimes
that is what you want; usually it is a bug.

## What "pro" looks like

The things that separate a working Qt program from a good one, all of which are
demonstrated in this repository:

* Business logic lives in classes that **do not include a single GUI header**,
  so it can be tested in milliseconds.
* Models honour the **model/view contract** exactly, and there is a test that
  proves it (`QAbstractItemModelTester`).
* Long operations run **off the GUI thread**, communicate by value, and can be
  cancelled.
* The QML layer holds **no application state** — only transient view state like
  "is this dialog open".
* Every user-visible string goes through `qsTr()`, so translation is possible
  later.
* Warnings are on (`-Wall -Wextra -Wpedantic`) and the build is clean.

Next: [01-architecture.md](01-architecture.md).

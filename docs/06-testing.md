# 6 — Testing

```bash
ctest --test-dir build --output-on-failure     # all three suites
./build/tests/tst_taskstore                    # one suite, verbose
./build/tests/tst_taskstore jsonRoundTripKeepsEverything   # one function
./build/tests/tst_tasklistmodel -functions     # list what is available
```

The whole suite runs in about 20 milliseconds, because none of it needs a
window. That is not an accident — it is the payoff of the layering described in
[01-architecture.md](01-architecture.md).

## 6.1 The shape of a Qt test

```cpp
class Tst_TaskStore : public QObject
{
    Q_OBJECT
private slots:
    void addAssignsIncreasingIds();     // ← a test function
    void addRejectsBlankTitles();
};

QTEST_APPLESS_MAIN(Tst_TaskStore)
#include "tst_taskstore.moc"            // ← required: moc output for this .cpp
```

* Every **private slot** is a test, except four special names:
  `initTestCase()` (once, first), `init()` (before each test),
  `cleanup()` (after each test), `cleanupTestCase()` (once, last).
* The `#include "….moc"` line at the bottom is needed because the `QObject`
  subclass is defined in a `.cpp`, not a header.

Pick the right main macro:

| Macro | Creates | Use for |
|---|---|---|
| `QTEST_APPLESS_MAIN` | nothing | pure logic, no event loop (`tst_taskstore`) |
| `QTEST_GUILESS_MAIN` | `QCoreApplication` | event loop, timers, threads (`tst_tasklistmodel`, `tst_scanworker`) |
| `QTEST_MAIN` | `QGuiApplication`/`QApplication` | anything that needs a GUI |

## 6.2 Assertions

```cpp
QVERIFY(condition);
QVERIFY2(condition, "message shown on failure");
QCOMPARE(actual, expected);        // prints both values when they differ
QVERIFY_THROWS_EXCEPTION(Type, expression);
QSKIP("not applicable here");
QFAIL("should not be reached");
```

Prefer `QCOMPARE` over `QVERIFY(a == b)`: on failure it prints what it got and
what it wanted, which is the difference between a two-second fix and a
debugging session.

> **A trap this project hit.** `QCOMPARE` finds a free function named
> `toString()` by argument-dependent lookup and tries to use it to print
> failures. `devboard::Priority` originally had a `toString(Level)` returning
> `QString`, which made every `QCOMPARE` on a `Priority::Level` fail to compile
> with a wall of template errors. It is now called `label()`. If you ever see
> "no matching function for call to `compare_helper`", look for a `toString()`
> in the same namespace as the compared type.

## 6.3 `QSignalSpy` — testing that the right things were announced

For a Qt class, emitting the right signals **is** part of being correct. A model
whose data is right but whose signals are wrong will corrupt any view attached
to it.

```cpp
QSignalSpy insertSpy(m_model, &QAbstractItemModel::rowsInserted);

m_model->addTask(QStringLiteral("write a test"));

QCOMPARE(insertSpy.count(), 1);
const QList<QVariant> arguments = insertSpy.first();
QCOMPARE(arguments.at(1).toInt(), 0);   // rowsInserted(parent, first, last)
QCOMPARE(arguments.at(2).toInt(), 0);
```

`QSignalSpy` is just a `QList<QList<QVariant>>` that grows on every emission.
Check the **arguments**, not only the count.

For queued signals from another thread, `spy.wait(ms)` runs a local event loop
until the signal arrives or the timeout expires:

```cpp
QMetaObject::invokeMethod(worker, "scan", Qt::QueuedConnection, Q_ARG(QString, path));
QVERIFY(finishedSpy.wait(5000));
```

Never `QThread::sleep()` instead: slow when it passes, flaky when it fails.

Tests that pin down "no signal was emitted" are just as valuable:

```cpp
QVERIFY(m_model->setData(index, QStringLiteral("after"), TaskListModel::TitleRole));
QCOMPARE(changedSpy.count(), 1);
QVERIFY(m_model->setData(index, QStringLiteral("after"), TaskListModel::TitleRole));
QCOMPARE(changedSpy.count(), 1);      // same value → still 1, no repaint
```

## 6.4 `QAbstractItemModelTester` — free model verification

```cpp
QAbstractItemModelTester tester(m_model, QAbstractItemModelTester::FailureReportingMode::Warning);
```

Attach it and it hooks every model signal, checking the contract continuously:
that `rowCount()` matches what `rowsInserted` announced, that indexes stay
valid, that `begin…`/`end…` pairs balance, that `parent()` is consistent. It
catches the bugs that otherwise appear as a random crash inside `QQuickListView`
three weeks later.

Add it to **every** model test you ever write. It costs one line.

## 6.5 Isolation

Tests must not touch the developer's real data or each other's:

```cpp
void Tst_TaskListModel::init()
{
    m_dir = new QTemporaryDir;                                  // deleted in cleanup()
    m_model = new TaskListModel;
    m_model->setStoragePath(m_dir->filePath(QStringLiteral("tasks.json")));
}
```

`TaskListModel::setStoragePath()` exists **for this reason**. Designing for
testability usually means adding one seam like this — a way to inject the thing
the class would otherwise decide for itself.

`tst_scanworker` does the same in reverse: `initTestCase()` builds a tiny
directory tree with known sizes (5 + 10 + 20 + 3 bytes) in a `QTemporaryDir`, so
the assertions can be exact numbers rather than "more than zero".

## 6.6 Data-driven tests

For many similar cases, write the test once and feed it a table:

```cpp
void Tst_TaskStore::priorityRoundTrip_data()
{
    QTest::addColumn<Priority::Level>("input");
    QTest::addColumn<QString>("text");

    QTest::newRow("low")    << Priority::Low    << QStringLiteral("Low");
    QTest::newRow("normal") << Priority::Normal << QStringLiteral("Normal");
    QTest::newRow("high")   << Priority::High   << QStringLiteral("High");
}

void Tst_TaskStore::priorityRoundTrip()
{
    QFETCH(Priority::Level, input);
    QFETCH(QString, text);
    QCOMPARE(Priority::label(input), text);
    QCOMPARE(Priority::fromLabel(text), input);
}
```

The `_data()` suffix is the convention Qt Test looks for. Each row is reported
separately, so you see exactly which case failed. (Writing this one is exercise 1.)

## 6.7 Testing QML

Not used in this project, but worth knowing: **Qt Quick Test** lets you write
tests in QML.

```cmake
find_package(Qt6 REQUIRED COMPONENTS QuickTest)
qt_add_executable(tst_qml tst_qml.cpp)
target_link_libraries(tst_qml PRIVATE Qt6::QuickTest)
```

```qml
import QtQuick
import QtTest

TestCase {
    name: "TaskEditor"
    TaskEditorDialog { id: dialog; taskModel: TaskListModel { } }

    function test_openForNew_clearsTitle() {
        dialog.openForNew();
        compare(dialog.editedRow, -1);
    }
}
```

`TestCase` also gives you `mousePress`, `keyClick` and `tryCompare` (which polls
until a binding settles) for real interaction tests.

## 6.8 What is worth testing

| Test it | Do not bother |
|---|---|
| every rule in `src/core` | colours and margins |
| model signals and role names | that `Qt::red` is red |
| proxy filtering, sorting, row mapping | Qt's own classes |
| serialisation round trips | trivial one-line getters |
| threading: does it finish, does cancel work | exact pixel layout |
| every bug you fix — write the failing test first | |

That last row is the highest-value habit in the table.

Next: [07-cpp-notes.md](07-cpp-notes.md).

// ---------------------------------------------------------------------------
// tst_taskstore.cpp -- unit tests for the pure C++ layer.
//
// TEACHING NOTE
// Qt Test is a small framework built into Qt. The shape is always the same:
//
//   class Tst_Something : public QObject { Q_OBJECT private slots: ... };
//
// Every *private slot* is a test function, except four magic names:
//   initTestCase()    once, before everything
//   init()            before each test function
//   cleanup()         after each test function
//   cleanupTestCase() once, at the end
//
// QTEST_APPLESS_MAIN writes a main() that needs no QCoreApplication -- perfect
// for logic that has no event loop. Use QTEST_GUILESS_MAIN when you need an
// event loop but no GUI, and QTEST_MAIN for real GUI tests.
// ---------------------------------------------------------------------------

#include "core/TaskStore.h"

#include <QJsonArray>
#include <QTemporaryDir>
#include <QTest>

using namespace devboard;

class Tst_TaskStore : public QObject
{
    Q_OBJECT

private slots:
    void addAssignsIncreasingIds();
    void addRejectsBlankTitles();
    void addTrimsTheTitle();

    void updateKeepsIdentityFields();
    void updateFailsForUnknownId();

    void removeAndSetDone();
    void removeCompletedRemovesOnlyDone();

    void countsAreConsistent();
    void overdueIgnoresCompletedTasks();

    void jsonRoundTripKeepsEverything();
    void loadRejectsGarbageWithoutLosingData();
    void saveAndLoadThroughAFile();

private:
    /// Small helper so the tests read like sentences.
    static Task makeTask(const QString &title,
                         Priority::Level priority = Priority::Normal,
                         const QDateTime &due = QDateTime())
    {
        Task task;
        task.title = title;
        task.priority = priority;
        task.dueDate = due;
        return task;
    }
};

void Tst_TaskStore::addAssignsIncreasingIds()
{
    TaskStore store;
    const int first = store.addTask(makeTask(QStringLiteral("first")));
    const int second = store.addTask(makeTask(QStringLiteral("second")));

    QCOMPARE(store.count(), 2);
    QVERIFY(first > 0);
    QVERIFY(second > first);
    QCOMPARE(store.indexOfId(second), 1);
    QCOMPARE(store.indexOfId(9999), -1);   // unknown id -> -1, never a crash
}

void Tst_TaskStore::addRejectsBlankTitles()
{
    TaskStore store;
    QCOMPARE(store.addTask(makeTask(QString())), 0);
    QCOMPARE(store.addTask(makeTask(QStringLiteral("   "))), 0);
    QVERIFY(store.isEmpty());
}

void Tst_TaskStore::addTrimsTheTitle()
{
    TaskStore store;
    store.addTask(makeTask(QStringLiteral("  padded  ")));
    QCOMPARE(store.at(0)->title, QStringLiteral("padded"));

    // A task added without a createdAt gets one automatically.
    QVERIFY(store.at(0)->createdAt.isValid());
}

void Tst_TaskStore::updateKeepsIdentityFields()
{
    TaskStore store;
    const int id = store.addTask(makeTask(QStringLiteral("original")));
    const QDateTime created = store.at(0)->createdAt;

    Task replacement = makeTask(QStringLiteral("edited"), Priority::High);
    replacement.id = 4242;                                    // must be ignored
    replacement.createdAt = QDateTime::currentDateTime().addYears(-5);   // ditto

    QVERIFY(store.updateTask(id, replacement));
    QCOMPARE(store.at(0)->id, id);
    QCOMPARE(store.at(0)->createdAt, created);
    QCOMPARE(store.at(0)->title, QStringLiteral("edited"));
    QCOMPARE(store.at(0)->priority, Priority::High);
}

void Tst_TaskStore::updateFailsForUnknownId()
{
    TaskStore store;
    QVERIFY(!store.updateTask(1, makeTask(QStringLiteral("nope"))));

    const int id = store.addTask(makeTask(QStringLiteral("real")));
    QVERIFY(!store.updateTask(id, makeTask(QString())));   // blank title rejected
    QCOMPARE(store.at(0)->title, QStringLiteral("real"));  // and nothing changed
}

void Tst_TaskStore::removeAndSetDone()
{
    TaskStore store;
    const int id = store.addTask(makeTask(QStringLiteral("a task")));

    QVERIFY(store.setDone(id, true));
    QVERIFY(store.at(0)->done);

    // Setting the same value again reports "no change", so the model layer can
    // skip emitting dataChanged().
    QVERIFY(!store.setDone(id, true));

    QVERIFY(store.removeTask(id));
    QVERIFY(store.isEmpty());
    QVERIFY(!store.removeTask(id));
}

void Tst_TaskStore::removeCompletedRemovesOnlyDone()
{
    TaskStore store;
    const int a = store.addTask(makeTask(QStringLiteral("keep me")));
    const int b = store.addTask(makeTask(QStringLiteral("done 1")));
    const int c = store.addTask(makeTask(QStringLiteral("done 2")));
    Q_UNUSED(a)

    store.setDone(b, true);
    store.setDone(c, true);

    QCOMPARE(store.removeCompleted(), 2);
    QCOMPARE(store.count(), 1);
    QCOMPARE(store.at(0)->title, QStringLiteral("keep me"));
    QCOMPARE(store.removeCompleted(), 0);   // idempotent
}

void Tst_TaskStore::countsAreConsistent()
{
    TaskStore store;
    store.addTask(makeTask(QStringLiteral("one")));
    const int second = store.addTask(makeTask(QStringLiteral("two")));
    store.setDone(second, true);

    QCOMPARE(store.count(), 2);
    QCOMPARE(store.openCount(), 1);
    QCOMPARE(store.doneCount(), 1);
}

void Tst_TaskStore::overdueIgnoresCompletedTasks()
{
    const QDateTime yesterday = QDateTime::currentDateTime().addDays(-1);

    TaskStore store;
    store.addTask(makeTask(QStringLiteral("late"), Priority::Normal, yesterday));
    const int doneId = store.addTask(makeTask(QStringLiteral("late but done"),
                                              Priority::Normal, yesterday));
    store.addTask(makeTask(QStringLiteral("no date")));

    QCOMPARE(store.overdueCount(), 2);
    store.setDone(doneId, true);
    QCOMPARE(store.overdueCount(), 1);
}

void Tst_TaskStore::jsonRoundTripKeepsEverything()
{
    TaskStore original;
    const QDateTime due = QDateTime::currentDateTime().addDays(3);
    original.addTask(makeTask(QStringLiteral("with a due date"), Priority::High, due));
    const int id = original.addTask(makeTask(QStringLiteral("no due date"), Priority::Low));
    original.setDone(id, true);

    TaskStore restored;
    QString error;
    QVERIFY2(restored.loadFromJson(original.toJson(), &error), qPrintable(error));

    QCOMPARE(restored.count(), original.count());
    for (int i = 0; i < original.count(); ++i) {
        // Task has operator==, so one QCOMPARE checks every field at once.
        QCOMPARE(*restored.at(i), *original.at(i));
    }

    // Ids must keep growing after a reload, or a new task would collide with a
    // restored one.
    const int newId = restored.addTask(makeTask(QStringLiteral("added after load")));
    QVERIFY(newId > id);
}

void Tst_TaskStore::loadRejectsGarbageWithoutLosingData()
{
    TaskStore store;
    store.addTask(makeTask(QStringLiteral("precious")));

    QString error;
    QVERIFY(!store.loadFromJson(QJsonDocument(QJsonArray()), &error));
    QVERIFY(!error.isEmpty());

    // The failed load must not have touched the existing content.
    QCOMPARE(store.count(), 1);
    QCOMPARE(store.at(0)->title, QStringLiteral("precious"));
}

void Tst_TaskStore::saveAndLoadThroughAFile()
{
    // QTemporaryDir cleans itself up in its destructor, so tests never leave
    // files behind and never depend on each other.
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    const QString path = dir.filePath(QStringLiteral("nested/tasks.json"));

    TaskStore writer;
    writer.addTask(makeTask(QStringLiteral("persisted")));
    QString error;
    QVERIFY2(writer.saveToFile(path, &error), qPrintable(error));

    TaskStore reader;
    QVERIFY2(reader.loadFromFile(path, &error), qPrintable(error));
    QCOMPARE(reader.count(), 1);
    QCOMPARE(reader.at(0)->title, QStringLiteral("persisted"));

    // Loading a path that does not exist is not an error: it is a first run.
    TaskStore fresh;
    QVERIFY(fresh.loadFromFile(dir.filePath(QStringLiteral("missing.json")), &error));
    QVERIFY(fresh.isEmpty());
}

QTEST_APPLESS_MAIN(Tst_TaskStore)
#include "tst_taskstore.moc"

// ---------------------------------------------------------------------------
// tst_tasklistmodel.cpp -- tests for the model layer.
//
// TEACHING NOTE
// Two tools do most of the work here:
//
//   QAbstractItemModelTester -- attach it to any model and it verifies, at
//       runtime, that you honour the model contract: that rowCount() is stable,
//       that beginInsertRows() is matched by endInsertRows(), that indexes stay
//       valid, and so on. Adding it to your model tests costs one line and
//       catches the bugs that otherwise show up as random view crashes.
//
//   QSignalSpy -- records every emission of a signal so you can assert on the
//       count and on the arguments. Testing *that the right signals were sent*
//       is as important as testing the data, because signals are what the UI
//       reacts to.
// ---------------------------------------------------------------------------

#include "models/TaskFilterModel.h"
#include "models/TaskListModel.h"

#include <QAbstractItemModelTester>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

using namespace devboard;

class Tst_TaskListModel : public QObject
{
    Q_OBJECT

private slots:
    void init();              // runs before every test function
    void cleanup();           // runs after every test function

    void modelPassesTheItemModelTester();
    void roleNamesMatchTheDelegate();
    void addTaskInsertsOneRowAndSignals();
    void addTaskRejectsBlankTitle();
    void toggleDoneEmitsDataChanged();
    void removeTaskEmitsRowsRemoved();
    void clearCompletedResetsTheModel();
    void setDataEditsThroughTheModel();
    void getReturnsAJavaScriptFriendlyMap();
    void saveAndLoadUseTheStoragePath();

    void filterHidesCompletedTasks();
    void filterSearchesTitleAndNotes();
    void sortByPriorityPutsHighFirst();
    void sourceRowMapsBackToTheRealRow();

private:
    QTemporaryDir *m_dir = nullptr;
    TaskListModel *m_model = nullptr;
};

void Tst_TaskListModel::init()
{
    m_dir = new QTemporaryDir;
    QVERIFY(m_dir->isValid());

    m_model = new TaskListModel;
    // Point the model at a throw-away file so the test never touches the real
    // ~/.local/share/DevBoard/tasks.json of the developer running it.
    m_model->setStoragePath(m_dir->filePath(QStringLiteral("tasks.json")));
}

void Tst_TaskListModel::cleanup()
{
    delete m_model;
    m_model = nullptr;
    delete m_dir;
    m_dir = nullptr;
}

void Tst_TaskListModel::modelPassesTheItemModelTester()
{
    QAbstractItemModelTester tester(m_model, QAbstractItemModelTester::FailureReportingMode::Warning);

    m_model->addTask(QStringLiteral("one"));
    m_model->addTask(QStringLiteral("two"));
    m_model->toggleDone(0);
    m_model->removeTask(1);
    m_model->clearCompleted();

    QCOMPARE(m_model->rowCount(), 0);
}

void Tst_TaskListModel::roleNamesMatchTheDelegate()
{
    // If you rename a role here you must rename the matching `required property`
    // in TaskDelegate.qml. This test is the reminder.
    const QHash<int, QByteArray> names = m_model->roleNames();
    for (const char *expected : { "taskId", "title", "notes", "priority",
                                  "priorityLabel", "done", "createdAt",
                                  "dueDate", "dueDateLabel", "overdue" }) {
        QVERIFY2(names.values().contains(QByteArray(expected)),
                 qPrintable(QStringLiteral("missing role name: %1").arg(QLatin1String(expected))));
    }
}

void Tst_TaskListModel::addTaskInsertsOneRowAndSignals()
{
    QSignalSpy insertSpy(m_model, &QAbstractItemModel::rowsInserted);
    QSignalSpy countSpy(m_model, &TaskListModel::countsChanged);

    const int row = m_model->addTask(QStringLiteral("write a test"),
                                     QStringLiteral("with QSignalSpy"),
                                     Priority::High);

    QCOMPARE(row, 0);
    QCOMPARE(m_model->rowCount(), 1);
    QCOMPARE(insertSpy.count(), 1);
    QVERIFY(countSpy.count() >= 1);

    // rowsInserted(parent, first, last): check the arguments, not just the count.
    const QList<QVariant> arguments = insertSpy.first();
    QCOMPARE(arguments.at(1).toInt(), 0);
    QCOMPARE(arguments.at(2).toInt(), 0);

    const QModelIndex index = m_model->index(0, 0);
    QCOMPARE(index.data(TaskListModel::TitleRole).toString(), QStringLiteral("write a test"));
    QCOMPARE(index.data(TaskListModel::PriorityRole).toInt(), int(Priority::High));
    QCOMPARE(index.data(TaskListModel::PriorityLabelRole).toString(), QStringLiteral("High"));
    QCOMPARE(index.data(TaskListModel::DoneRole).toBool(), false);
}

void Tst_TaskListModel::addTaskRejectsBlankTitle()
{
    QSignalSpy insertSpy(m_model, &QAbstractItemModel::rowsInserted);
    QSignalSpy removeSpy(m_model, &QAbstractItemModel::rowsRemoved);

    QCOMPARE(m_model->addTask(QStringLiteral("   ")), -1);
    QCOMPARE(m_model->rowCount(), 0);

    // The model announced the row and then took it back, so the two signals
    // must balance out. A view that saw only one of them would be corrupt.
    QCOMPARE(insertSpy.count(), removeSpy.count());
}

void Tst_TaskListModel::toggleDoneEmitsDataChanged()
{
    m_model->addTask(QStringLiteral("toggle me"));
    QSignalSpy changedSpy(m_model, &QAbstractItemModel::dataChanged);

    QVERIFY(m_model->toggleDone(0));
    QCOMPARE(changedSpy.count(), 1);
    QCOMPARE(m_model->index(0, 0).data(TaskListModel::DoneRole).toBool(), true);
    QCOMPARE(m_model->openCount(), 0);
    QCOMPARE(m_model->doneCount(), 1);

    QVERIFY(!m_model->toggleDone(99));            // out of range -> false
    QCOMPARE(changedSpy.count(), 1);              // and no signal
}

void Tst_TaskListModel::removeTaskEmitsRowsRemoved()
{
    m_model->addTask(QStringLiteral("first"));
    m_model->addTask(QStringLiteral("second"));

    QSignalSpy removeSpy(m_model, &QAbstractItemModel::rowsRemoved);
    QVERIFY(m_model->removeTask(0));

    QCOMPARE(removeSpy.count(), 1);
    QCOMPARE(m_model->rowCount(), 1);
    QCOMPARE(m_model->index(0, 0).data(TaskListModel::TitleRole).toString(),
             QStringLiteral("second"));
}

void Tst_TaskListModel::clearCompletedResetsTheModel()
{
    m_model->addTask(QStringLiteral("keep"));
    m_model->addTask(QStringLiteral("drop"));
    m_model->toggleDone(1);

    QSignalSpy resetSpy(m_model, &QAbstractItemModel::modelReset);
    QCOMPARE(m_model->clearCompleted(), 1);

    QCOMPARE(resetSpy.count(), 1);
    QCOMPARE(m_model->rowCount(), 1);
    QCOMPARE(m_model->clearCompleted(), 0);   // nothing to do -> no reset
    QCOMPARE(resetSpy.count(), 1);
}

void Tst_TaskListModel::setDataEditsThroughTheModel()
{
    m_model->addTask(QStringLiteral("before"));
    const QModelIndex index = m_model->index(0, 0);

    QSignalSpy changedSpy(m_model, &QAbstractItemModel::dataChanged);
    QVERIFY(m_model->setData(index, QStringLiteral("after"), TaskListModel::TitleRole));
    QCOMPARE(index.data(TaskListModel::TitleRole).toString(), QStringLiteral("after"));
    QCOMPARE(changedSpy.count(), 1);

    // Writing the same value must succeed but must NOT emit dataChanged again,
    // otherwise views repaint for nothing.
    QVERIFY(m_model->setData(index, QStringLiteral("after"), TaskListModel::TitleRole));
    QCOMPARE(changedSpy.count(), 1);

    // Read-only roles refuse the write.
    QVERIFY(!m_model->setData(index, 1, TaskListModel::OverdueRole));
}

void Tst_TaskListModel::getReturnsAJavaScriptFriendlyMap()
{
    m_model->addTask(QStringLiteral("inspect me"), QStringLiteral("notes"), Priority::Low);
    const QVariantMap map = m_model->get(0);

    QCOMPARE(map.value(QStringLiteral("title")).toString(), QStringLiteral("inspect me"));
    QCOMPARE(map.value(QStringLiteral("notes")).toString(), QStringLiteral("notes"));
    QCOMPARE(map.value(QStringLiteral("priority")).toInt(), int(Priority::Low));
    QCOMPARE(map.value(QStringLiteral("row")).toInt(), 0);

    QVERIFY(m_model->get(-1).isEmpty());
}

void Tst_TaskListModel::saveAndLoadUseTheStoragePath()
{
    m_model->addTask(QStringLiteral("persisted"));
    QVERIFY(m_model->save());
    QVERIFY(QFile::exists(m_model->storagePath()));

    TaskListModel reloaded;
    reloaded.setStoragePath(m_model->storagePath());
    QSignalSpy resetSpy(&reloaded, &QAbstractItemModel::modelReset);

    QVERIFY(reloaded.load());
    QCOMPARE(resetSpy.count(), 1);
    QCOMPARE(reloaded.rowCount(), 1);
    QCOMPARE(reloaded.index(0, 0).data(TaskListModel::TitleRole).toString(),
             QStringLiteral("persisted"));
}

// ---------------------------------------------------------------------------
// The proxy model
// ---------------------------------------------------------------------------

void Tst_TaskListModel::filterHidesCompletedTasks()
{
    m_model->addTask(QStringLiteral("open"));
    m_model->addTask(QStringLiteral("finished"));
    m_model->toggleDone(1);

    TaskFilterModel proxy;
    QAbstractItemModelTester tester(&proxy, QAbstractItemModelTester::FailureReportingMode::Warning);
    proxy.setSourceModel(m_model);

    QCOMPARE(proxy.rowCount(), 2);

    QSignalSpy countSpy(&proxy, &TaskFilterModel::countChanged);
    proxy.setShowCompleted(false);

    QCOMPARE(proxy.rowCount(), 1);
    QVERIFY(countSpy.count() >= 1);
    QCOMPARE(proxy.index(0, 0).data(TaskListModel::TitleRole).toString(), QStringLiteral("open"));
}

void Tst_TaskListModel::filterSearchesTitleAndNotes()
{
    m_model->addTask(QStringLiteral("buy milk"));
    m_model->addTask(QStringLiteral("read book"), QStringLiteral("about milk production"));
    m_model->addTask(QStringLiteral("call mum"));

    TaskFilterModel proxy;
    proxy.setSourceModel(m_model);

    proxy.setSearchText(QStringLiteral("MILK"));    // matching is case insensitive
    QCOMPARE(proxy.rowCount(), 2);

    proxy.setSearchText(QStringLiteral("   "));     // whitespace means "no filter"
    QCOMPARE(proxy.rowCount(), 3);

    proxy.setSearchText(QStringLiteral("nothing matches this"));
    QCOMPARE(proxy.rowCount(), 0);
}

void Tst_TaskListModel::sortByPriorityPutsHighFirst()
{
    m_model->addTask(QStringLiteral("low"), QString(), Priority::Low);
    m_model->addTask(QStringLiteral("high"), QString(), Priority::High);
    m_model->addTask(QStringLiteral("normal"), QString(), Priority::Normal);

    TaskFilterModel proxy;
    proxy.setSourceModel(m_model);
    proxy.setSortMode(TaskFilterModel::ByPriority);

    QCOMPARE(proxy.index(0, 0).data(TaskListModel::TitleRole).toString(), QStringLiteral("high"));
    QCOMPARE(proxy.index(1, 0).data(TaskListModel::TitleRole).toString(), QStringLiteral("normal"));
    QCOMPARE(proxy.index(2, 0).data(TaskListModel::TitleRole).toString(), QStringLiteral("low"));

    // Completed tasks always sink, whatever their priority.
    m_model->toggleDone(1);   // the "high" one
    QCOMPARE(proxy.index(2, 0).data(TaskListModel::TitleRole).toString(), QStringLiteral("high"));
}

void Tst_TaskListModel::sourceRowMapsBackToTheRealRow()
{
    m_model->addTask(QStringLiteral("aaa"));
    m_model->addTask(QStringLiteral("zzz"));
    m_model->addTask(QStringLiteral("mmm"));

    TaskFilterModel proxy;
    proxy.setSourceModel(m_model);
    proxy.setSortMode(TaskFilterModel::ByTitle);

    // Proxy row 0 is "aaa" (source row 0); proxy row 2 is "zzz" (source row 1).
    QCOMPARE(proxy.sourceRow(0), 0);
    QCOMPARE(proxy.sourceRow(1), 2);
    QCOMPARE(proxy.sourceRow(2), 1);
    QCOMPARE(proxy.sourceRow(99), -1);

    // This is exactly what TasksPage.qml does before calling a command.
    QVERIFY(m_model->toggleDone(proxy.sourceRow(2)));
    QCOMPARE(m_model->index(1, 0).data(TaskListModel::DoneRole).toBool(), true);
}

QTEST_GUILESS_MAIN(Tst_TaskListModel)
#include "tst_tasklistmodel.moc"

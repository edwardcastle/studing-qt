#pragma once

// ---------------------------------------------------------------------------
// TaskListModel.h -- the bridge between C++ data and Qt's view classes.
//
// TEACHING NOTE
// Qt views (ListView in QML, QListView in Widgets) never own data. They ask a
// *model* three questions:
//
//     rowCount()   "how many rows do you have?"
//     data(index, role)  "give me piece <role> of row <index>"
//     roleNames()  "what are those roles called in QML?"
//
// and they listen to signals to know when something changed. The contract is
// strict: before you insert rows you must call beginInsertRows()/endInsertRows(),
// before you remove them beginRemoveRows()/endRemoveRows(), and after an
// in-place edit you must emit dataChanged(). Break that contract and the view
// will show stale data or crash. QAbstractItemModelTester (used in the unit
// tests) exists exactly to catch those mistakes.
// ---------------------------------------------------------------------------

#include "core/TaskStore.h"

#include <QAbstractListModel>
#include <QDateTime>
#include <QString>
#include <QTimer>
#include <QVariantMap>

#include <QtQmlIntegration/qqmlintegration.h>

namespace devboard {

class TaskListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT   // -> usable in QML as `TaskListModel { }` after importing DevBoard

    // Q_PROPERTY is how C++ state becomes *bindable* in QML. The NOTIFY signal
    // is not optional decoration: it is what makes `text: model.openCount`
    // update itself when the number changes.
    Q_PROPERTY(int count READ count NOTIFY countsChanged)
    Q_PROPERTY(int openCount READ openCount NOTIFY countsChanged)
    Q_PROPERTY(int doneCount READ doneCount NOTIFY countsChanged)
    Q_PROPERTY(int overdueCount READ overdueCount NOTIFY countsChanged)
    Q_PROPERTY(QString storagePath READ storagePath CONSTANT)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)

public:
    /// The named pieces of a row. Custom roles must start at Qt::UserRole.
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        NotesRole,
        PriorityRole,
        PriorityLabelRole,
        DoneRole,
        CreatedAtRole,
        DueDateRole,
        DueDateLabelRole,
        OverdueRole,
    };
    Q_ENUM(Roles)

    explicit TaskListModel(QObject *parent = nullptr);

    // --- QAbstractListModel interface --------------------------------------
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    bool setData(const QModelIndex &index, const QVariant &value, int role) override;
    Qt::ItemFlags flags(const QModelIndex &index) const override;
    QHash<int, QByteArray> roleNames() const override;

    // --- Properties --------------------------------------------------------
    int count() const;
    int openCount() const;
    int doneCount() const;
    int overdueCount() const;
    QString storagePath() const { return m_storagePath; }
    QString statusMessage() const { return m_statusMessage; }

    // --- Commands callable from QML ----------------------------------------
    // Q_INVOKABLE marks a normal method as callable from QML. (Slots are
    // callable too; Q_INVOKABLE says "this is an action, not a signal handler".)

    /// Returns the new row index, or -1 when the title was empty.
    Q_INVOKABLE int addTask(const QString &title,
                            const QString &notes = QString(),
                            int priority = Priority::Normal,
                            const QDateTime &dueDate = QDateTime());

    Q_INVOKABLE bool updateTask(int row,
                                const QString &title,
                                const QString &notes,
                                int priority,
                                const QDateTime &dueDate);

    Q_INVOKABLE bool removeTask(int row);
    Q_INVOKABLE bool toggleDone(int row);
    Q_INVOKABLE int clearCompleted();

    /// Handy for dialogs: one row as a JS object, e.g. `var t = model.get(3)`.
    Q_INVOKABLE QVariantMap get(int row) const;

    /// Fills an empty board with a few examples so the UI is never blank.
    Q_INVOKABLE void addSampleTasks();

    // --- Persistence -------------------------------------------------------
    Q_INVOKABLE bool load();
    Q_INVOKABLE bool save();

    /// Overrides the default location. Used by the unit tests.
    void setStoragePath(const QString &path);

    /// Read-only view of the underlying data (tests, other C++ code).
    const TaskStore &store() const { return m_store; }

signals:
    void countsChanged();
    void statusMessageChanged();

private:
    bool isValidRow(int row) const;
    void notifyRowChanged(int row);
    void setStatusMessage(const QString &message);
    void scheduleAutoSave();

    TaskStore m_store;
    QString m_storagePath;
    QString m_statusMessage;

    /// Debounced auto-save: many quick edits collapse into one disk write.
    QTimer m_autoSaveTimer;
};

} // namespace devboard

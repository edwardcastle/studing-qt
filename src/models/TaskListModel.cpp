#include "TaskListModel.h"

#include <QLocale>
#include <QStandardPaths>

namespace devboard {

namespace {

/// Default file: ~/.local/share/DevBoard/tasks.json on Linux, the equivalent
/// per-user location on macOS and Windows. Never hard code paths.
QString defaultStoragePath()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return dir + QStringLiteral("/tasks.json");
}

QString humanDueDate(const QDateTime &dueDate)
{
    if (!dueDate.isValid())
        return QString();

    const QDateTime now = QDateTime::currentDateTime();
    const qint64 days = now.date().daysTo(dueDate.date());
    if (days == 0)
        return QStringLiteral("today");
    if (days == 1)
        return QStringLiteral("tomorrow");
    if (days == -1)
        return QStringLiteral("yesterday");
    if (days < 0)
        return QStringLiteral("%1 days ago").arg(-days);
    if (days < 7)
        return QStringLiteral("in %1 days").arg(days);
    return QLocale().toString(dueDate.date(), QLocale::ShortFormat);
}

} // namespace

TaskListModel::TaskListModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_storagePath(defaultStoragePath())
{
    m_autoSaveTimer.setSingleShot(true);
    m_autoSaveTimer.setInterval(400);
    connect(&m_autoSaveTimer, &QTimer::timeout, this, [this] { save(); });
}

// ---------------------------------------------------------------------------
// QAbstractListModel interface
// ---------------------------------------------------------------------------

int TaskListModel::rowCount(const QModelIndex &parent) const
{
    // A *list* model has rows only at the top level. Returning 0 for any valid
    // parent is what makes it a list rather than a tree -- this check is
    // mandatory, and QAbstractItemModelTester will complain if you forget it.
    if (parent.isValid())
        return 0;
    return m_store.count();
}

QVariant TaskListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || !isValidRow(index.row()))
        return {};

    const Task &task = m_store.tasks()[static_cast<size_t>(index.row())];

    switch (role) {
    case IdRole:
        return task.id;
    case TitleRole:
    case Qt::DisplayRole:               // so Widgets views show something too
        return task.title;
    case NotesRole:
        return task.notes;
    case PriorityRole:
        return static_cast<int>(task.priority);
    case PriorityLabelRole:
        return Priority::label(task.priority);
    case DoneRole:
        return task.done;
    case CreatedAtRole:
        return task.createdAt;
    case DueDateRole:
        return task.dueDate;
    case DueDateLabelRole:
        return humanDueDate(task.dueDate);
    case OverdueRole:
        return task.isOverdue();
    default:
        return {};
    }
}

bool TaskListModel::setData(const QModelIndex &index, const QVariant &value, int role)
{
    if (!index.isValid() || !isValidRow(index.row()))
        return false;

    const auto stored = m_store.at(index.row());
    if (!stored)
        return false;

    Task updated = *stored;
    switch (role) {
    case TitleRole:
    case Qt::EditRole:
        updated.title = value.toString();
        break;
    case NotesRole:
        updated.notes = value.toString();
        break;
    case PriorityRole:
        updated.priority = static_cast<Priority::Level>(value.toInt());
        break;
    case DoneRole:
        updated.done = value.toBool();
        break;
    case DueDateRole:
        updated.dueDate = value.toDateTime();
        break;
    default:
        return false;   // read-only roles
    }

    if (updated == *stored)
        return true;    // nothing changed: succeed, but do not emit anything

    if (!m_store.updateTask(updated.id, updated))
        return false;

    notifyRowChanged(index.row());
    return true;
}

Qt::ItemFlags TaskListModel::flags(const QModelIndex &index) const
{
    if (!index.isValid())
        return Qt::NoItemFlags;
    return QAbstractListModel::flags(index) | Qt::ItemIsEditable;
}

QHash<int, QByteArray> TaskListModel::roleNames() const
{
    // These names are what QML delegates see. `title` in QML == TitleRole here.
    return {
        { IdRole, "taskId" },
        { TitleRole, "title" },
        { NotesRole, "notes" },
        { PriorityRole, "priority" },
        { PriorityLabelRole, "priorityLabel" },
        { DoneRole, "done" },
        { CreatedAtRole, "createdAt" },
        { DueDateRole, "dueDate" },
        { DueDateLabelRole, "dueDateLabel" },
        { OverdueRole, "overdue" },
    };
}

// ---------------------------------------------------------------------------
// Properties
// ---------------------------------------------------------------------------

int TaskListModel::count() const { return m_store.count(); }
int TaskListModel::openCount() const { return m_store.openCount(); }
int TaskListModel::doneCount() const { return m_store.doneCount(); }
int TaskListModel::overdueCount() const { return m_store.overdueCount(); }

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

int TaskListModel::addTask(const QString &title,
                           const QString &notes,
                           int priority,
                           const QDateTime &dueDate)
{
    Task task;
    task.title = title;
    task.notes = notes;
    task.priority = static_cast<Priority::Level>(priority);
    task.dueDate = dueDate;

    const int newRow = m_store.count();

    // The two calls below *must* wrap the mutation. Between them the model is
    // allowed to be inconsistent; outside of them it never may be.
    beginInsertRows(QModelIndex(), newRow, newRow);
    const int id = m_store.addTask(std::move(task));
    endInsertRows();

    if (id == 0) {
        // The store rejected it (blank title). We already told the view a row
        // appeared, so tell it the truth again.
        beginRemoveRows(QModelIndex(), newRow, newRow);
        endRemoveRows();
        setStatusMessage(QStringLiteral("A task needs a title."));
        return -1;
    }

    emit countsChanged();
    setStatusMessage(QStringLiteral("Added \"%1\".").arg(title.trimmed()));
    scheduleAutoSave();
    return newRow;
}

bool TaskListModel::updateTask(int row,
                               const QString &title,
                               const QString &notes,
                               int priority,
                               const QDateTime &dueDate)
{
    if (!isValidRow(row))
        return false;

    const auto stored = m_store.at(row);
    if (!stored)
        return false;

    Task updated = *stored;
    updated.title = title;
    updated.notes = notes;
    updated.priority = static_cast<Priority::Level>(priority);
    updated.dueDate = dueDate;

    if (!m_store.updateTask(updated.id, updated)) {
        setStatusMessage(QStringLiteral("A task needs a title."));
        return false;
    }

    notifyRowChanged(row);
    setStatusMessage(QStringLiteral("Updated \"%1\".").arg(updated.title));
    return true;
}

bool TaskListModel::removeTask(int row)
{
    if (!isValidRow(row))
        return false;

    const auto stored = m_store.at(row);
    if (!stored)
        return false;

    beginRemoveRows(QModelIndex(), row, row);
    const bool removed = m_store.removeTask(stored->id);
    endRemoveRows();

    if (!removed)
        return false;

    emit countsChanged();
    setStatusMessage(QStringLiteral("Removed \"%1\".").arg(stored->title));
    scheduleAutoSave();
    return true;
}

bool TaskListModel::toggleDone(int row)
{
    if (!isValidRow(row))
        return false;

    const auto stored = m_store.at(row);
    if (!stored)
        return false;

    if (!m_store.setDone(stored->id, !stored->done))
        return false;

    notifyRowChanged(row);
    return true;
}

int TaskListModel::clearCompleted()
{
    if (m_store.doneCount() == 0)
        return 0;

    // Completed rows can be scattered anywhere, so the simplest *correct* thing
    // is a full reset. beginResetModel() tells every attached view: "drop
    // everything you know, I will tell you when I am done".
    beginResetModel();
    const int removed = m_store.removeCompleted();
    endResetModel();

    emit countsChanged();
    setStatusMessage(QStringLiteral("Cleared %1 completed task(s).").arg(removed));
    scheduleAutoSave();
    return removed;
}

QVariantMap TaskListModel::get(int row) const
{
    QVariantMap map;
    if (!isValidRow(row))
        return map;

    const QModelIndex idx = index(row, 0);
    const QHash<int, QByteArray> names = roleNames();
    for (auto it = names.cbegin(); it != names.cend(); ++it)
        map.insert(QString::fromUtf8(it.value()), data(idx, it.key()));
    map.insert(QStringLiteral("row"), row);
    return map;
}

void TaskListModel::addSampleTasks()
{
    const QDateTime now = QDateTime::currentDateTime();
    addTask(QStringLiteral("Read docs/02-cpp-and-qml.md"),
            QStringLiteral("Understand how Q_PROPERTY and Q_INVOKABLE reach QML."),
            Priority::High, now.addDays(1));
    addTask(QStringLiteral("Add a \"tags\" field to Task"),
            QStringLiteral("Touches Task, TaskStore, TaskListModel roles and the QML delegate."),
            Priority::Normal, now.addDays(3));
    addTask(QStringLiteral("Scan a big folder and watch the UI stay responsive"),
            QStringLiteral("Open the Scanner tab, start a scan, resize the window while it runs."),
            Priority::Low, QDateTime());
}

// ---------------------------------------------------------------------------
// Persistence
// ---------------------------------------------------------------------------

bool TaskListModel::load()
{
    QString error;

    beginResetModel();
    const bool ok = m_store.loadFromFile(m_storagePath, &error);
    endResetModel();

    emit countsChanged();
    setStatusMessage(ok ? QStringLiteral("Loaded %1 task(s).").arg(m_store.count())
                        : QStringLiteral("Load failed: %1").arg(error));
    return ok;
}

bool TaskListModel::save()
{
    QString error;
    const bool ok = m_store.saveToFile(m_storagePath, &error);
    if (!ok)
        setStatusMessage(QStringLiteral("Save failed: %1").arg(error));
    return ok;
}

void TaskListModel::setStoragePath(const QString &path)
{
    m_storagePath = path;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool TaskListModel::isValidRow(int row) const
{
    return row >= 0 && row < m_store.count();
}

void TaskListModel::notifyRowChanged(int row)
{
    const QModelIndex idx = index(row, 0);

    // Passing an empty role list means "every role of this row changed". You
    // can pass the exact roles instead when you know them; that lets the view
    // skip work.
    emit dataChanged(idx, idx);
    emit countsChanged();
    scheduleAutoSave();
}

void TaskListModel::setStatusMessage(const QString &message)
{
    if (m_statusMessage == message)
        return;
    m_statusMessage = message;
    emit statusMessageChanged();
}

void TaskListModel::scheduleAutoSave()
{
    // start() on a running single-shot timer restarts it, so a burst of edits
    // results in exactly one write 400 ms after the last one.
    m_autoSaveTimer.start();
}

} // namespace devboard

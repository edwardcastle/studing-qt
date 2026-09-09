#include "TaskStore.h"

#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonParseError>
#include <QSaveFile>

#include <algorithm>

namespace devboard {

int TaskStore::indexOfId(int id) const
{
    // std::find_if + a lambda is the idiomatic modern C++ "search a container".
    const auto it = std::find_if(m_tasks.begin(), m_tasks.end(),
                                 [id](const Task &task) { return task.id == id; });
    if (it == m_tasks.end())
        return -1;
    return static_cast<int>(std::distance(m_tasks.begin(), it));
}

std::optional<Task> TaskStore::at(int index) const
{
    if (index < 0 || index >= count())
        return std::nullopt;   // "no value", instead of returning a dummy Task
    return m_tasks[static_cast<size_t>(index)];
}

int TaskStore::openCount() const
{
    return static_cast<int>(std::count_if(m_tasks.begin(), m_tasks.end(),
                                          [](const Task &task) { return !task.done; }));
}

int TaskStore::doneCount() const
{
    return count() - openCount();
}

int TaskStore::overdueCount() const
{
    const QDateTime now = QDateTime::currentDateTime();
    return static_cast<int>(std::count_if(m_tasks.begin(), m_tasks.end(),
                                          [&now](const Task &task) { return task.isOverdue(now); }));
}

int TaskStore::addTask(Task task)
{
    // Validation belongs here, in the core, not in the UI. The UI may also
    // disable its "Add" button, but the rule must hold even if it does not.
    task.title = task.title.trimmed();
    if (task.title.isEmpty())
        return 0;

    task.id = m_nextId++;
    if (!task.createdAt.isValid())
        task.createdAt = QDateTime::currentDateTime();

    m_tasks.push_back(std::move(task));
    return m_tasks.back().id;
}

bool TaskStore::updateTask(int id, Task task)
{
    const int index = indexOfId(id);
    if (index < 0)
        return false;

    task.title = task.title.trimmed();
    if (task.title.isEmpty())
        return false;

    Task &stored = m_tasks[static_cast<size_t>(index)];

    // Identity fields are owned by the store, not by the caller: whatever the
    // caller put in `task.id` / `task.createdAt` is ignored on purpose.
    task.id = stored.id;
    task.createdAt = stored.createdAt;
    stored = std::move(task);
    return true;
}

bool TaskStore::removeTask(int id)
{
    const int index = indexOfId(id);
    if (index < 0)
        return false;
    m_tasks.erase(m_tasks.begin() + index);
    return true;
}

bool TaskStore::setDone(int id, bool done)
{
    const int index = indexOfId(id);
    if (index < 0)
        return false;

    Task &stored = m_tasks[static_cast<size_t>(index)];
    if (stored.done == done)
        return false;   // no actual change -> the caller can skip its signal
    stored.done = done;
    return true;
}

int TaskStore::removeCompleted()
{
    // The erase-remove idiom: std::remove_if shuffles the elements to keep to
    // the front and returns the new logical end; erase() then drops the tail.
    const auto newEnd = std::remove_if(m_tasks.begin(), m_tasks.end(),
                                       [](const Task &task) { return task.done; });
    const int removed = static_cast<int>(std::distance(newEnd, m_tasks.end()));
    m_tasks.erase(newEnd, m_tasks.end());
    return removed;
}

void TaskStore::clear()
{
    m_tasks.clear();
    m_nextId = 1;
}

QJsonDocument TaskStore::toJson() const
{
    QJsonArray array;
    for (const Task &task : m_tasks)
        array.append(task.toJson());

    // A top-level object (rather than a bare array) leaves room to add fields
    // later without breaking readers -- always version your file formats.
    QJsonObject root;
    root[QStringLiteral("version")] = 1;
    root[QStringLiteral("nextId")] = m_nextId;
    root[QStringLiteral("tasks")] = array;
    return QJsonDocument(root);
}

bool TaskStore::loadFromJson(const QJsonDocument &document, QString *errorMessage)
{
    const auto fail = [errorMessage](const QString &message) {
        if (errorMessage)
            *errorMessage = message;
        return false;
    };

    if (!document.isObject())
        return fail(QStringLiteral("Expected a JSON object at the top level."));

    const QJsonObject root = document.object();
    const QJsonValue tasksValue = root.value(QStringLiteral("tasks"));
    if (!tasksValue.isArray())
        return fail(QStringLiteral("Missing or invalid \"tasks\" array."));

    // Parse into a temporary first: if anything goes wrong halfway through we
    // must not leave the store in a half-updated state (strong exception /
    // error safety).
    std::vector<Task> parsed;
    int highestId = 0;
    const QJsonArray array = tasksValue.toArray();
    parsed.reserve(static_cast<size_t>(array.size()));

    for (const QJsonValue &value : array) {
        if (!value.isObject())
            return fail(QStringLiteral("A task entry is not an object."));
        Task task = Task::fromJson(value.toObject());
        if (task.title.trimmed().isEmpty())
            continue;   // skip junk rows rather than refusing the whole file
        highestId = std::max(highestId, task.id);
        parsed.push_back(std::move(task));
    }

    m_tasks = std::move(parsed);
    m_nextId = std::max(root.value(QStringLiteral("nextId")).toInt(1), highestId + 1);

    // Any row that arrived without an id gets one now, so ids stay unique.
    for (Task &task : m_tasks) {
        if (task.id <= 0)
            task.id = m_nextId++;
    }
    return true;
}

bool TaskStore::saveToFile(const QString &filePath, QString *errorMessage) const
{
    const auto fail = [errorMessage](const QString &message) {
        if (errorMessage)
            *errorMessage = message;
        return false;
    };

    QDir().mkpath(QFileInfo(filePath).absolutePath());

    // QSaveFile writes to a temporary file and renames it on commit(). If the
    // program crashes mid-write the previous file is still intact -- this is
    // the safe way to overwrite user data.
    QSaveFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return fail(QStringLiteral("Cannot open %1: %2").arg(filePath, file.errorString()));

    file.write(toJson().toJson(QJsonDocument::Indented));
    if (!file.commit())
        return fail(QStringLiteral("Cannot write %1: %2").arg(filePath, file.errorString()));
    return true;
}

bool TaskStore::loadFromFile(const QString &filePath, QString *errorMessage)
{
    const auto fail = [errorMessage](const QString &message) {
        if (errorMessage)
            *errorMessage = message;
        return false;
    };

    QFile file(filePath);
    if (!file.exists()) {
        // A missing file on first start is normal, not an error.
        clear();
        return true;
    }
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return fail(QStringLiteral("Cannot open %1: %2").arg(filePath, file.errorString()));

    QJsonParseError parseError {};
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError)
        return fail(QStringLiteral("Invalid JSON in %1: %2").arg(filePath, parseError.errorString()));

    return loadFromJson(document, errorMessage);
}

} // namespace devboard

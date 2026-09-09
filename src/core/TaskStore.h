#pragma once

// ---------------------------------------------------------------------------
// TaskStore.h -- the business logic of the "Tasks" feature.
//
// TEACHING NOTE
// This class knows *nothing* about Qt Quick, QML, models or views. It is the
// part of the program you could reuse in a command line tool, a server, or a
// different UI toolkit. That is why the unit tests in tests/tst_taskstore.cpp
// can run without creating a single window.
//
// The layering used in this project:
//
//     QML (src/qml)            <- what the user sees
//        ^ properties/signals
//     Models (src/models)      <- adapts C++ data to Qt's model/view protocol
//        ^ plain function calls
//     Core  (src/core)         <- the rules of the application  <-- YOU ARE HERE
//
// Dependencies only ever point downwards. Core never calls up into the UI; it
// just returns values and lets the layer above decide what to show.
// ---------------------------------------------------------------------------

#include "Task.h"

#include <QJsonDocument>
#include <QString>

#include <optional>
#include <vector>

namespace devboard {

class TaskStore
{
public:
    TaskStore() = default;

    // --- Reading -----------------------------------------------------------

    /// Direct read-only access to the rows, in storage order.
    const std::vector<Task> &tasks() const { return m_tasks; }

    int count() const { return static_cast<int>(m_tasks.size()); }
    bool isEmpty() const { return m_tasks.empty(); }

    /// Row index of the task with this id, or -1 when there is no such task.
    int indexOfId(int id) const;

    /// Copy of a task by row index. Returns std::nullopt for an invalid index.
    std::optional<Task> at(int index) const;

    int openCount() const;      ///< tasks that are not done yet
    int doneCount() const;
    int overdueCount() const;   ///< not done and past their due date

    // --- Writing -----------------------------------------------------------
    // Every mutating call returns something the caller can check, so the model
    // layer above can decide whether it needs to emit a signal.

    /// Appends a task, assigns it a fresh id and a createdAt stamp when unset.
    /// Returns the id of the new task, or 0 when the title is blank.
    int addTask(Task task);

    /// Replaces the task with `id`. The id and createdAt of the stored task are
    /// preserved. Returns false when there is no such task or the title is blank.
    bool updateTask(int id, Task task);

    bool removeTask(int id);
    bool setDone(int id, bool done);

    /// Removes every completed task. Returns how many were removed.
    int removeCompleted();

    void clear();

    // --- Persistence -------------------------------------------------------

    QJsonDocument toJson() const;

    /// Replaces the whole content from a JSON document previously written by
    /// toJson(). On failure the store is left untouched and `errorMessage`
    /// (when not null) is filled in.
    bool loadFromJson(const QJsonDocument &document, QString *errorMessage = nullptr);

    bool saveToFile(const QString &filePath, QString *errorMessage = nullptr) const;
    bool loadFromFile(const QString &filePath, QString *errorMessage = nullptr);

private:
    std::vector<Task> m_tasks;
    int m_nextId = 1;
};

} // namespace devboard

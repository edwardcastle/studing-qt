#pragma once

// ---------------------------------------------------------------------------
// Task.h -- the domain type of the "Tasks" feature.
//
// TEACHING NOTE
// This header is deliberately *boring* C++. `Task` is a plain struct with value
// semantics: you can copy it, put it in a std::vector, compare it, and test it
// without ever creating a window, a QApplication or a QML engine.
//
// A very common beginner mistake in Qt is to make every row of a list a
// QObject. QObjects are heavy (each one has a QMetaObject, a signal/slot
// connection list, a parent/child relationship) and they are *not copyable*.
// Rule of thumb:
//   * QObject  -> for things with identity and a lifetime that emit signals
//                 (a model, a controller, a network job).
//   * struct   -> for data (a row, a message, a configuration value).
// ---------------------------------------------------------------------------

#include <QDateTime>
#include <QJsonObject>
#include <QObject>
#include <QString>

#include <QtQmlIntegration/qqmlintegration.h>

namespace devboard {

// A namespace-scoped enum that is still visible to QML and to QMetaType.
//
//   Q_NAMESPACE  : gives this namespace a QMetaObject (so the enum gets
//                  reflection: names <-> values at runtime).
//   Q_ENUM_NS    : registers the enum with that QMetaObject.
//   QML_ELEMENT  : makes it importable from QML as `Priority.High`, etc.
//
// Without Q_ENUM_NS the enum would still work in C++, but QML and
// QVariant::toString() would only ever see a raw integer.
namespace Priority {
Q_NAMESPACE
QML_ELEMENT

enum Level {
    Low = 0,
    Normal = 1,
    High = 2,
};
Q_ENUM_NS(Level)

/// Human readable label, used by the UI and by the JSON writer.
/// NOTE: deliberately not called toString() -- Qt Test finds a free function
/// named toString() by argument-dependent lookup and would try to use it to
/// print failures, which produces a very confusing compile error.
QString label(Level level);

/// Parse back from the string produced by label(). Unknown -> Normal.
Level fromLabel(const QString &text);
} // namespace Priority

/// One row of the task list. Pure data, no Qt object machinery.
struct Task
{
    int id = 0;                                   ///< 0 means "not stored yet".
    QString title;
    QString notes;
    Priority::Level priority = Priority::Normal;
    bool done = false;
    QDateTime createdAt;
    QDateTime dueDate;                            ///< invalid QDateTime == no due date.

    /// True when the task still has to be done and its due date is in the past.
    bool isOverdue(const QDateTime &now = QDateTime::currentDateTime()) const;

    // --- Serialisation -----------------------------------------------------
    // Keeping (de)serialisation next to the data keeps the persistence rules in
    // one place; TaskStore only decides *where* the bytes go.
    QJsonObject toJson() const;
    static Task fromJson(const QJsonObject &object);
};

/// Value semantics means we can compare tasks -- handy in unit tests.
bool operator==(const Task &lhs, const Task &rhs);
inline bool operator!=(const Task &lhs, const Task &rhs) { return !(lhs == rhs); }

} // namespace devboard

#include "Task.h"

namespace devboard {

namespace Priority {

QString label(Level level)
{
    switch (level) {
    case Low:
        return QStringLiteral("Low");
    case Normal:
        return QStringLiteral("Normal");
    case High:
        return QStringLiteral("High");
    }
    // Defensive: an enum value we do not know about (e.g. from a newer file
    // format) degrades to "Normal" instead of crashing or writing garbage.
    return QStringLiteral("Normal");
}

Level fromLabel(const QString &text)
{
    if (text.compare(QLatin1String("Low"), Qt::CaseInsensitive) == 0)
        return Low;
    if (text.compare(QLatin1String("High"), Qt::CaseInsensitive) == 0)
        return High;
    return Normal;
}

} // namespace Priority

bool Task::isOverdue(const QDateTime &now) const
{
    if (done || !dueDate.isValid())
        return false;
    return dueDate < now;
}

QJsonObject Task::toJson() const
{
    QJsonObject object;
    object[QStringLiteral("id")] = id;
    object[QStringLiteral("title")] = title;
    object[QStringLiteral("notes")] = notes;
    object[QStringLiteral("priority")] = Priority::label(priority);
    object[QStringLiteral("done")] = done;

    // QDateTime has no direct JSON representation, so we store ISO-8601 text.
    //
    // Use ISODateWithMs, not ISODate: plain ISODate silently truncates the
    // milliseconds, so a value written and read back would not compare equal to
    // the original. That is the kind of bug a round-trip unit test catches
    // immediately and a manual click-through never does.
    //
    // Storing an *invalid* QDateTime as an empty string lets us distinguish
    // "no due date" from "due at the epoch".
    object[QStringLiteral("createdAt")] =
            createdAt.isValid() ? createdAt.toString(Qt::ISODateWithMs) : QString();
    object[QStringLiteral("dueDate")] =
            dueDate.isValid() ? dueDate.toString(Qt::ISODateWithMs) : QString();
    return object;
}

Task Task::fromJson(const QJsonObject &object)
{
    Task task;
    task.id = object.value(QStringLiteral("id")).toInt();
    task.title = object.value(QStringLiteral("title")).toString();
    task.notes = object.value(QStringLiteral("notes")).toString();
    task.priority = Priority::fromLabel(object.value(QStringLiteral("priority")).toString());
    task.done = object.value(QStringLiteral("done")).toBool();

    const QString created = object.value(QStringLiteral("createdAt")).toString();
    const QString due = object.value(QStringLiteral("dueDate")).toString();
    task.createdAt = created.isEmpty() ? QDateTime()
                                       : QDateTime::fromString(created, Qt::ISODateWithMs);
    task.dueDate = due.isEmpty() ? QDateTime()
                                 : QDateTime::fromString(due, Qt::ISODateWithMs);
    return task;
}

bool operator==(const Task &lhs, const Task &rhs)
{
    return lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.notes == rhs.notes
            && lhs.priority == rhs.priority
            && lhs.done == rhs.done
            && lhs.createdAt == rhs.createdAt
            && lhs.dueDate == rhs.dueDate;
}

} // namespace devboard

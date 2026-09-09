#include "TaskFilterModel.h"

#include "TaskListModel.h"

namespace devboard {

TaskFilterModel::TaskFilterModel(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    setDynamicSortFilter(true);   // re-apply the rules when the source changes

    // Keep the `count` property honest: it must change whenever the number of
    // visible rows changes, for any reason.
    connect(this, &QAbstractItemModel::rowsInserted, this, &TaskFilterModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &TaskFilterModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &TaskFilterModel::countChanged);

    sort(0);   // enables lessThan(); column 0 is the only column of a list model
}

void TaskFilterModel::setSearchText(const QString &text)
{
    if (m_searchText == text)
        return;
    m_searchText = text;
    invalidateFilter();          // "ask filterAcceptsRow() again for every row"
    emit searchTextChanged();
    emit countChanged();
}

void TaskFilterModel::setShowCompleted(bool show)
{
    if (m_showCompleted == show)
        return;
    m_showCompleted = show;
    invalidateFilter();
    emit showCompletedChanged();
    emit countChanged();
}

void TaskFilterModel::setSortMode(SortMode mode)
{
    if (m_sortMode == mode)
        return;
    m_sortMode = mode;
    invalidate();                // filtering *and* ordering may have changed
    sort(0);
    emit sortModeChanged();
}

int TaskFilterModel::sourceRow(int proxyRow) const
{
    const QModelIndex proxyIndex = index(proxyRow, 0);
    if (!proxyIndex.isValid())
        return -1;
    return mapToSource(proxyIndex).row();
}

bool TaskFilterModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    const QAbstractItemModel *source = sourceModel();
    if (!source)
        return false;

    const QModelIndex idx = source->index(sourceRow, 0, sourceParent);
    if (!idx.isValid())
        return false;

    if (!m_showCompleted && idx.data(TaskListModel::DoneRole).toBool())
        return false;

    if (m_searchText.trimmed().isEmpty())
        return true;

    const QString needle = m_searchText.trimmed();
    const QString title = idx.data(TaskListModel::TitleRole).toString();
    const QString notes = idx.data(TaskListModel::NotesRole).toString();
    return title.contains(needle, Qt::CaseInsensitive)
            || notes.contains(needle, Qt::CaseInsensitive);
}

bool TaskFilterModel::lessThan(const QModelIndex &left, const QModelIndex &right) const
{
    // Unfinished work always floats above finished work, whatever the sort mode.
    const bool leftDone = left.data(TaskListModel::DoneRole).toBool();
    const bool rightDone = right.data(TaskListModel::DoneRole).toBool();
    if (leftDone != rightDone)
        return !leftDone;

    switch (m_sortMode) {
    case ByCreated:
        return left.data(TaskListModel::CreatedAtRole).toDateTime()
                > right.data(TaskListModel::CreatedAtRole).toDateTime();

    case ByDueDate: {
        const QDateTime leftDue = left.data(TaskListModel::DueDateRole).toDateTime();
        const QDateTime rightDue = right.data(TaskListModel::DueDateRole).toDateTime();
        if (leftDue.isValid() != rightDue.isValid())
            return leftDue.isValid();   // "no due date" sinks to the bottom
        if (!leftDue.isValid())
            return false;               // neither has one: treat as equal
        return leftDue < rightDue;
    }

    case ByPriority: {
        const int leftPriority = left.data(TaskListModel::PriorityRole).toInt();
        const int rightPriority = right.data(TaskListModel::PriorityRole).toInt();
        if (leftPriority != rightPriority)
            return leftPriority > rightPriority;   // High(2) before Low(0)
        return left.data(TaskListModel::CreatedAtRole).toDateTime()
                > right.data(TaskListModel::CreatedAtRole).toDateTime();
    }

    case ByTitle:
        return left.data(TaskListModel::TitleRole).toString()
                .compare(right.data(TaskListModel::TitleRole).toString(),
                         Qt::CaseInsensitive) < 0;
    }
    return false;
}

} // namespace devboard

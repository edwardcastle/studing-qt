#pragma once

// ---------------------------------------------------------------------------
// TaskFilterModel.h -- searching, filtering and sorting *without* touching the
// data.
//
// TEACHING NOTE
// A proxy model sits between a source model and a view. It presents the same
// rows in a different order, or hides some of them, and forwards every change
// signal. The big win: TaskListModel stays simple and the sort/filter rules
// live in their own testable class.
//
//     TaskListModel (data)  ->  TaskFilterModel (view rules)  ->  ListView
//
// Two virtual functions do all the work:
//     filterAcceptsRow()  "should this source row be visible?"
//     lessThan()          "which of these two source rows comes first?"
//
// Whenever a rule changes you must call invalidateFilter() / re-sort so the
// proxy re-asks those questions.
// ---------------------------------------------------------------------------

#include <QSortFilterProxyModel>
#include <QString>

#include <QtQmlIntegration/qqmlintegration.h>

namespace devboard {

class TaskFilterModel : public QSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    Q_PROPERTY(bool showCompleted READ showCompleted WRITE setShowCompleted NOTIFY showCompletedChanged)
    Q_PROPERTY(SortMode sortMode READ sortMode WRITE setSortMode NOTIFY sortModeChanged)

    // `count` is not offered by QSortFilterProxyModel as a property, but QML
    // wants one for "3 of 12 shown" labels.
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum SortMode {
        ByCreated = 0,   ///< newest first
        ByDueDate,       ///< soonest first, tasks without a date last
        ByPriority,      ///< high first, then by due date
        ByTitle,         ///< alphabetical, case insensitive
    };
    Q_ENUM(SortMode)

    explicit TaskFilterModel(QObject *parent = nullptr);

    QString searchText() const { return m_searchText; }
    void setSearchText(const QString &text);

    bool showCompleted() const { return m_showCompleted; }
    void setShowCompleted(bool show);

    SortMode sortMode() const { return m_sortMode; }
    void setSortMode(SortMode mode);

    int count() const { return rowCount(); }

    /// QML works with proxy rows; the commands on TaskListModel want source
    /// rows. This converts between the two.
    Q_INVOKABLE int sourceRow(int proxyRow) const;

signals:
    void searchTextChanged();
    void showCompletedChanged();
    void sortModeChanged();
    void countChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;
    bool lessThan(const QModelIndex &left, const QModelIndex &right) const override;

private:
    QString m_searchText;
    bool m_showCompleted = true;
    SortMode m_sortMode = ByCreated;
};

} // namespace devboard

#pragma once

// ---------------------------------------------------------------------------
// ScanResultModel.h -- a second, much smaller QAbstractListModel.
//
// TEACHING NOTE
// Compare this file with TaskListModel: same three overrides, no commands. Most
// models in real applications look like this one. Writing a model is a habit,
// not a big architecture decision.
//
// Note also that this model is filled in *one* go, from a value that arrived
// over a cross-thread signal. Populating a model row by row from a worker
// thread is the classic way to make a threaded program feel slower than a
// single threaded one.
// ---------------------------------------------------------------------------

#include "scanner/ScanTypes.h"

#include <QAbstractListModel>

#include <QtQmlIntegration/qqmlintegration.h>

namespace devboard {

class ScanResultModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        ExtensionRole = Qt::UserRole + 1,
        FileCountRole,
        TotalBytesRole,
        SizeLabelRole,
        SharePercentRole,   ///< share of the whole scan, 0..100
    };
    Q_ENUM(Roles)

    explicit ScanResultModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    /// Replaces the whole content in one reset.
    void setStats(const QList<ExtensionStat> &stats, qint64 totalBytes);
    void clearStats();

signals:
    void countChanged();

private:
    QList<ExtensionStat> m_stats;
    qint64 m_totalBytes = 0;
};

} // namespace devboard

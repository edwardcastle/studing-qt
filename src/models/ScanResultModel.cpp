#include "ScanResultModel.h"

#include <QLocale>

namespace devboard {

ScanResultModel::ScanResultModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int ScanResultModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return static_cast<int>(m_stats.size());
}

QVariant ScanResultModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_stats.size())
        return {};

    const ExtensionStat &stat = m_stats.at(index.row());
    switch (role) {
    case ExtensionRole:
    case Qt::DisplayRole:
        return stat.extension.isEmpty() ? QStringLiteral("(no extension)")
                                        : QStringLiteral(".%1").arg(stat.extension);
    case FileCountRole:
        return stat.fileCount;
    case TotalBytesRole:
        return static_cast<qlonglong>(stat.totalBytes);
    case SizeLabelRole:
        // QLocale::formattedDataSize gives "1.2 MB" in the user's language.
        return QLocale().formattedDataSize(stat.totalBytes);
    case SharePercentRole:
        return m_totalBytes > 0 ? (100.0 * double(stat.totalBytes) / double(m_totalBytes)) : 0.0;
    default:
        return {};
    }
}

QHash<int, QByteArray> ScanResultModel::roleNames() const
{
    return {
        { ExtensionRole, "extension" },
        { FileCountRole, "fileCount" },
        { TotalBytesRole, "totalBytes" },
        { SizeLabelRole, "sizeLabel" },
        { SharePercentRole, "sharePercent" },
    };
}

void ScanResultModel::setStats(const QList<ExtensionStat> &stats, qint64 totalBytes)
{
    beginResetModel();
    m_stats = stats;
    m_totalBytes = totalBytes;
    endResetModel();
    emit countChanged();
}

void ScanResultModel::clearStats()
{
    if (m_stats.isEmpty())
        return;
    beginResetModel();
    m_stats.clear();
    m_totalBytes = 0;
    endResetModel();
    emit countChanged();
}

} // namespace devboard

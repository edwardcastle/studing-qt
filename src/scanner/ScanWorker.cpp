#include "ScanWorker.h"

#include <QDirIterator>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QHash>
#include <QThread>

#include <algorithm>

namespace devboard {

ScanWorker::ScanWorker(QObject *parent)
    : QObject(parent)
{
}

void ScanWorker::requestCancel()
{
    // std::atomic guarantees this store is visible to the worker thread without
    // a mutex and without undefined behaviour. A plain `bool` here would be a
    // data race, even though it "seems to work" in practice.
    m_cancelRequested.store(true, std::memory_order_relaxed);
}

void ScanWorker::scan(const QString &rootPath)
{
    m_cancelRequested.store(false, std::memory_order_relaxed);

    const QFileInfo rootInfo(rootPath);
    if (!rootInfo.exists() || !rootInfo.isDir()) {
        emit failed(QStringLiteral("\"%1\" is not a readable directory.").arg(rootPath));
        return;
    }

    ScanSummary summary;
    summary.rootPath = rootInfo.absoluteFilePath();

    QHash<QString, ExtensionStat> byExtension;

    // QDirIterator walks the tree lazily, so memory stays flat even on huge
    // directories. Symlinks are not followed: that avoids infinite loops.
    QDirIterator it(summary.rootPath,
                    QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden,
                    QDirIterator::Subdirectories);

    QElapsedTimer sinceLastReport;
    sinceLastReport.start();

    while (it.hasNext()) {
        const QString path = it.next();

        if (m_cancelRequested.load(std::memory_order_relaxed)) {
            summary.canceled = true;
            break;
        }

        const QFileInfo info = it.fileInfo();
        if (info.isDir()) {
            ++summary.directoryCount;
            continue;
        }

        ++summary.fileCount;
        summary.totalBytes += info.size();

        const QString extension = info.suffix().toLower();
        ExtensionStat &stat = byExtension[extension];   // default-constructs on first use
        stat.extension = extension;
        ++stat.fileCount;
        stat.totalBytes += info.size();

        // Throttle: emitting a signal per file would post millions of events to
        // the GUI thread and make the whole app crawl.
        if (sinceLastReport.elapsed() >= 80) {
            emit progress(summary.fileCount, summary.totalBytes, info.absoluteFilePath());
            sinceLastReport.restart();
        }
    }

    summary.extensions = byExtension.values();
    std::sort(summary.extensions.begin(), summary.extensions.end(),
              [](const ExtensionStat &lhs, const ExtensionStat &rhs) {
                  if (lhs.totalBytes != rhs.totalBytes)
                      return lhs.totalBytes > rhs.totalBytes;
                  return lhs.extension < rhs.extension;
              });

    emit progress(summary.fileCount, summary.totalBytes, QString());
    emit finished(summary);
}

} // namespace devboard

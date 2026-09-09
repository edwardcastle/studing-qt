#include "ScannerController.h"

#include "scanner/ScanWorker.h"

#include <QDir>
#include <QLocale>
#include <QStandardPaths>

namespace devboard {

ScannerController::ScannerController(QObject *parent)
    : QObject(parent)
    , m_worker(new ScanWorker)   // no parent: moveToThread() requires that
{
    // Step 1: give the worker a different thread affinity.
    m_worker->moveToThread(&m_thread);

    // Step 2: let the thread own the worker's destruction.
    connect(&m_thread, &QThread::finished, m_worker, &QObject::deleteLater);

    // Step 3: wire the two directions. Because sender and receiver live on
    // different threads, Qt turns these into queued connections automatically:
    // the call is packed into an event and executed by the receiver's thread.
    connect(this, &ScannerController::scanRequested, m_worker, &ScanWorker::scan);
    connect(m_worker, &ScanWorker::progress, this, &ScannerController::onProgress);
    connect(m_worker, &ScanWorker::finished, this, &ScannerController::onFinished);
    connect(m_worker, &ScanWorker::failed, this, &ScannerController::onFailed);

    m_thread.setObjectName(QStringLiteral("scan-worker"));   // shows up in debuggers
    m_thread.start();

    m_rootPath = defaultScanPath();
    m_statusText = QStringLiteral("Pick a folder and press Scan.");
}

ScannerController::~ScannerController()
{
    // Shutting a worker thread down cleanly, in order:
    //   1. ask the current job to stop,
    //   2. ask the event loop to quit,
    //   3. WAIT. Destroying a running QThread terminates the process.
    if (m_worker)
        m_worker->requestCancel();
    m_thread.quit();
    m_thread.wait();
}

QString ScannerController::bytesLabel() const
{
    return QLocale().formattedDataSize(m_bytesScanned);
}

void ScannerController::start(const QString &pathOrUrl)
{
    if (m_running)
        return;

    // QML's FolderDialog gives URLs; a text field gives a plain path. Accept
    // both so the UI does not have to care.
    QString path = pathOrUrl;
    if (path.startsWith(QLatin1String("file:")))
        path = QUrl(path).toLocalFile();
    path = QDir::cleanPath(path.trimmed());

    if (path.isEmpty()) {
        setStatusText(QStringLiteral("Choose a folder first."));
        return;
    }

    if (m_rootPath != path) {
        m_rootPath = path;
        emit rootPathChanged();
    }

    m_results.clearStats();
    m_filesScanned = 0;
    m_bytesScanned = 0;
    m_currentPath.clear();
    emit progressChanged();

    setRunning(true);
    setStatusText(QStringLiteral("Scanning %1 ...").arg(path));

    // This does not call scan() -- it posts an event to the worker thread. The
    // function returns immediately and the GUI keeps repainting.
    emit scanRequested(path);
}

void ScannerController::startFromUrl(const QUrl &folderUrl)
{
    start(folderUrl.isLocalFile() ? folderUrl.toLocalFile() : folderUrl.toString());
}

void ScannerController::cancel()
{
    if (!m_running || !m_worker)
        return;

    // Direct call on purpose: requestCancel() only writes an atomic flag, and
    // the worker is stuck inside a loop so a queued call would not arrive until
    // the loop was already over.
    m_worker->requestCancel();
    setStatusText(QStringLiteral("Cancelling ..."));
}

QString ScannerController::defaultScanPath() const
{
    const QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    return home.isEmpty() ? QDir::currentPath() : home;
}

void ScannerController::setRunning(bool running)
{
    if (m_running == running)
        return;
    m_running = running;
    emit runningChanged();
}

void ScannerController::setStatusText(const QString &text)
{
    if (m_statusText == text)
        return;
    m_statusText = text;
    emit statusTextChanged();
}

void ScannerController::onProgress(int files, qint64 bytes, const QString &currentPath)
{
    m_filesScanned = files;
    m_bytesScanned = bytes;
    m_currentPath = currentPath;
    emit progressChanged();
}

void ScannerController::onFinished(const devboard::ScanSummary &summary)
{
    m_filesScanned = summary.fileCount;
    m_bytesScanned = summary.totalBytes;
    m_currentPath.clear();
    emit progressChanged();

    m_results.setStats(summary.extensions, summary.totalBytes);
    setRunning(false);

    if (summary.canceled) {
        setStatusText(QStringLiteral("Cancelled after %1 file(s).").arg(summary.fileCount));
        return;
    }
    setStatusText(QStringLiteral("%1 files in %2 folders, %3, %4 extension(s).")
                          .arg(summary.fileCount)
                          .arg(summary.directoryCount)
                          .arg(QLocale().formattedDataSize(summary.totalBytes))
                          .arg(summary.extensions.size()));
}

void ScannerController::onFailed(const QString &reason)
{
    setRunning(false);
    setStatusText(reason);
}

} // namespace devboard

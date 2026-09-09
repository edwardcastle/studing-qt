#pragma once

// ---------------------------------------------------------------------------
// ScannerController.h -- owns the worker thread and exposes it to QML.
//
// TEACHING NOTE
// This is the "controller" layer: it contains no scanning logic and no UI. Its
// only job is to translate between two worlds:
//
//   QML calls a Q_INVOKABLE          ->  a signal is emitted to the worker
//   the worker emits a signal        ->  a Q_PROPERTY changes, QML re-binds
//
// Thread ownership rules used here (memorise these three):
//
//   1. The controller lives on the GUI thread; the worker lives on m_thread.
//   2. All communication is signal/slot, so Qt does the thread hopping for us
//      (Qt::AutoConnection becomes Qt::QueuedConnection across threads).
//   3. The worker is deleted by its own thread (`&QThread::finished` ->
//      `deleteLater`), never with `delete` from the GUI thread.
// ---------------------------------------------------------------------------

#include "models/ScanResultModel.h"
#include "scanner/ScanTypes.h"

#include <QObject>
#include <QString>
#include <QThread>
#include <QUrl>

#include <QtQmlIntegration/qqmlintegration.h>

namespace devboard {

class ScanWorker;

class ScannerController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(QString rootPath READ rootPath NOTIFY rootPathChanged)
    Q_PROPERTY(int filesScanned READ filesScanned NOTIFY progressChanged)
    Q_PROPERTY(qlonglong bytesScanned READ bytesScanned NOTIFY progressChanged)
    Q_PROPERTY(QString bytesLabel READ bytesLabel NOTIFY progressChanged)
    Q_PROPERTY(QString currentPath READ currentPath NOTIFY progressChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)

    // Exposing a child QObject as a property is how QML gets hold of a model
    // that C++ owns. CONSTANT says "this pointer never changes", which lets QML
    // bind to it without a notify signal.
    Q_PROPERTY(devboard::ScanResultModel *results READ results CONSTANT)

public:
    explicit ScannerController(QObject *parent = nullptr);
    ~ScannerController() override;

    bool running() const { return m_running; }
    QString rootPath() const { return m_rootPath; }
    int filesScanned() const { return m_filesScanned; }
    qlonglong bytesScanned() const { return m_bytesScanned; }
    QString bytesLabel() const;
    QString currentPath() const { return m_currentPath; }
    QString statusText() const { return m_statusText; }
    ScanResultModel *results() { return &m_results; }

    /// Accepts either a plain path or a "file:///..." URL (what QML's
    /// FolderDialog hands you).
    Q_INVOKABLE void start(const QString &pathOrUrl);
    Q_INVOKABLE void startFromUrl(const QUrl &folderUrl);
    Q_INVOKABLE void cancel();

    /// A sensible starting point so the user does not have to hunt for a folder.
    Q_INVOKABLE QString defaultScanPath() const;

signals:
    /// Private signal used to hop into the worker thread. QML never sees it.
    void scanRequested(const QString &rootPath);

    void runningChanged();
    void rootPathChanged();
    void progressChanged();
    void statusTextChanged();

private:
    void setRunning(bool running);
    void setStatusText(const QString &text);
    void onProgress(int files, qint64 bytes, const QString &currentPath);
    void onFinished(const devboard::ScanSummary &summary);
    void onFailed(const QString &reason);

    QThread m_thread;
    ScanWorker *m_worker = nullptr;   ///< owned by m_thread, not by `this`
    ScanResultModel m_results;

    bool m_running = false;
    QString m_rootPath;
    int m_filesScanned = 0;
    qint64 m_bytesScanned = 0;
    QString m_currentPath;
    QString m_statusText;
};

} // namespace devboard

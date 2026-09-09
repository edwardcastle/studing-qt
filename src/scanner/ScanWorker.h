#pragma once

// ---------------------------------------------------------------------------
// ScanWorker.h -- the "slow job" that must not block the user interface.
//
// TEACHING NOTE (this is the part everybody gets wrong at first)
// A QObject does not have a thread of its own. It has an *affinity*: the thread
// whose event loop delivers its queued slot calls. The pattern used here is the
// recommended one, usually called "worker object":
//
//     QThread thread;                  // just an event loop in another thread
//     ScanWorker *worker = new ScanWorker;
//     worker->moveToThread(&thread);   // now its slots run over there
//     thread.start();
//
// You then talk to the worker *only through signals and slots*. Calling
// worker->scan(...) directly from the GUI thread would run the loop on the GUI
// thread and freeze the window -- which is exactly what we are trying to avoid.
//
// The one exception is cancellation: we cannot send a queued signal to a
// worker that is busy inside a loop, because it is not processing events. So
// the cancel flag is a std::atomic_bool, which is safe to write from one thread
// while another reads it.
// ---------------------------------------------------------------------------

#include "ScanTypes.h"

#include <QObject>

#include <atomic>

namespace devboard {

class ScanWorker : public QObject
{
    Q_OBJECT

public:
    explicit ScanWorker(QObject *parent = nullptr);

    /// Safe to call from any thread: it only touches an atomic flag.
    void requestCancel();

public slots:
    /// Walks `rootPath` recursively. Runs on the worker thread; blocking here
    /// is fine, that is the whole point.
    void scan(const QString &rootPath);

signals:
    /// Emitted at most every ~80 ms so we do not flood the GUI event loop with
    /// thousands of updates per second (a classic cause of "my threaded app is
    /// slower than the single threaded one").
    void progress(int filesScanned, qint64 bytesScanned, const QString &currentPath);

    void finished(const devboard::ScanSummary &summary);
    void failed(const QString &reason);

private:
    std::atomic_bool m_cancelRequested { false };
};

} // namespace devboard

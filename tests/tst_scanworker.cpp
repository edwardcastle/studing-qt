// ---------------------------------------------------------------------------
// tst_scanworker.cpp -- testing code that runs on another thread.
//
// TEACHING NOTE
// Threaded code is testable, but only if you keep the discipline of talking to
// the worker through signals. The recipe used below:
//
//   1. build a known directory tree in a QTemporaryDir;
//   2. move the worker onto a QThread and start it;
//   3. QSignalSpy on the signal you expect;
//   4. spy.wait(timeout) spins a local event loop until the signal arrives;
//   5. shut the thread down and assert.
//
// Never use QThread::sleep() to "wait for the worker". It makes tests slow when
// they pass and flaky when they fail.
// ---------------------------------------------------------------------------

#include "scanner/ScanWorker.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>
#include <QThread>

using namespace devboard;

class Tst_ScanWorker : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void scanCountsFilesAndBytes();
    void scanGroupsByExtension();
    void scanReportsAnInvalidPath();
    void scanRunsOnTheWorkerThread();

private:
    /// Writes `contents` to <dir>/<relativePath>, creating folders as needed.
    static void writeFile(const QString &root, const QString &relativePath, const QByteArray &contents)
    {
        const QString full = root + QLatin1Char('/') + relativePath;
        QDir().mkpath(QFileInfo(full).absolutePath());
        QFile file(full);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(contents);
    }

    QTemporaryDir m_dir;
};

void Tst_ScanWorker::initTestCase()
{
    qRegisterMetaType<devboard::ScanSummary>("devboard::ScanSummary");
    QVERIFY(m_dir.isValid());

    // A tiny, completely predictable tree:
    //   a.txt        (5 bytes)
    //   b.txt        (10 bytes)
    //   sub/c.cpp    (20 bytes)
    //   sub/deep/d   (3 bytes, no extension)
    writeFile(m_dir.path(), QStringLiteral("a.txt"), QByteArray(5, 'a'));
    writeFile(m_dir.path(), QStringLiteral("b.txt"), QByteArray(10, 'b'));
    writeFile(m_dir.path(), QStringLiteral("sub/c.cpp"), QByteArray(20, 'c'));
    writeFile(m_dir.path(), QStringLiteral("sub/deep/d"), QByteArray(3, 'd'));
}

void Tst_ScanWorker::scanCountsFilesAndBytes()
{
    ScanWorker worker;
    QSignalSpy finishedSpy(&worker, &ScanWorker::finished);

    // Called directly: on this thread, which is exactly what we want in a test.
    worker.scan(m_dir.path());

    QCOMPARE(finishedSpy.count(), 1);
    const auto summary = finishedSpy.first().at(0).value<ScanSummary>();

    QCOMPARE(summary.fileCount, 4);
    QCOMPARE(summary.totalBytes, qint64(5 + 10 + 20 + 3));
    QCOMPARE(summary.directoryCount, 2);   // sub, sub/deep
    QVERIFY(!summary.canceled);
}

void Tst_ScanWorker::scanGroupsByExtension()
{
    ScanWorker worker;
    QSignalSpy finishedSpy(&worker, &ScanWorker::finished);
    worker.scan(m_dir.path());

    const auto summary = finishedSpy.first().at(0).value<ScanSummary>();
    QCOMPARE(summary.extensions.size(), 3);   // txt, cpp, "" (no extension)

    // The list is sorted by size, biggest first.
    QCOMPARE(summary.extensions.at(0).extension, QStringLiteral("cpp"));
    QCOMPARE(summary.extensions.at(0).totalBytes, qint64(20));
    QCOMPARE(summary.extensions.at(1).extension, QStringLiteral("txt"));
    QCOMPARE(summary.extensions.at(1).fileCount, 2);
    QCOMPARE(summary.extensions.at(1).totalBytes, qint64(15));
    QCOMPARE(summary.extensions.at(2).extension, QString());   // the file "d"
}

void Tst_ScanWorker::scanReportsAnInvalidPath()
{
    ScanWorker worker;
    QSignalSpy failedSpy(&worker, &ScanWorker::failed);
    QSignalSpy finishedSpy(&worker, &ScanWorker::finished);

    worker.scan(m_dir.filePath(QStringLiteral("does-not-exist")));

    QCOMPARE(failedSpy.count(), 1);
    QCOMPARE(finishedSpy.count(), 0);   // failed() and finished() are exclusive
}

void Tst_ScanWorker::scanRunsOnTheWorkerThread()
{
    QThread thread;
    thread.setObjectName(QStringLiteral("test-scan-worker"));

    // No parent: an object with a parent cannot be moved to another thread.
    auto *worker = new ScanWorker;
    worker->moveToThread(&thread);
    connect(&thread, &QThread::finished, worker, &QObject::deleteLater);
    thread.start();

    QSignalSpy finishedSpy(worker, &ScanWorker::finished);

    // QMetaObject::invokeMethod with QueuedConnection is the "call a slot on
    // another thread" primitive that signal/slot connections are built on.
    QMetaObject::invokeMethod(worker, "scan", Qt::QueuedConnection,
                              Q_ARG(QString, m_dir.path()));

    // wait() runs a local event loop, so the queued `finished` signal can be
    // delivered to this thread. Without it the spy would stay empty forever.
    QVERIFY(finishedSpy.wait(5000));

    const auto summary = finishedSpy.first().at(0).value<ScanSummary>();
    QCOMPARE(summary.fileCount, 4);

    thread.quit();
    QVERIFY(thread.wait(5000));
}

QTEST_GUILESS_MAIN(Tst_ScanWorker)
#include "tst_scanworker.moc"

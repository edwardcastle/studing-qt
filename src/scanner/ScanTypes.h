#pragma once

// ---------------------------------------------------------------------------
// ScanTypes.h -- the values that travel between the worker thread and the GUI
// thread.
//
// TEACHING NOTE
// When a signal crosses a thread boundary Qt does not call the slot directly.
// It *copies* the arguments into an event, posts it to the receiving thread's
// event loop, and unpacks it there. That is why every type used in a
// cross-thread signal must be:
//
//   1. copyable, and
//   2. known to QMetaType (that is what Q_DECLARE_METATYPE does).
//
// This is also why you should never send a raw pointer to something the worker
// still owns: the receiver might read it while the worker is already writing.
// Send values.
// ---------------------------------------------------------------------------

#include <QList>
#include <QMetaType>
#include <QString>

namespace devboard {

/// Aggregated numbers for one file extension, e.g. ".cpp -> 12 files, 40 kB".
struct ExtensionStat
{
    QString extension;      ///< lower case, without the dot; "" for no extension
    int fileCount = 0;
    qint64 totalBytes = 0;
};

/// Everything the worker produces when a scan finishes.
struct ScanSummary
{
    QString rootPath;
    int fileCount = 0;
    int directoryCount = 0;
    qint64 totalBytes = 0;
    QList<ExtensionStat> extensions;   ///< sorted, biggest first
    bool canceled = false;
};

} // namespace devboard

// Both macros must appear at global scope, outside any namespace.
Q_DECLARE_METATYPE(devboard::ExtensionStat)
Q_DECLARE_METATYPE(devboard::ScanSummary)

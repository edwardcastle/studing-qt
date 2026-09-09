# 4 — Keeping the user interface responsive

## 4.1 The problem, stated precisely

There is exactly one thread that may touch the GUI: the one that created
`QGuiApplication`. Everything that happens on screen — layout, painting,
delivering a click — happens between two iterations of that thread's event
loop. So any function of yours that takes 300 ms freezes the window for 300 ms.

A recursive directory walk over a real folder takes seconds. That is the whole
reason for `src/scanner/` and `src/app/ScannerController.*`.

## 4.2 Which tool for which job

| Situation | Use |
|---|---|
| Work that must be interruptible and reports progress | **worker object + `QThread`** ← this project |
| "Run this function, give me the result later" | `QtConcurrent::run()` + `QFutureWatcher` |
| Map/filter/reduce over a container, in parallel | `QtConcurrent::mapped()` etc. |
| Many short tasks | `QThreadPool` + `QRunnable` |
| Network requests | `QNetworkAccessManager` — already asynchronous, **do not** put it on a thread |
| File I/O of a few kB | just do it on the GUI thread |

Note the last two rows. A lot of threading code exists to solve problems that
were never synchronous in the first place. Reach for a thread when you have a
**CPU- or I/O-bound loop you wrote yourself**.

## 4.3 The worker-object pattern

The code is in `ScannerController`'s constructor. It is five lines, and each
one matters.

```cpp
ScannerController::ScannerController(QObject *parent)
    : QObject(parent)
    , m_worker(new ScanWorker)          // 1. NO parent
{
    m_worker->moveToThread(&m_thread);  // 2. change its thread affinity

    connect(&m_thread, &QThread::finished, m_worker, &QObject::deleteLater);  // 3.

    connect(this, &ScannerController::scanRequested, m_worker, &ScanWorker::scan);   // 4.
    connect(m_worker, &ScanWorker::progress,  this, &ScannerController::onProgress);
    connect(m_worker, &ScanWorker::finished,  this, &ScannerController::onFinished);
    connect(m_worker, &ScanWorker::failed,    this, &ScannerController::onFailed);

    m_thread.start();                   // 5. the thread runs its own event loop
}
```

1. **No parent.** `moveToThread()` refuses to move an object that has one. (A
   parent and its children must always share a thread.)
2. **Affinity, not execution.** After `moveToThread()`, queued slot calls to the
   worker are executed by `m_thread`. The object did not "start running" — it is
   just registered with a different event loop.
3. **The thread deletes the worker.** Never `delete m_worker` from the GUI
   thread; it might be in the middle of `scan()`.
4. **Talk only through signals.** `emit scanRequested(path)` does *not* call
   `scan()`. It posts an event to `m_thread`'s queue and returns immediately.

> Do not subclass `QThread` and put your work in `run()`. It is the older
> pattern, it is still in a lot of tutorials, and it makes it very easy to
> accidentally call worker methods from the wrong thread — the `QThread` object
> itself lives on the *creating* thread, only `run()` executes on the new one.

### Prove it to yourself

Open `ScannerController::start()` and replace

```cpp
emit scanRequested(path);
```

with

```cpp
m_worker->scan(path);       // direct call → runs HERE, on the GUI thread
```

Rebuild, scan a big folder, and try to move the window. Then put it back. That
five-second experiment teaches more than this whole page.

## 4.4 What crosses the boundary, and how

`Qt::AutoConnection` (the default) decides at **emit time**:

* sender and receiver on the same thread → **direct** call, like a function call;
* different threads → **queued**: arguments are *copied* into a
  `QMetaCallEvent`, posted to the receiver's event loop, unpacked and executed
  there.

Consequences you must design around:

* **Everything you send is copied.** Send values, not pointers into data the
  worker still owns. That is why `ScanSummary` is a struct of plain values.
* **The type must be known to `QMetaType`.** Hence, in `ScanTypes.h`:

  ```cpp
  Q_DECLARE_METATYPE(devboard::ScanSummary)
  ```

  and, in `main.cpp`:

  ```cpp
  qRegisterMetaType<devboard::ScanSummary>("devboard::ScanSummary");
  ```

  Miss this and you get the runtime warning
  `QObject::connect: Cannot queue arguments of type 'ScanSummary'` — and the
  slot is simply never called. No crash, no compile error. Remember this
  message; you will meet it.
* **The receiver must be running an event loop.** If the GUI thread is blocked
  inside your own long function, queued signals from workers pile up unprocessed.

## 4.5 Progress reporting: throttle it

`ScanWorker::scan()` emits at most one `progress()` every 80 ms:

```cpp
if (sinceLastReport.elapsed() >= 80) {
    emit progress(summary.fileCount, summary.totalBytes, info.absoluteFilePath());
    sinceLastReport.restart();
}
```

Emitting per file would post hundreds of thousands of events to the GUI thread.
Each one allocates, each one wakes the loop, each one re-evaluates bindings —
and the "threaded" version ends up *slower* than the single-threaded one while
the UI stutters. 60 Hz is 16 ms; anything faster than that is invisible.

The same reasoning applies to results: `ScanResultModel` is filled once, in
`onFinished()`, not row by row from the worker.

## 4.6 Cancellation

You cannot cancel with a queued signal. The worker is inside a `while` loop, so
it is not processing events, so the signal would only arrive after the loop
finished. Hence a flag:

```cpp
// ScanWorker.h
std::atomic_bool m_cancelRequested { false };

// called from the GUI thread — this is the exception to "signals only"
void ScanWorker::requestCancel() { m_cancelRequested.store(true, std::memory_order_relaxed); }

// checked inside the loop, on the worker thread
if (m_cancelRequested.load(std::memory_order_relaxed)) { summary.canceled = true; break; }
```

`std::atomic_bool`, not `bool`. A plain `bool` written by one thread and read by
another is a data race: undefined behaviour, and in optimised builds the
compiler is entitled to hoist the read out of the loop so your flag is never
seen again. `std::memory_order_relaxed` is enough here because the flag carries
no other data with it.

Note also that cancellation is **cooperative**: the worker stops at the next
iteration and still emits `finished()` with `canceled = true`, so the UI has one
code path for "the scan ended". There is no way to kill a thread safely, and
`QThread::terminate()` leaves your program in an undefined state — never use it.

## 4.7 Shutting down

```cpp
ScannerController::~ScannerController()
{
    if (m_worker)
        m_worker->requestCancel();   // 1. ask the loop to stop
    m_thread.quit();                 // 2. ask the event loop to return
    m_thread.wait();                 // 3. BLOCK until it really has
}
```

Destroying a running `QThread` prints
`QThread: Destroyed while thread is still running` and usually aborts the
process. `wait()` is not optional. Ordering matters too: `quit()` only ends the
*event loop*, so a worker stuck in a long loop must be told to stop first.

## 4.8 Rules to memorise

1. Never touch a GUI object (window, item, widget) from a worker thread.
2. Communicate by signals and values; a raw pointer to shared data is a bug
   waiting for a deadline.
3. Objects with a parent cannot change threads.
4. Every thread that receives queued signals needs a running event loop.
5. Always `quit()` **and** `wait()` before destroying a `QThread`.
6. Throttle progress signals.
7. Cancellation is a flag the worker checks, not something you can force.
8. If it can be done asynchronously without a thread (network, file watching,
   timers), do that instead.

## 4.9 Debugging threaded code

* `m_thread.setObjectName("scan-worker")` — the name shows up in gdb, in Qt
  Creator's thread list and in `top -H`. Do it for every thread.
* `qDebug() << QThread::currentThread()` inside a slot answers "which thread am
  I on?" immediately.
* Build with `-fsanitize=thread` (Clang or GCC) to catch real data races:
  ```bash
  cmake -S . -B build-tsan -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_CXX_FLAGS="-fsanitize=thread -g"
  ```
* `tests/tst_scanworker.cpp` shows how to test this: `QSignalSpy::wait()` runs a
  local event loop so a queued signal can actually be delivered. Never
  `QThread::sleep()` in a test.

Next: [05-build-system.md](05-build-system.md).

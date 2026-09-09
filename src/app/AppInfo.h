#pragma once

// ---------------------------------------------------------------------------
// AppInfo.h -- a QML *singleton* written in C++.
//
// TEACHING NOTE
// There are three common ways to get C++ into QML. This project uses all three
// so you can compare them:
//
//   1. QML_ELEMENT            -> QML creates the object: `TaskListModel { }`
//                                (TaskListModel, TaskFilterModel, Scanner...)
//   2. QML_ELEMENT + QML_SINGLETON
//                             -> one shared instance created on first use,
//                                reachable everywhere as `AppInfo.something`
//                                (this file)
//   3. engine.rootContext()->setContextProperty("name", obj)
//                             -> the old Qt 5 way. It still works but it hides
//                                the type from tooling, so prefer 1 and 2.
//
// Anything registered this way must live in a target that was built with
// qt_add_qml_module() -- see CMakeLists.txt.
// ---------------------------------------------------------------------------

#include <QObject>
#include <QString>
#include <QUrl>

#include <QtQmlIntegration/qqmlintegration.h>

namespace devboard {

class AppInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString appName READ appName CONSTANT)
    Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT)
    Q_PROPERTY(QString buildType READ buildType CONSTANT)

public:
    explicit AppInfo(QObject *parent = nullptr);

    QString appName() const;
    QString qtVersion() const;
    QString buildType() const;

    /// "1.2 MB" instead of "1258291". Exposed so QML never formats sizes itself.
    Q_INVOKABLE QString formatBytes(qlonglong bytes) const;

    /// FolderDialog hands out URLs; the C++ side wants paths.
    Q_INVOKABLE QString urlToLocalFile(const QUrl &url) const;

    /// Opens the folder that holds tasks.json in the system file manager.
    Q_INVOKABLE void revealPath(const QString &filePath) const;
};

} // namespace devboard

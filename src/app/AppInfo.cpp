#include "AppInfo.h"

#include <QCoreApplication>
#include <QDesktopServices>
#include <QFileInfo>
#include <QLocale>

namespace devboard {

AppInfo::AppInfo(QObject *parent)
    : QObject(parent)
{
}

QString AppInfo::appName() const
{
    return QCoreApplication::applicationName();
}

QString AppInfo::qtVersion() const
{
    // QT_VERSION_STR is the version we compiled against; qVersion() is the one
    // actually loaded at runtime. They can differ, and when they do it usually
    // explains a very confusing bug.
    return QStringLiteral("%1 (built against %2)")
            .arg(QString::fromLatin1(qVersion()), QStringLiteral(QT_VERSION_STR));
}

QString AppInfo::buildType() const
{
#ifdef QT_DEBUG
    return QStringLiteral("Debug");
#else
    return QStringLiteral("Release");
#endif
}

QString AppInfo::formatBytes(qlonglong bytes) const
{
    return QLocale().formattedDataSize(bytes);
}

QString AppInfo::urlToLocalFile(const QUrl &url) const
{
    return url.isLocalFile() ? url.toLocalFile() : url.toString();
}

void AppInfo::revealPath(const QString &filePath) const
{
    const QFileInfo info(filePath);
    const QString folder = info.isDir() ? info.absoluteFilePath() : info.absolutePath();
    QDesktopServices::openUrl(QUrl::fromLocalFile(folder));
}

} // namespace devboard

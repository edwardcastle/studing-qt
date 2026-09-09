// ---------------------------------------------------------------------------
// main.cpp -- start up the application object, register metatypes, load QML.
//
// TEACHING NOTE
// A Qt program is an event loop. main() builds the objects, calls exec(), and
// from that moment on everything happens in reaction to events: a mouse click,
// a timer firing, a queued signal arriving from a worker thread. exec() only
// returns when the last window closes (or quit() is called), and the return
// value of main() is the exit code of the whole process.
//
// Which application class to use:
//   QCoreApplication  -- no GUI at all (services, CLI tools)
//   QGuiApplication   -- Qt Quick / QML  <-- this project
//   QApplication      -- Qt Widgets (adds QWidget-specific machinery)
// ---------------------------------------------------------------------------

#include "scanner/ScanTypes.h"

#include <QGuiApplication>
#include <QIcon>
#include <QMetaType>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // These three names decide where QStandardPaths puts your data, so set them
    // before anything asks for a storage location.
    QCoreApplication::setOrganizationName(QStringLiteral("StudingQt"));
    QCoreApplication::setApplicationName(QStringLiteral("DevBoard"));
    QCoreApplication::setApplicationVersion(QStringLiteral("1.0"));

    // Custom types that travel over *queued* (cross-thread) connections have to
    // be known to the meta type system. Forgetting this gives you the classic
    // runtime warning:
    //   "QObject::connect: Cannot queue arguments of type 'ScanSummary'"
    qRegisterMetaType<devboard::ScanSummary>("devboard::ScanSummary");
    qRegisterMetaType<devboard::ExtensionStat>("devboard::ExtensionStat");

    // "Basic" is the style every platform has. Try "Fusion", "Material" or
    // "Universal" -- or set QT_QUICK_CONTROLS_STYLE=Material before launching.
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
        QQuickStyle::setStyle(QStringLiteral("Basic"));

    QQmlApplicationEngine engine;

    // If a QML file has an error the engine reports it and creates nothing. Do
    // not let that turn into a silent, window-less process: fail loudly.
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);

    // "DevBoard" is the URI declared by qt_add_qml_module() in CMakeLists.txt.
    // qt_add_qml_module compiles every QML file into the binary as a resource
    // under :/qt/qml/<URI>/, so this URL works on any machine without shipping
    // loose .qml files. Types written in C++ with QML_ELEMENT live under the
    // same URI, which is why Main.qml only needs `import DevBoard`.
    //
    // Qt 6.5 and newer offer a nicer spelling of the same thing:
    //     engine.loadFromModule("DevBoard", "Main");
    // This project targets 6.4 as well, so it uses the explicit URL.
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/DevBoard/Main.qml")));

    return app.exec();
}

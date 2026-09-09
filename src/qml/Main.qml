// ---------------------------------------------------------------------------
// Main.qml -- the window, the tabs, and the place where the C++ objects are
// created.
//
// TEACHING NOTE: how QML and C++ meet
// The three objects below (TaskListModel, TaskFilterModel, ScannerController)
// are C++ classes. They appear here as ordinary QML types because each one is
// marked QML_ELEMENT and lives in a target built with qt_add_qml_module().
//
// Once created, QML owns them: when this window is destroyed, they are deleted.
// Everything QML can see on them is what the C++ side published:
//   * Q_PROPERTY  -> readable, bindable, sometimes assignable
//   * Q_INVOKABLE -> callable like a normal function
//   * signals     -> handled as onSomethingChanged: { ... }
// Nothing else is visible. That is the whole API surface, and it is a good
// discipline: if QML needs it, publish it deliberately.
// ---------------------------------------------------------------------------

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import DevBoard

ApplicationWindow {
    id: window

    width: 1040
    height: 680
    minimumWidth: 780
    minimumHeight: 520
    visible: true
    title: qsTr("DevBoard — a Qt Quick + C++ example")
    color: Theme.background

    // ---------------------------------------------------------------- models
    // Declaring them here means "one per window". A binding like
    // `taskModel.openCount` below re-evaluates by itself whenever the C++ side
    // emits countsChanged() -- no manual refresh anywhere in this file.
    TaskListModel {
        id: taskModel

        Component.onCompleted: {
            load();
            if (count === 0)
                addSampleTasks();
        }
    }

    TaskFilterModel {
        id: filterModel
        sourceModel: taskModel        // <- the proxy wraps the real model
    }

    ScannerController {
        id: scanner
    }

    // ---------------------------------------------------------------- header
    header: Rectangle {
        color: Theme.surface
        implicitHeight: headerColumn.implicitHeight + Theme.spacing * 2

        Rectangle {                    // 1px separator line
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        ColumnLayout {
            id: headerColumn
            anchors.fill: parent
            anchors.margins: Theme.spacing
            spacing: Theme.spacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing

                Label {
                    text: qsTr("DevBoard")
                    color: Theme.text
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                }
                Label {
                    text: qsTr("C++ backend · Qt Quick front end")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: qsTr("Qt %1").arg(AppInfo.qtVersion)
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }
            }

            TabBar {
                id: tabBar
                Layout.fillWidth: true
                background: null

                TabButton {
                    text: qsTr("Tasks (%1)").arg(taskModel.openCount)
                    width: implicitWidth
                }
                TabButton {
                    text: scanner.running ? qsTr("Scanner · running…") : qsTr("Scanner")
                    width: implicitWidth
                }
                TabButton {
                    text: qsTr("How it works")
                    width: implicitWidth
                }
            }
        }
    }

    // ------------------------------------------------------------- the pages
    // StackLayout shows exactly one child at a time, chosen by currentIndex.
    // Binding it to tabBar.currentIndex is all the "navigation" this app needs.
    StackLayout {
        anchors.fill: parent
        currentIndex: tabBar.currentIndex

        TasksPage {
            taskModel: taskModel
            filterModel: filterModel
        }

        ScannerPage {
            controller: scanner
        }

        AboutPage {
            taskModel: taskModel
        }
    }

    // ---------------------------------------------------------------- footer
    footer: Rectangle {
        color: Theme.surface
        implicitHeight: 30

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Theme.border
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing
            anchors.rightMargin: Theme.spacing

            Label {
                // Two different C++ objects feeding one label.
                text: tabBar.currentIndex === 1 ? scanner.statusText
                                                : taskModel.statusMessage
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                text: qsTr("%1 open · %2 done · %3 overdue")
                        .arg(taskModel.openCount)
                        .arg(taskModel.doneCount)
                        .arg(taskModel.overdueCount)
                color: taskModel.overdueCount > 0 ? Theme.warning : Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}

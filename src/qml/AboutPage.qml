// ---------------------------------------------------------------------------
// AboutPage.qml -- an in-app cheat sheet, so the explanation travels with the
// program.
//
// TEACHING NOTE
// This page is also a small demo of `Repeater`: it builds one Section per entry
// of a JavaScript array. Repeater is the right tool for a handful of static
// items; use ListView (with a real model) as soon as the count can grow or the
// content has to scroll efficiently.
// ---------------------------------------------------------------------------

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import DevBoard

Item {
    id: root

    required property TaskListModel taskModel

    readonly property var sections: [
        {
            heading: qsTr("1. Where the data lives"),
            body: qsTr("devboard::TaskStore (src/core) holds a std::vector<Task> and all the rules: "
                     + "validation, ids, counting, JSON. It uses no GUI class at all, which is why "
                     + "tests/tst_taskstore.cpp can test it without opening a window.")
        },
        {
            heading: qsTr("2. How the list reaches the screen"),
            body: qsTr("TaskListModel (src/models) implements rowCount(), data() and roleNames(). "
                     + "The names it returns — title, done, priority, dueDateLabel … — are exactly "
                     + "the properties the delegate in TaskDelegate.qml declares as `required`.")
        },
        {
            heading: qsTr("3. Filtering and sorting"),
            body: qsTr("TaskFilterModel is a QSortFilterProxyModel. The ListView is attached to the "
                     + "proxy, so hiding or reordering rows never touches the stored data. Because "
                     + "of that, the page converts proxy rows back to source rows before calling "
                     + "any command.")
        },
        {
            heading: qsTr("4. Calling C++ from QML"),
            body: qsTr("Q_PROPERTY gives you bindable values (openCount, running, statusText). "
                     + "Q_INVOKABLE gives you callable commands (addTask, removeTask, start, cancel). "
                     + "Together they are the whole contract between the two languages.")
        },
        {
            heading: qsTr("5. Keeping the UI responsive"),
            body: qsTr("The Scanner tab runs a QDirIterator loop inside a ScanWorker that was moved "
                     + "to its own QThread. Progress arrives through queued signals; cancellation "
                     + "goes the other way through a std::atomic_bool.")
        },
        {
            heading: qsTr("6. Saving"),
            body: qsTr("Every change restarts a 400 ms single-shot QTimer; when it fires, the store "
                     + "writes tasks.json through QSaveFile, so a crash mid-write cannot corrupt "
                     + "the previous file.")
        }
    ]

    ScrollView {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        contentWidth: availableWidth      // vertical scrolling only

        ColumnLayout {
            width: root.width - Theme.spacing * 2
            spacing: Theme.spacing

            Label {
                text: qsTr("How this example is put together")
                color: Theme.text
                font.pixelSize: Theme.fontTitle
                font.bold: true
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.textMuted
                font.pixelSize: Theme.fontNormal
                text: qsTr("The full write-up is in the docs/ folder of the repository. "
                         + "This page is the short version.")
            }

            Repeater {
                model: root.sections

                delegate: Rectangle {
                    id: sectionCard
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: sectionColumn.implicitHeight + Theme.spacing * 2
                    color: Theme.surface
                    radius: Theme.radius
                    border.color: Theme.border

                    ColumnLayout {
                        id: sectionColumn
                        anchors.fill: parent
                        anchors.margins: Theme.spacing
                        spacing: Theme.spacingSmall

                        Label {
                            text: sectionCard.modelData.heading
                            color: Theme.accent
                            font.pixelSize: Theme.fontNormal
                            font.bold: true
                        }
                        Label {
                            Layout.fillWidth: true
                            text: sectionCard.modelData.body
                            color: Theme.text
                            font.pixelSize: Theme.fontNormal
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: infoColumn.implicitHeight + Theme.spacing * 2
                color: Theme.surface
                radius: Theme.radius
                border.color: Theme.border

                ColumnLayout {
                    id: infoColumn
                    anchors.fill: parent
                    anchors.margins: Theme.spacing
                    spacing: Theme.spacingSmall

                    Label {
                        text: qsTr("Runtime")
                        color: Theme.accent
                        font.pixelSize: Theme.fontNormal
                        font.bold: true
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAnywhere
                        color: Theme.text
                        font.pixelSize: Theme.fontSmall
                        text: qsTr("Qt: %1\nBuild: %2\nTasks file: %3")
                                .arg(AppInfo.qtVersion)
                                .arg(AppInfo.buildType)
                                .arg(root.taskModel.storagePath)
                    }
                    Button {
                        text: qsTr("Open the folder holding tasks.json")
                        onClicked: AppInfo.revealPath(root.taskModel.storagePath)
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// TasksPage.qml -- the list, the toolbar above it, and the editor dialog.
//
// TEACHING NOTE
// Notice what this file does *not* contain: no array of tasks, no sorting code,
// no file handling. It only describes what things look like and forwards user
// actions to the C++ model. When you catch yourself keeping a copy of the data
// in QML, that is the moment to move the logic down into C++.
// ---------------------------------------------------------------------------

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import DevBoard

Item {
    id: root

    // `required property` (Qt 6) makes these mandatory: forget to pass one and
    // you get a clear error at creation time instead of a silent undefined.
    required property TaskListModel taskModel
    required property TaskFilterModel filterModel

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacing

        // ------------------------------------------------------------ toolbar
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: qsTr("Search title or notes…")
                color: Theme.text
                placeholderTextColor: Theme.textMuted
                background: Rectangle {
                    color: Theme.surface
                    border.color: searchField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radius
                }

                // A two-way link done the explicit way: typing updates the C++
                // property, and the C++ property is the single source of truth.
                onTextChanged: root.filterModel.searchText = text
            }

            ComboBox {
                id: sortBox
                Layout.preferredWidth: 170
                model: [qsTr("Newest first"), qsTr("By due date"), qsTr("By priority"), qsTr("By title")]
                // The order of this list matches TaskFilterModel::SortMode.
                onCurrentIndexChanged: root.filterModel.sortMode = currentIndex
            }

            CheckBox {
                id: showDoneBox
                text: qsTr("Show done")
                checked: true
                contentItem: Label {
                    text: showDoneBox.text
                    color: Theme.text
                    font.pixelSize: Theme.fontNormal
                    leftPadding: showDoneBox.indicator.width + 4
                    verticalAlignment: Text.AlignVCenter
                }
                onCheckedChanged: root.filterModel.showCompleted = checked
            }

            Button {
                text: qsTr("New task")
                onClicked: editor.openForNew()
            }

            Button {
                text: qsTr("Clear done")
                enabled: root.taskModel.doneCount > 0
                onClicked: root.taskModel.clearCompleted()
            }
        }

        // --------------------------------------------------------------- list
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.border

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 1
                clip: true                 // stop delegates painting outside
                spacing: 1
                model: root.filterModel    // the PROXY, not the source model

                // ScrollBar.vertical is an attached property: it belongs to the
                // ListView but is declared by the Controls module.
                ScrollBar.vertical: ScrollBar { }

                delegate: TaskDelegate {
                    // ListView.view is an attached property pointing at the
                    // view that created this delegate. Prefer it over reaching
                    // for an outer id: delegates live in their own scope, and
                    // the linter reports such unqualified access as a warning.
                    width: ListView.view.width

                    onToggleRequested: function (proxyRow) {
                        // Rows the user sees are proxy rows; the commands work on
                        // source rows. Always convert, never assume they match.
                        root.taskModel.toggleDone(root.filterModel.sourceRow(proxyRow));
                    }
                    onEditRequested: function (proxyRow) {
                        editor.openForRow(root.filterModel.sourceRow(proxyRow));
                    }
                    onRemoveRequested: function (proxyRow) {
                        root.taskModel.removeTask(root.filterModel.sourceRow(proxyRow));
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: listView.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.textMuted
                    text: root.taskModel.count === 0
                          ? qsTr("No tasks yet.\nPress “New task” to add one.")
                          : qsTr("Nothing matches the current filter.")
                }
            }
        }

        // -------------------------------------------------------- count label
        Label {
            text: qsTr("Showing %1 of %2 task(s)").arg(root.filterModel.count).arg(root.taskModel.count)
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
        }
    }

    TaskEditorDialog {
        id: editor
        anchors.centerIn: Overlay.overlay
        taskModel: root.taskModel
    }
}

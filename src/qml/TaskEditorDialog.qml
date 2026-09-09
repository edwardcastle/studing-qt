// ---------------------------------------------------------------------------
// TaskEditorDialog.qml -- one dialog used for both "new" and "edit".
//
// TEACHING NOTE
// The dialog keeps its own draft values in plain QML properties while it is
// open, and only pushes them into the C++ model when the user presses Save.
// That is the right kind of local state: it is temporary, it belongs to the
// widget, and throwing it away on Cancel is the desired behaviour.
//
// Contrast with the list itself, which never keeps a copy of anything.
// ---------------------------------------------------------------------------

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import DevBoard

Dialog {
    id: dialog

    required property TaskListModel taskModel

    /// -1 means "creating a new task", otherwise it is a source row.
    property int editedRow: -1

    title: editedRow < 0 ? qsTr("New task") : qsTr("Edit task")
    modal: true
    width: 440
    standardButtons: Dialog.Save | Dialog.Cancel
    closePolicy: Popup.CloseOnEscape

    function openForNew() {
        editedRow = -1;
        titleField.text = "";
        notesField.text = "";
        priorityBox.currentIndex = Priority.Normal;
        dueBox.checked = false;
        dueField.text = Qt.formatDate(new Date(), "yyyy-MM-dd");
        open();
    }

    function openForRow(row) {
        if (row < 0)
            return;
        // get() is a Q_INVOKABLE returning a QVariantMap, which arrives in QML
        // as an ordinary JavaScript object.
        const task = taskModel.get(row);
        editedRow = row;
        titleField.text = task.title;
        notesField.text = task.notes;
        priorityBox.currentIndex = task.priority;
        // dueDateLabel is empty exactly when the C++ side has no due date,
        // which is easier to test than poking at the QDateTime itself.
        dueBox.checked = task.dueDateLabel !== "";
        dueField.text = dueBox.checked ? Qt.formatDate(task.dueDate, "yyyy-MM-dd")
                                       : Qt.formatDate(new Date(), "yyyy-MM-dd");
        open();
    }

    onAccepted: {
        const dueDate = dueBox.checked ? Date.fromLocaleDateString(Qt.locale(), dueField.text, "yyyy-MM-dd")
                                       : undefined;
        if (editedRow < 0)
            taskModel.addTask(titleField.text, notesField.text, priorityBox.currentIndex, dueDate);
        else
            taskModel.updateTask(editedRow, titleField.text, notesField.text,
                                 priorityBox.currentIndex, dueDate);
    }

    // Disable Save until there is a title -- the C++ store would reject it
    // anyway, but the UI should not let the user get that far.
    onOpened: titleField.forceActiveFocus()

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        Label { text: qsTr("Title"); color: Theme.textMuted; font.pixelSize: Theme.fontSmall }
        TextField {
            id: titleField
            Layout.fillWidth: true
            placeholderText: qsTr("What has to be done?")
            onTextChanged: {
                const saveButton = dialog.standardButton(Dialog.Save);
                if (saveButton)
                    saveButton.enabled = text.trim().length > 0;
            }
        }

        Label { text: qsTr("Notes"); color: Theme.textMuted; font.pixelSize: Theme.fontSmall }
        TextArea {
            id: notesField
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            wrapMode: TextArea.Wrap
            placeholderText: qsTr("Optional details…")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing

            ColumnLayout {
                spacing: 2
                Label { text: qsTr("Priority"); color: Theme.textMuted; font.pixelSize: Theme.fontSmall }
                ComboBox {
                    id: priorityBox
                    // The index of each entry matches devboard::Priority::Level.
                    model: [qsTr("Low"), qsTr("Normal"), qsTr("High")]
                    Layout.preferredWidth: 140
                }
            }

            ColumnLayout {
                spacing: 2
                CheckBox {
                    id: dueBox
                    text: qsTr("Due date")
                }
                TextField {
                    id: dueField
                    enabled: dueBox.checked
                    Layout.preferredWidth: 160
                    placeholderText: "yyyy-MM-dd"
                    inputMask: "9999-99-99"
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}

// ---------------------------------------------------------------------------
// TaskDelegate.qml -- how ONE row is drawn.
//
// TEACHING NOTE
// A delegate is instantiated by the view, once per visible row, and recycled as
// you scroll. Two consequences:
//   * keep it cheap -- no heavy JavaScript, no timers per row;
//   * never store state in it, because the instance you are looking at will be
//     reused for a completely different row a second later.
//
// The `required property` lines below are the modern way to receive data from
// the model: each one matches a name returned by TaskListModel::roleNames().
// Declaring them explicitly (instead of relying on the old implicit `model.`
// context) is faster, and a typo becomes an error instead of `undefined`.
// ---------------------------------------------------------------------------

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import DevBoard

Rectangle {
    id: delegateRoot

    // --- data coming from the model (names from roleNames()) ----------------
    required property int index          // the row number inside the view
    required property string title
    required property string notes
    required property int priority
    required property string priorityLabel
    required property bool done
    required property string dueDateLabel
    required property bool overdue

    // --- what this delegate reports back to the page ------------------------
    signal toggleRequested(int row)
    signal editRequested(int row)
    signal removeRequested(int row)

    implicitHeight: Math.max(Theme.rowHeight, layout.implicitHeight + Theme.spacing * 2)
    color: hoverHandler.hovered ? Theme.surfaceHover : "transparent"

    HoverHandler { id: hoverHandler }

    // A coloured bar on the left is a cheap, readable way to show priority.
    Rectangle {
        width: 3
        height: parent.height
        color: delegateRoot.done ? Theme.border : Theme.priorityColor(delegateRoot.priority)
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing
        anchors.rightMargin: Theme.spacing
        anchors.topMargin: Theme.spacingSmall
        anchors.bottomMargin: Theme.spacingSmall
        spacing: Theme.spacing

        CheckBox {
            checked: delegateRoot.done
            // Do NOT write `checked = ...` here. The model owns the value; we
            // ask it to change and the new value comes back through the role.
            onToggled: delegateRoot.toggleRequested(delegateRoot.index)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
                Layout.fillWidth: true
                text: delegateRoot.title
                color: delegateRoot.done ? Theme.textMuted : Theme.text
                font.pixelSize: Theme.fontNormal
                font.strikeout: delegateRoot.done
                elide: Text.ElideRight
            }

            Label {
                Layout.fillWidth: true
                visible: delegateRoot.notes.length > 0
                text: delegateRoot.notes
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Small pill showing the priority.
        Rectangle {
            visible: !delegateRoot.done
            implicitWidth: priorityLabelText.implicitWidth + Theme.spacing
            implicitHeight: priorityLabelText.implicitHeight + 4
            radius: height / 2
            color: Theme.accentSoft
            border.color: Theme.priorityColor(delegateRoot.priority)

            Label {
                id: priorityLabelText
                anchors.centerIn: parent
                text: delegateRoot.priorityLabel
                color: Theme.priorityColor(delegateRoot.priority)
                font.pixelSize: Theme.fontSmall
            }
        }

        Label {
            visible: delegateRoot.dueDateLabel.length > 0
            text: delegateRoot.dueDateLabel
            color: delegateRoot.overdue ? Theme.danger : Theme.textMuted
            font.pixelSize: Theme.fontSmall
            font.bold: delegateRoot.overdue
        }

        // Row actions only appear on hover: less visual noise, same reach.
        Button {
            text: qsTr("Edit")
            flat: true
            visible: hoverHandler.hovered
            onClicked: delegateRoot.editRequested(delegateRoot.index)
        }

        Button {
            text: qsTr("Delete")
            flat: true
            visible: hoverHandler.hovered
            onClicked: delegateRoot.removeRequested(delegateRoot.index)
        }
    }

    // Separator between rows.
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.border
    }
}

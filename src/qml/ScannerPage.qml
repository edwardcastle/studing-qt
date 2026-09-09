// ---------------------------------------------------------------------------
// ScannerPage.qml -- the UI of the background job.
//
// TEACHING NOTE -- what to look at while it runs
// Start a scan on a big folder and then resize the window, scroll, switch tabs.
// Everything stays smooth, because the directory walk happens on another
// thread. If you want to *feel* the difference, open src/app/ScannerController.cpp
// and replace
//         emit scanRequested(path);
// with
//         m_worker->scan(path);
// That calls the same function directly on the GUI thread. Rebuild, scan the
// same folder, and try to move the window.
// ---------------------------------------------------------------------------

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import DevBoard

Item {
    id: root

    required property ScannerController controller

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacing

        // ------------------------------------------------------------ toolbar
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            TextField {
                id: pathField
                Layout.fillWidth: true
                text: root.controller.rootPath
                color: Theme.text
                placeholderText: qsTr("Folder to scan")
                background: Rectangle {
                    color: Theme.surface
                    border.color: pathField.activeFocus ? Theme.accent : Theme.border
                    radius: Theme.radius
                }
            }

            Button {
                text: qsTr("Browse…")
                enabled: !root.controller.running
                onClicked: folderDialog.open()
            }

            Button {
                text: qsTr("Scan")
                enabled: !root.controller.running
                onClicked: root.controller.start(pathField.text)
            }

            Button {
                text: qsTr("Cancel")
                // `running` is a Q_PROPERTY with a NOTIFY signal, so this button
                // enables and disables itself. No code anywhere calls
                // "cancelButton.enabled = ...".
                enabled: root.controller.running
                onClicked: root.controller.cancel()
            }
        }

        // ----------------------------------------------------------- progress
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: progressColumn.implicitHeight + Theme.spacing * 2
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.border

            ColumnLayout {
                id: progressColumn
                anchors.fill: parent
                anchors.margins: Theme.spacing
                spacing: Theme.spacingSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingLarge

                    StatTile {
                        caption: qsTr("Files")
                        value: root.controller.filesScanned.toLocaleString(Qt.locale())
                    }
                    StatTile {
                        caption: qsTr("Size")
                        value: root.controller.bytesLabel
                    }
                    StatTile {
                        caption: qsTr("Extensions")
                        value: root.controller.results.count.toString()
                    }
                    Item { Layout.fillWidth: true }
                    BusyIndicator {
                        running: root.controller.running
                        visible: running
                        implicitWidth: 28
                        implicitHeight: 28
                    }
                }

                // A directory walk has no known total, so an indeterminate bar
                // is the honest choice: it says "working", not "42% done".
                ProgressBar {
                    Layout.fillWidth: true
                    indeterminate: root.controller.running
                    value: root.controller.running ? 0 : 1
                    visible: root.controller.running
                }

                Label {
                    Layout.fillWidth: true
                    visible: root.controller.currentPath.length > 0
                    text: root.controller.currentPath
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideMiddle
                }
            }
        }

        // ------------------------------------------------------------ results
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.border

            ListView {
                id: resultsView
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                // `results` is a Q_PROPERTY returning a ScanResultModel* owned
                // by C++. QML can use it as a model but never deletes it.
                model: root.controller.results

                ScrollBar.vertical: ScrollBar { }

                delegate: Item {
                    id: resultDelegate

                    required property string extension
                    required property int fileCount
                    required property string sizeLabel
                    required property real sharePercent

                    width: ListView.view.width
                    height: 44

                    // The share bar is drawn behind the text: a one-line chart.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height - 8
                        width: Math.max(2, parent.width * resultDelegate.sharePercent / 100)
                        color: Theme.accentSoft
                        radius: 4
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing
                        anchors.rightMargin: Theme.spacing

                        Label {
                            text: resultDelegate.extension
                            color: Theme.text
                            font.pixelSize: Theme.fontNormal
                            font.family: "monospace"
                            Layout.preferredWidth: 160
                            elide: Text.ElideRight
                        }
                        Label {
                            text: qsTr("%1 file(s)").arg(resultDelegate.fileCount)
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            Layout.fillWidth: true
                        }
                        Label {
                            text: resultDelegate.sharePercent.toFixed(1) + " %"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            Layout.preferredWidth: 60
                            horizontalAlignment: Text.AlignRight
                        }
                        Label {
                            text: resultDelegate.sizeLabel
                            color: Theme.text
                            font.pixelSize: Theme.fontNormal
                            Layout.preferredWidth: 90
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: resultsView.count === 0 && !root.controller.running
                    text: qsTr("No results yet — choose a folder and press Scan.")
                    color: Theme.textMuted
                }
            }
        }
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Choose a folder to scan")
        onAccepted: root.controller.startFromUrl(selectedFolder)
    }
}

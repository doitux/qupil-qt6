// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

Page {
    id: root
    property int selectedId: -1
    property string archiveHtml: ""

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        ListView {
            id: list
            Layout.preferredWidth: root.width > 760 ? 280 : root.width
            Layout.fillHeight: true
            visible: root.width > 760 || root.selectedId < 0
            model: App.archive
            spacing: 4
            clip: true
            delegate: ItemDelegate {
                required property var model
                required property string name
                width: list.width
                text: name
                onClicked: { root.selectedId = model.id; root.archiveHtml = App.pupilArchiveHtml(model.id) }
            }
            Label { anchors.centerIn: parent; visible: list.count === 0; text: qsTr("Archive is empty"); opacity: 0.65 }
        }

        Rectangle { visible: root.width > 760; Layout.preferredWidth: 1; Layout.fillHeight: true; color: root.palette.mid }

        ColumnLayout {
            visible: root.width > 760 || root.selectedId >= 0
            Layout.fillWidth: true; Layout.fillHeight: true
            RowLayout {
                Layout.fillWidth: true
                Button { visible: root.width <= 760; text: "‹ " + qsTr("Archive"); onClicked: root.selectedId = -1 }
                Label { text: qsTr("Archived pupil"); font.bold: true; font.pixelSize: 20; Layout.fillWidth: true }
                Button { visible: root.selectedId >= 0; text: qsTr("Delete entry"); onClicked: deleteDialog.open() }
            }
            ScrollView {
                id: archiveScroll
                Layout.fillWidth: true; Layout.fillHeight: true
                contentWidth: availableWidth
                Label {
                    x: 12
                    width: Math.max(0, archiveScroll.availableWidth - 24)
                    text: root.archiveHtml
                    textFormat: Text.RichText
                    wrapMode: Text.Wrap
                    color: root.palette.text
                }
            }
            DocumentActions {
                visible: root.selectedId >= 0
                documentTitle: qsTr("Pupil archive")
                suggestedFileName: ""
                landscape: false
                createDocument: function() { return root.archiveHtml }
            }
        }
    }

    Dialog {
        id: deleteDialog
        anchors.centerIn: parent
        title: qsTr("Delete archive entry?")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: if (App.deleteArchiveEntry(root.selectedId)) { root.selectedId = -1; root.archiveHtml = "" }
    }
}

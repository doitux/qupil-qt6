// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    width: 1100
    height: 760

    property var archiveModel: null
    property int selectedId: -1
    property string archiveHtml: ""
    property color paletteMid: "#808080"
    property color paletteText: "#202020"
    property var selectAction: null
    property var backAction: null
    property var openDeleteAction: null

    property alias deleteDialog: deleteDialog
    property alias documentActionsHost: documentActionsHost

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        ListView {
            id: archiveList
            Layout.preferredWidth: root.width > 760 ? 280 : root.width
            Layout.fillHeight: true
            visible: root.width > 760 || root.selectedId < 0
            model: root.archiveModel
            spacing: 4
            clip: true
            delegate: ItemDelegate {
                required property var model
                required property string name
                property int recordId: model.id
                width: archiveList.width
                text: name
                action: root.selectAction
            }
            Label { anchors.centerIn: parent; visible: archiveList.count === 0; text: qsTr("Archive is empty"); opacity: 0.65 }
        }

        Rectangle { visible: root.width > 760; Layout.preferredWidth: 1; Layout.fillHeight: true; color: root.paletteMid }

        ColumnLayout {
            visible: root.width > 760 || root.selectedId >= 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            RowLayout {
                Layout.fillWidth: true
                Button { visible: root.width <= 760; text: "‹ " + qsTr("Archive"); action: root.backAction }
                Label { text: qsTr("Archived pupil"); font.bold: true; font.pixelSize: 20; Layout.fillWidth: true }
                Button { visible: root.selectedId >= 0; text: qsTr("Delete entry"); action: root.openDeleteAction }
            }
            ScrollView {
                id: archiveScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                Label {
                    x: 12
                    width: Math.max(0, archiveScroll.availableWidth - 24)
                    text: root.archiveHtml
                    textFormat: Text.RichText
                    wrapMode: Text.Wrap
                    color: root.paletteText
                }
            }
            Item {
                id: documentActionsHost
                visible: root.selectedId >= 0
                Layout.fillWidth: true
                Layout.preferredHeight: 44
            }
        }
    }

    Dialog {
        id: deleteDialog
        anchors.centerIn: parent
        title: qsTr("Delete archive entry?")
        standardButtons: Dialog.Ok | Dialog.Cancel
    }
}

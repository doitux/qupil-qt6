// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    width: 1100
    height: 760

    property int editId: -1
    property var remindersModel: null
    property var pupilsModel: null
    property var addAction: null
    property var editAction: null
    property var deleteAction: null

    property alias editor: editor
    property alias reminderText: reminderText
    property alias mode: mode
    property alias pupil: pupil
    property alias sound: sound

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Label { text: qsTr("Reminders"); font.pixelSize: 22; font.bold: true; Layout.fillWidth: true }
            Button { text: qsTr("Add"); action: root.addAction }
        }
        ListView {
            id: remindersList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.remindersModel
            spacing: 6
            clip: true
            delegate: ItemDelegate {
                required property var model
                required property string description
                required property string modeName
                required property string pupilName
                required property int sound
                property int recordId: model.id
                width: remindersList.width
                action: root.editAction
                contentItem: RowLayout {
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: description; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label { text: modeName + (pupilName ? " · " + pupilName : "") + (sound ? " · 🔔" : ""); opacity: 0.65 }
                    }
                    ToolButton {
                        property int recordId: model.id
                        text: "×"
                        action: root.deleteAction
                    }
                }
            }
        }
    }

    Dialog {
        id: editor
        anchors.centerIn: parent
        width: Math.min(520, root.width - 32)
        modal: true
        title: root.editId < 0 ? qsTr("New reminder") : qsTr("Edit reminder")
        standardButtons: Dialog.Save | Dialog.Cancel
        ColumnLayout {
            width: parent.width
            LabeledField { id: reminderText; label: qsTr("Reminder text") }
            Label { text: qsTr("Mode"); font.bold: true }
            ComboBox { id: mode; Layout.fillWidth: true; model: [qsTr("At application start"), qsTr("Every lesson"), qsTr("Specific pupil")] }
            Label { visible: mode.currentIndex === 2; text: qsTr("Pupil"); font.bold: true }
            ComboBox { id: pupil; visible: mode.currentIndex === 2; Layout.fillWidth: true; model: root.pupilsModel; textRole: "name"; valueRole: "id" }
            CheckBox { id: sound; text: qsTr("Play notification sound") }
        }
    }
}

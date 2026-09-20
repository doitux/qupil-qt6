// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

Page {
    id: root
    property int editId: -1

    function openEditor(id) {
        editId = id
        if (id < 0) {
            reminderText.text = ""
            mode.currentIndex = 0
            pupil.currentIndex = App.pupils.count > 0 ? 0 : -1
            sound.checked = false
        } else {
            const r = App.reminder(id)
            reminderText.text = r.description || ""
            mode.currentIndex = r.mode || 0
            const idx = pupil.indexOfValue(r.pupilId)
            pupil.currentIndex = idx >= 0 ? idx : 0
            sound.checked = !!r.sound
        }
        editor.open()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Label { text: qsTr("Reminders"); font.pixelSize: 22; font.bold: true; Layout.fillWidth: true }
            Button { text: qsTr("Add"); onClicked: root.openEditor(-1) }
        }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            model: App.reminders
            spacing: 6; clip: true
            delegate: ItemDelegate {
                required property var model
                required property string description
                required property string modeName
                required property string pupilName
                required property int sound
                width: list.width
                onClicked: root.openEditor(model.id)
                contentItem: RowLayout {
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: description; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label { text: modeName + (pupilName ? " · " + pupilName : "") + (sound ? " · 🔔" : ""); opacity: 0.65 }
                    }
                    ToolButton { text: "×"; onClicked: App.deleteReminder(model.id) }
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
        onAccepted: App.saveReminder({ id: root.editId, description: reminderText.text, mode: mode.currentIndex, pupilId: pupil.currentValue === undefined ? -1 : pupil.currentValue, sound: sound.checked })
        ColumnLayout {
            width: parent.width
            LabeledField { id: reminderText; label: qsTr("Reminder text") }
            Label { text: qsTr("Mode"); font.bold: true }
            ComboBox { id: mode; Layout.fillWidth: true; model: [qsTr("At application start"), qsTr("Every lesson"), qsTr("Specific pupil")] }
            Label { visible: mode.currentIndex === 2; text: qsTr("Pupil"); font.bold: true }
            ComboBox { id: pupil; visible: mode.currentIndex === 2; Layout.fillWidth: true; model: App.pupils; textRole: "name"; valueRole: "id" }
            CheckBox { id: sound; text: qsTr("Play notification sound") }
        }
    }
}

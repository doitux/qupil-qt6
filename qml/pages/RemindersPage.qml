// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Page {
    id: root
    property int editId: -1

    function openEditor(id) {
        editId = id
        if (id < 0) {
            form.reminderText.text = ""
            form.mode.currentIndex = 0
            form.pupil.currentIndex = App.pupils.count > 0 ? 0 : -1
            form.sound.checked = false
        } else {
            const r = App.reminder(id)
            form.reminderText.text = r.description || ""
            form.mode.currentIndex = r.mode || 0
            const idx = form.pupil.indexOfValue(r.pupilId)
            form.pupil.currentIndex = idx >= 0 ? idx : 0
            form.sound.checked = !!r.sound
        }
        form.editor.open()
    }

    Action { id: addAction; onTriggered: root.openEditor(-1) }
    Action { id: editAction; onTriggered: source => root.openEditor(source.recordId) }
    Action { id: deleteAction; onTriggered: source => App.deleteReminder(source.recordId) }

    RemindersPageForm {
        id: form
        anchors.fill: parent
        editId: root.editId
        remindersModel: App.reminders
        pupilsModel: App.pupils
        addAction: addAction
        editAction: editAction
        deleteAction: deleteAction

        editor.onAccepted: App.saveReminder({
            id: root.editId,
            description: reminderText.text,
            mode: mode.currentIndex,
            pupilId: pupil.currentValue === undefined ? -1 : pupil.currentValue,
            sound: sound.checked
        })
    }
}

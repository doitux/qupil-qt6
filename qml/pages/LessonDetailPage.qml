// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Page {
    id: root
    property int lessonId: -1
    property var assigned: []
    property var available: []
    signal done()

    function reloadMembers() {
        if (lessonId < 0) {
            assigned = []
            available = []
            return
        }
        assigned = App.lessonPupils(lessonId)
        available = App.availablePupilsForLesson(lessonId)
    }

    function load() {
        if (lessonId < 0) {
            form.typeBox.currentIndex = 0
            form.autoName.checked = true
            form.lessonName.text = ""
            form.irregular.checked = false
            form.dayBox.currentIndex = Math.max(0, new Date().getDay() - 1)
            form.startTime.text = "14:00"
            form.stopTime.text = "14:45"
            form.locationField.text = ""
            return
        }
        const l = App.lesson(lessonId)
        form.typeBox.currentIndex = Math.max(0, (l.type || 1) - 1)
        form.autoName.checked = !!l.autoName
        form.lessonName.text = l.name || ""
        form.irregular.checked = !!l.irregular
        form.dayBox.currentIndex = Math.max(0, l.day || 0)
        form.startTime.text = l.start || ""
        form.stopTime.text = l.stop || ""
        form.locationField.text = l.location || ""
        reloadMembers()
    }

    function save() {
        const id = App.saveLesson({
            id: lessonId,
            type: form.typeBox.currentIndex + 1,
            autoName: form.autoName.checked,
            name: form.lessonName.text,
            irregular: form.irregular.checked,
            day: form.dayBox.currentIndex,
            start: form.startTime.text,
            stop: form.stopTime.text,
            location: form.locationField.text
        })
        if (id >= 0) {
            lessonId = id
            load()
            saved.open()
        }
    }

    Action { id: backAction; onTriggered: root.done() }
    Action { id: saveAction; onTriggered: root.save() }
    Action {
        id: removePupilAction
        onTriggered: source => {
            if (App.removePupilFromLesson(root.lessonId, source.recordId))
                root.reloadMembers()
        }
    }
    Action {
        id: addPupilAction
        onTriggered: {
            if (App.addPupilToLesson(root.lessonId, form.availablePupil.currentValue))
                root.reloadMembers()
        }
    }
    Action { id: openDeleteAction; onTriggered: form.deleteDialog.open() }

    LessonDetailPageForm {
        id: form
        anchors.fill: parent
        lessonId: root.lessonId
        assigned: root.assigned
        available: root.available
        paletteMid: root.palette.mid
        backAction: backAction
        saveAction: saveAction
        removePupilAction: removePupilAction
        addPupilAction: addPupilAction
        openDeleteAction: openDeleteAction

        deleteDialog.onAccepted: {
            if (App.deleteLesson(root.lessonId))
                root.done()
        }
    }

    Popup { id: saved; anchors.centerIn: parent; Label { text: qsTr("Saved") } }
    Component.onCompleted: load()
    Connections { target: Language; function onEffectiveLanguageChanged() { if (root.lessonId >= 0) root.load() } }
}

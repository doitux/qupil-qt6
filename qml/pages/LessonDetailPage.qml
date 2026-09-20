// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

Page {
    id: root
    property int lessonId: -1
    property var assigned: []
    property var available: []
    signal done()

    function reloadMembers() {
        if (lessonId < 0) { assigned = []; available = []; return }
        assigned = App.lessonPupils(lessonId)
        available = App.availablePupilsForLesson(lessonId)
    }

    function load() {
        if (lessonId < 0) {
            typeBox.currentIndex = 0
            autoName.checked = true
            lessonName.text = ""
            irregular.checked = false
            dayBox.currentIndex = Math.max(0, new Date().getDay() - 1)
            startTime.text = "14:00"
            stopTime.text = "14:45"
            location.text = ""
            return
        }
        const l = App.lesson(lessonId)
        typeBox.currentIndex = Math.max(0, (l.type || 1) - 1)
        autoName.checked = !!l.autoName
        lessonName.text = l.name || ""
        irregular.checked = !!l.irregular
        dayBox.currentIndex = Math.max(0, l.day || 0)
        startTime.text = l.start || ""
        stopTime.text = l.stop || ""
        location.text = l.location || ""
        reloadMembers()
    }

    function save() {
        const id = App.saveLesson({
            id: lessonId,
            type: typeBox.currentIndex + 1,
            autoName: autoName.checked,
            name: lessonName.text,
            irregular: irregular.checked,
            day: dayBox.currentIndex,
            start: startTime.text,
            stop: stopTime.text,
            location: location.text
        })
        if (id >= 0) {
            lessonId = id
            load()
            saved.open()
        }
    }

    Component.onCompleted: load()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            Button { text: "‹ " + qsTr("Back"); onClicked: root.done() }
            Label { text: lessonId < 0 ? qsTr("New lesson") : lessonName.text; font.bold: true; font.pixelSize: 20; Layout.fillWidth: true; elide: Text.ElideRight }
            Button { text: qsTr("Save"); onClicked: root.save() }
        }

        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth

            ColumnLayout {
                width: scroll.availableWidth
                spacing: 12

                SectionCard {
                    title: qsTr("Lesson details")
                    Layout.fillWidth: true; Layout.margins: 12
                    GridLayout {
                        columns: root.width > 720 ? 2 : 1
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: qsTr("Type"); font.bold: true; opacity: 0.8 }
                            ComboBox { id: typeBox; Layout.fillWidth: true; model: [qsTr("Individual lesson"), qsTr("Group lesson"), qsTr("Ensemble lesson")] }
                        }
                        LabeledField { id: location; label: qsTr("Location") }
                        CheckBox { id: autoName; text: qsTr("Create name automatically") }
                        LabeledField { id: lessonName; label: qsTr("Lesson name"); readOnly: autoName.checked }
                        CheckBox { id: irregular; text: qsTr("Irregular lesson") }
                        ColumnLayout {
                            enabled: !irregular.checked
                            Layout.fillWidth: true
                            Label { text: qsTr("Weekday"); font.bold: true; opacity: 0.8 }
                            ComboBox { id: dayBox; Layout.fillWidth: true; model: [qsTr("Monday"),qsTr("Tuesday"),qsTr("Wednesday"),qsTr("Thursday"),qsTr("Friday"),qsTr("Saturday"),qsTr("Sunday")] }
                        }
                        LabeledField { id: startTime; label: qsTr("Start (HH:mm)"); readOnly: irregular.checked }
                        LabeledField { id: stopTime; label: qsTr("End (HH:mm)"); readOnly: irregular.checked }
                    }
                }

                SectionCard {
                    title: qsTr("Pupils")
                    visible: lessonId >= 0
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12

                    Label { visible: root.assigned.length === 0; text: qsTr("No pupils assigned yet."); opacity: 0.65 }
                    Repeater {
                        model: root.assigned
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Label { text: modelData.name; Layout.fillWidth: true }
                            Button {
                                text: qsTr("Remove")
                                onClicked: if (App.removePupilFromLesson(root.lessonId, modelData.id)) root.reloadMembers()
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.palette.mid }
                    RowLayout {
                        Layout.fillWidth: true
                        ComboBox {
                            id: availablePupil
                            Layout.fillWidth: true
                            model: root.available
                            textRole: "name"
                            valueRole: "id"
                        }
                        Button {
                            text: qsTr("Add")
                            enabled: root.available.length > 0
                            onClicked: if (App.addPupilToLesson(root.lessonId, availablePupil.currentValue)) root.reloadMembers()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 12
                    Button { text: qsTr("Save"); onClicked: root.save() }
                    Item { Layout.fillWidth: true }
                    Button { visible: lessonId >= 0; text: qsTr("Delete lesson"); onClicked: deleteDialog.open() }
                }
                Item { Layout.preferredHeight: 12 }
            }
        }
    }

    Dialog {
        id: deleteDialog
        anchors.centerIn: parent
        modal: true
        title: qsTr("Delete lesson?")
        standardButtons: Dialog.Ok | Dialog.Cancel
        Label { width: Math.min(420, root.width - 64); wrapMode: Text.WordWrap; text: qsTr("Historical pupil assignments are preserved where appropriate.") }
        onAccepted: if (App.deleteLesson(root.lessonId)) root.done()
    }

    Popup { id: saved; anchors.centerIn: parent; Label { text: qsTr("Saved") } }
}

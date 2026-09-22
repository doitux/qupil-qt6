// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    width: 1100
    height: 760

    property int lessonId: -1
    property var assigned: []
    property var available: []
    property color paletteMid: "#808080"

    property var backAction: null
    property var saveAction: null
    property var removePupilAction: null
    property var addPupilAction: null
    property var openDeleteAction: null

    property alias typeBox: typeBox
    property alias autoName: autoName
    property alias lessonName: lessonName
    property alias irregular: irregular
    property alias dayBox: dayBox
    property alias startTime: startTime
    property alias stopTime: stopTime
    property alias locationField: locationField
    property alias availablePupil: availablePupil
    property alias deleteDialog: deleteDialog

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            Button { text: "‹ " + qsTr("Back"); action: root.backAction }
            Label {
                text: root.lessonId < 0 ? qsTr("New lesson") : lessonName.text
                font.bold: true
                font.pixelSize: 20
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Button { text: qsTr("Save"); action: root.saveAction }
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
                    Layout.fillWidth: true
                    Layout.margins: 12
                    GridLayout {
                        columns: root.width > 720 ? 2 : 1
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: qsTr("Type"); font.bold: true; opacity: 0.8 }
                            ComboBox { id: typeBox; Layout.fillWidth: true; model: [qsTr("Individual lesson"), qsTr("Group lesson"), qsTr("Ensemble lesson")] }
                        }
                        LabeledField { id: locationField; label: qsTr("Location") }
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
                    visible: root.lessonId >= 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12

                    Label { visible: root.assigned.length === 0; text: qsTr("No pupils assigned yet."); opacity: 0.65 }
                    Repeater {
                        model: root.assigned
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Label { text: modelData.name; Layout.fillWidth: true }
                            Button {
                                property int recordId: modelData.id
                                text: qsTr("Remove")
                                action: root.removePupilAction
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.paletteMid }
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
                            action: root.addPupilAction
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 12
                    Button { text: qsTr("Save"); action: root.saveAction }
                    Item { Layout.fillWidth: true }
                    Button { visible: root.lessonId >= 0; text: qsTr("Delete lesson"); action: root.openDeleteAction }
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
    }
}

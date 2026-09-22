// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    width: 1100
    height: 760

    property var birthdayRows: []
    property var recitalRows: []
    property var ensembleRows: []
    property var instrumentData: ({ pupils: [], instruments: [], sizes: [], rentalCount: 0, nextSizeCount: 0 })

    property var editPupilAction: null
    property var addReminderAction: null
    property var rentalDocumentAction: null

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 12

            SectionCard {
                title: qsTr("Birthdays")
                Layout.fillWidth: true
                Layout.margins: 12

                Repeater {
                    model: root.birthdayRows
                    delegate: ItemDelegate {
                        required property var modelData
                        property int recordId: modelData.id
                        visible: index < 16
                        Layout.fillWidth: true
                        action: root.editPupilAction
                        contentItem: RowLayout {
                            Label { text: modelData.name; font.bold: modelData.today; Layout.fillWidth: true }
                            Label {
                                text: modelData.today ? qsTr("today") + " · " + modelData.age + " " + qsTr("years")
                                      : modelData.recent ? (-modelData.days) + " " + qsTr("days ago") + " · " + modelData.age + " " + qsTr("years")
                                      : qsTr("in") + " " + modelData.days + " " + qsTr("days") + " · " + modelData.age + " " + qsTr("years")
                                opacity: 0.7
                            }
                        }
                    }
                }
                Label { visible: root.birthdayRows.length === 0; text: qsTr("No valid birthdays stored"); opacity: 0.6 }
            }

            SectionCard {
                title: qsTr("Overdue concert activity")
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12

                Repeater {
                    model: root.recitalRows
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Button {
                            property int recordId: modelData.id
                            text: modelData.name
                            flat: true
                            Layout.fillWidth: true
                            action: root.editPupilAction
                        }
                        Label { text: modelData.daysSince + " " + qsTr("days since") + " " + modelData.referenceDate; opacity: 0.65 }
                        ToolButton {
                            property int pupilId: modelData.id
                            property string reminderText: qsTr("Speak about concert activity!")
                            text: "+!"
                            Accessible.name: qsTr("Add reminder")
                            action: root.addReminderAction
                        }
                    }
                }
                Label { visible: root.recitalRows.length === 0; text: qsTr("No overdue concert candidates"); opacity: 0.6 }
            }

            SectionCard {
                title: qsTr("Ensemble activity")
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12

                Repeater {
                    model: root.ensembleRows
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Button {
                            property int recordId: modelData.id
                            text: modelData.name
                            flat: true
                            Layout.fillWidth: true
                            action: root.editPupilAction
                        }
                        Label { text: modelData.lastDescription || qsTr("no previous ensemble"); opacity: 0.65 }
                        ToolButton {
                            property int pupilId: modelData.id
                            property string reminderText: qsTr("Speak about ensemble activity!")
                            text: "+!"
                            Accessible.name: qsTr("Add reminder")
                            action: root.addReminderAction
                        }
                    }
                }
                Label { visible: root.ensembleRows.length === 0; text: qsTr("All requested pupils have an active ensemble activity"); opacity: 0.6 }
            }

            SectionCard {
                title: qsTr("Instrument overview")
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.bottomMargin: 12
                Button { text: qsTr("Rental Instruments Inventory List ..."); action: root.rentalDocumentAction }

                RowLayout {
                    Label { text: qsTr("Rental instruments:") + " " + root.instrumentData.rentalCount; font.bold: true }
                    Label { text: qsTr("Next size needed:") + " " + root.instrumentData.nextSizeCount; font.bold: true }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 12
                    Repeater {
                        model: root.instrumentData.instruments || []
                        delegate: Label { required property var modelData; text: modelData.name + ": " + modelData.count }
                    }
                }

                Repeater {
                    model: root.instrumentData.pupils || []
                    delegate: ItemDelegate {
                        required property var modelData
                        property int recordId: modelData.id
                        Layout.fillWidth: true
                        action: root.editPupilAction
                        contentItem: RowLayout {
                            Label { text: modelData.name; Layout.fillWidth: true }
                            Label { text: (modelData.instrument || "") + ((modelData.instrument || "") && (modelData.size || "") ? " · " : "") + (modelData.size || ""); opacity: 0.7 }
                            Label { visible: modelData.rental; text: qsTr("rental"); font.bold: true }
                            Label { visible: modelData.needsNextSize; text: qsTr("next size"); font.bold: true }
                        }
                    }
                }
            }
        }
    }
}

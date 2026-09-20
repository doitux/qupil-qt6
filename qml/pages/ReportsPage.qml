// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

Page {
    id: root
    signal editPupil(int recordId)

    property var birthdayRows: []
    property var recitalRows: []
    property var ensembleRows: []
    property var instrumentData: ({ pupils: [], instruments: [], sizes: [], rentalCount: 0, nextSizeCount: 0 })

    function reload() {
        birthdayRows = App.birthdays()
        recitalRows = App.overdueRecitalPupils()
        ensembleRows = App.pupilsWithoutEnsemble()
        instrumentData = App.instrumentOverview()
    }

    function reminder(pupilId, text) {
        App.saveReminder({ id: -1, description: text, mode: 2, pupilId: pupilId, sound: true })
        reminderSaved.open()
    }

    Component.onCompleted: reload()

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
                    model: root.birthdayRows.slice(0, 16)
                    delegate: ItemDelegate {
                        required property var modelData
                        Layout.fillWidth: true
                        onClicked: root.editPupil(modelData.id)
                        contentItem: RowLayout {
                            Label { text: modelData.name; font.bold: modelData.today; Layout.fillWidth: true }
                            Label {
                                text: modelData.today ? qsTr("today · %1 years").arg(modelData.age)
                                      : modelData.recent ? qsTr("%1 days ago · %2 years").arg(-modelData.days).arg(modelData.age)
                                      : qsTr("in %1 days · %2 years").arg(modelData.days).arg(modelData.age)
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
                Layout.leftMargin: 12; Layout.rightMargin: 12

                Repeater {
                    model: root.recitalRows
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Button { text: modelData.name; flat: true; Layout.fillWidth: true; onClicked: root.editPupil(modelData.id) }
                        Label { text: qsTr("%1 days since %2").arg(modelData.daysSince).arg(modelData.referenceDate); opacity: 0.65 }
                        ToolButton { text: "+!"; Accessible.name: qsTr("Add reminder"); onClicked: root.reminder(modelData.id, qsTr("Speak about concert activity!")) }
                    }
                }
                Label { visible: root.recitalRows.length === 0; text: qsTr("No overdue concert candidates"); opacity: 0.6 }
            }

            SectionCard {
                title: qsTr("Ensemble activity")
                Layout.fillWidth: true
                Layout.leftMargin: 12; Layout.rightMargin: 12

                Repeater {
                    model: root.ensembleRows
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Button { text: modelData.name; flat: true; Layout.fillWidth: true; onClicked: root.editPupil(modelData.id) }
                        Label { text: modelData.lastDescription || qsTr("no previous ensemble"); opacity: 0.65 }
                        ToolButton { text: "+!"; Accessible.name: qsTr("Add reminder"); onClicked: root.reminder(modelData.id, qsTr("Speak about ensemble activity!")) }
                    }
                }
                Label { visible: root.ensembleRows.length === 0; text: qsTr("All requested pupils have an active ensemble activity"); opacity: 0.6 }
            }

            SectionCard {
                title: qsTr("Instrument overview")
                Layout.fillWidth: true
                Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.bottomMargin: 12
                Button {
                    text: qsTr("Rental Instruments Inventory List ...")
                    onClicked: rentalPreview.showDocument(App.rentalInstrumentDocumentHtml(),
                                                          qsTr("Rental instrument inventory list"), "", false)
                }

                RowLayout {
                    Label { text: qsTr("Rental instruments: %1").arg(root.instrumentData.rentalCount); font.bold: true }
                    Label { text: qsTr("Next size needed: %1").arg(root.instrumentData.nextSizeCount); font.bold: true }
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
                        Layout.fillWidth: true
                        onClicked: root.editPupil(modelData.id)
                        contentItem: RowLayout {
                            Label { text: modelData.name; Layout.fillWidth: true }
                            Label { text: [modelData.instrument, modelData.size].filter(x => x && x.length).join(" · "); opacity: 0.7 }
                            Label { visible: modelData.rental; text: qsTr("rental"); font.bold: true }
                            Label { visible: modelData.needsNextSize; text: qsTr("next size"); font.bold: true }
                        }
                    }
                }
            }
        }
    }

    DocumentPreviewDialog { id: rentalPreview }

    Popup { id: reminderSaved; anchors.centerIn: parent; Label { text: qsTr("Reminder added") } }
}

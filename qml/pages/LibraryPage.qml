// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

Page {
    id: root
    property int loanId: -1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        SectionCard {
            title: qsTr("Add music")
            Layout.fillWidth: true
            GridLayout {
                columns: root.width > 800 ? 4 : 1
                Layout.fillWidth: true
                LabeledField { id: author; label: qsTr("Composer / author") }
                LabeledField { id: titleField; label: qsTr("Title") }
                LabeledField { id: publisher; label: qsTr("Publisher") }
                Button {
                    text: qsTr("Add")
                    enabled: author.text.trim().length && titleField.text.trim().length && publisher.text.trim().length
                    onClicked: if (App.addSheetMusic(author.text, titleField.text, publisher.text) >= 0) titleField.clear()
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            model: App.library
            spacing: 6; clip: true
            delegate: ItemDelegate {
                required property var model
                required property string author
                required property string title
                required property string publisher
                required property int rentPupilId
                required property string rentPupilName
                required property string rentDate
                required property bool available
                width: list.width
                contentItem: RowLayout {
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: author + " — " + title; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label {
                            text: publisher + (available ? " · " + qsTr("available") : " · " + qsTr("loaned to %1").arg(rentPupilName) + (rentDate ? " · " + rentDate : ""))
                            opacity: 0.65; Layout.fillWidth: true; elide: Text.ElideRight
                        }
                    }
                    Button {
                        text: available ? qsTr("Loan") : qsTr("Return")
                        onClicked: {
                            if (available) { root.loanId = model.id; loanPupil.currentIndex = 0; loanDialog.open() }
                            else App.returnSheetMusic(model.id)
                        }
                    }
                    ToolButton { text: "×"; onClicked: App.deleteSheetMusic(model.id) }
                }
            }
        }
    }

    Dialog {
        id: loanDialog
        anchors.centerIn: parent
        width: Math.min(450, root.width - 32)
        title: qsTr("Loan music")
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: if (loanPupil.currentIndex >= 0) App.loanSheetMusic(root.loanId, loanPupil.currentValue)
        ColumnLayout {
            width: parent.width
            Label { text: qsTr("Pupil"); font.bold: true }
            ComboBox { id: loanPupil; Layout.fillWidth: true; model: App.pupils; textRole: "name"; valueRole: "id" }
        }
    }
}

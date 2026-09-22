// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    width: 1100
    height: 760

    property var libraryModel: null
    property var pupilsModel: null
    property var addAction: null
    property var loanOrReturnAction: null
    property var deleteAction: null
    property bool canAdd: false

    property alias authorField: author
    property alias titleField: titleField
    property alias publisherField: publisher
    property alias loanDialog: loanDialog
    property alias loanPupil: loanPupil

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
                    enabled: root.canAdd
                    action: root.addAction
                }
            }
        }

        ListView {
            id: libraryList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.libraryModel
            spacing: 6
            clip: true
            delegate: ItemDelegate {
                required property var model
                required property string author
                required property string title
                required property string publisher
                required property int rentPupilId
                required property string rentPupilName
                required property string rentDate
                required property bool available
                width: libraryList.width
                contentItem: RowLayout {
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: author + " — " + title; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label {
                            text: publisher + (available ? " · " + qsTr("available") : " · " + qsTr("loaned to") + " " + rentPupilName + (rentDate ? " · " + rentDate : ""))
                            opacity: 0.65
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                    Button {
                        property int recordId: model.id
                        property bool itemAvailable: available
                        text: available ? qsTr("Loan") : qsTr("Return")
                        action: root.loanOrReturnAction
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
        id: loanDialog
        anchors.centerIn: parent
        width: Math.min(450, root.width - 32)
        title: qsTr("Loan music")
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        ColumnLayout {
            width: parent.width
            Label { text: qsTr("Pupil"); font.bold: true }
            ComboBox { id: loanPupil; Layout.fillWidth: true; model: root.pupilsModel; textRole: "name"; valueRole: "id" }
        }
    }
}

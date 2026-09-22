// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    width: 1100
    height: 760

    property var pupilsModel: null
    property string pupilFilter: ""
    property var editPupilAction: null
    property var addPupilAction: null
    property alias searchField: searchField

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            TextField {
                id: searchField
                placeholderText: qsTr("Search pupils…")
                text: root.pupilFilter
                Layout.fillWidth: true
            }
            Button { text: qsTr("Add"); action: root.addPupilAction }
        }

        ListView {
            id: pupilsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.pupilsModel
            spacing: 6

            delegate: ItemDelegate {
                required property var model
                required property string name
                required property string instrument
                required property string email
                required property string phone
                property int recordId: model.id
                width: pupilsList.width
                action: root.editPupilAction
                contentItem: RowLayout {
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: name; font.bold: true; font.pixelSize: 17; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label {
                            text: instrument + (instrument && email ? " · " : "") + email + ((instrument || email) && phone ? " · " : "") + phone
                            opacity: 0.65
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    Label { text: "›"; font.pixelSize: 28; opacity: 0.55 }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: pupilsList.count === 0
                text: root.pupilFilter.length ? qsTr("No matching pupils") : qsTr("No pupils yet")
                opacity: 0.65
            }
        }
    }
}

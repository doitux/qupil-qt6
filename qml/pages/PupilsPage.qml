// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

Page {
    id: root
    signal editPupil(int recordId)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            TextField {
                placeholderText: qsTr("Search pupils…")
                text: App.pupilFilter
                Layout.fillWidth: true
                onTextChanged: App.pupilFilter = text
            }
            Button { text: qsTr("Add"); onClicked: root.editPupil(-1) }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: App.pupils
            spacing: 6

            delegate: ItemDelegate {
                required property var model
                required property string name
                required property string instrument
                required property string email
                required property string phone
                width: list.width
                onClicked: root.editPupil(model.id)
                contentItem: RowLayout {
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: name; font.bold: true; font.pixelSize: 17; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label {
                            text: [instrument, email, phone].filter(x => x && x.length).join(" · ")
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
                visible: list.count === 0
                text: App.pupilFilter.length ? qsTr("No matching pupils") : qsTr("No pupils yet")
                opacity: 0.65
            }
        }
    }
}

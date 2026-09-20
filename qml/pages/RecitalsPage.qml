// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

Page {
    id: root
    signal editRecital(int recordId)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label { text: qsTr("Events"); font.pixelSize: 22; font.bold: true; Layout.fillWidth: true }
            Button { text: qsTr("Add"); onClicked: root.editRecital(-1) }
        }

        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            model: App.recitals
            spacing: 6; clip: true
            delegate: ItemDelegate {
                required property var model
                required property string description
                required property string date
                required property string time
                required property string location
                required property string stateName
                width: list.width
                onClicked: root.editRecital(model.id)
                contentItem: RowLayout {
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: description.length ? description : qsTr("Untitled event"); font.bold: true; font.pixelSize: 17; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label { text: [date, time, location, stateName].filter(x => x && x.length).join(" · "); opacity: 0.65; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                    Label { text: "›"; font.pixelSize: 28; opacity: 0.55 }
                }
            }
        }
    }
}

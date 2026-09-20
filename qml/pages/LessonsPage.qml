// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

Page {
    id: root
    signal editLesson(int recordId)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label { text: qsTr("Active lessons"); font.pixelSize: 22; font.bold: true; Layout.fillWidth: true }
            Button { text: qsTr("Add"); onClicked: root.editLesson(-1) }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: App.lessons
            clip: true
            spacing: 6

            delegate: ItemDelegate {
                required property var model
                required property string name
                required property string typeName
                required property string dayName
                required property string start
                required property string stop
                required property string location
                required property string pupilNames
                width: list.width
                onClicked: root.editLesson(model.id)
                contentItem: ColumnLayout {
                    Label { text: name; font.bold: true; font.pixelSize: 17; Layout.fillWidth: true; elide: Text.ElideRight }
                    Label {
                        text: [typeName, dayName + (start ? " " + start + "–" + stop : ""), location].filter(x => x && x.length).join(" · ")
                        opacity: 0.65
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Label { visible: pupilNames.length > 0; text: pupilNames; opacity: 0.8; Layout.fillWidth: true; elide: Text.ElideRight }
                }
            }
        }
    }
}

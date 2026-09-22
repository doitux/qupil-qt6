// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    width: 1100
    height: 760
    property var lessonsModel: null
    property var editLessonAction: null
    property var addLessonAction: null

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label { text: qsTr("Active lessons"); font.pixelSize: 22; font.bold: true; Layout.fillWidth: true }
            Button { text: qsTr("Add"); action: root.addLessonAction }
        }

        ListView {
            id: lessonsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.lessonsModel
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
                property int recordId: model.id
                width: lessonsList.width
                action: root.editLessonAction
                contentItem: ColumnLayout {
                    Label { text: name; font.bold: true; font.pixelSize: 17; Layout.fillWidth: true; elide: Text.ElideRight }
                    Label {
                        text: typeName + (dayName ? " · " + dayName : "") + (start ? " " + start + "–" + stop : "") + (location ? " · " + location : "")
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

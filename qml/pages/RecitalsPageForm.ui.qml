// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    width: 1100
    height: 760
    property var recitalsModel: null
    property var editRecitalAction: null
    property var addRecitalAction: null

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label { text: qsTr("Events"); font.pixelSize: 22; font.bold: true; Layout.fillWidth: true }
            Button { text: qsTr("Add"); action: root.addRecitalAction }
        }

        ListView {
            id: recitalsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.recitalsModel
            spacing: 6
            clip: true
            delegate: ItemDelegate {
                required property var model
                required property string description
                required property string date
                required property string time
                required property string location
                required property string stateName
                property int recordId: model.id
                width: recitalsList.width
                action: root.editRecitalAction
                contentItem: RowLayout {
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: description.length ? description : qsTr("Untitled event"); font.bold: true; font.pixelSize: 17; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label {
                            text: date + (date && time ? " · " : "") + time + ((date || time) && location ? " · " : "") + location + ((date || time || location) && stateName ? " · " : "") + stateName
                            opacity: 0.65
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                    Label { text: "›"; font.pixelSize: 28; opacity: 0.55 }
                }
            }
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property string title: qsTr("Nothing here yet")
    property string description: ""

    implicitHeight: column.implicitHeight + 48

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width - 32, 480))
        spacing: 8

        Label {
            text: title
            font.pixelSize: 20
            font.bold: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: true
        }
        Label {
            visible: description.length > 0
            text: description
            wrapMode: Text.WordWrap
            opacity: 0.7
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
    }
}

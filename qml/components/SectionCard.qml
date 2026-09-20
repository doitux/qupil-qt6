// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: root
    property string title: ""
    default property alias content: contentColumn.data

    padding: 16

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            visible: root.title.length > 0
            text: root.title
            font.pixelSize: 18
            font.bold: true
            Layout.fillWidth: true
        }

        ColumnLayout {
            id: contentColumn
            spacing: 10
            Layout.fillWidth: true
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string label: ""
    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property alias readOnly: field.readOnly

    spacing: 4
    Layout.fillWidth: true

    Label {
        text: root.label
        font.bold: true
        opacity: 0.8
    }
    TextField {
        id: field
        Layout.fillWidth: true
    }
}

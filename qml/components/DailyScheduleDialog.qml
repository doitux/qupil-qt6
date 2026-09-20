// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

Dialog {
    id: root
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    title: qsTr("Create Daily Schedule - Qupil")
    standardButtons: Dialog.Ok | Dialog.Cancel
    width: Math.max(320, Math.min(parent ? parent.width - 32 : 560, 560))

    property var previewDialog: null
    property var dayRows: []

    function rebuildDays() {
        const names = [qsTr("Monday"), qsTr("Tuesday"), qsTr("Wednesday"), qsTr("Thursday"),
                       qsTr("Friday"), qsTr("Saturday"), qsTr("Sunday")]
        const today = new Date()
        const current = today.getDay() === 0 ? 6 : today.getDay() - 1
        let rows = []
        for (let i = 0; i < 7; ++i) {
            let delta = i - current
            if (delta < 0) delta += 7
            const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() + delta)
            rows.push(names[i] + " - " + Qt.formatDate(d, "dd.MM.yyyy"))
        }
        rows.push(qsTr("Irregular"))
        dayRows = rows
        weekday.currentIndex = current
    }

    onOpened: rebuildDays()
    onAccepted: {
        if (!previewDialog)
            return
        const html = App.dayOverviewDocumentHtml(weekday.currentIndex, noteCount.value, freeSpace.value)
        previewDialog.showDocument(html, qsTr("Daily schedule"), "", false)
    }

    contentItem: GridLayout {
        columns: 2
        rowSpacing: 10
        columnSpacing: 12

        Label { text: qsTr("Weekday:") }
        ComboBox { id: weekday; Layout.fillWidth: true; model: root.dayRows }

        Label { text: qsTr("Show the last") }
        RowLayout {
            SpinBox { id: noteCount; from: 0; to: 99; value: 3; editable: true }
            Label { text: qsTr("notes for every lesson"); Layout.fillWidth: true; wrapMode: Text.WordWrap }
        }

        Label { text: qsTr("Add around") }
        RowLayout {
            SpinBox { id: freeSpace; from: 0; to: 99; value: 2; editable: true }
            Label { text: qsTr("cm free space for handwritten notes"); Layout.fillWidth: true; wrapMode: Text.WordWrap }
        }
    }
}

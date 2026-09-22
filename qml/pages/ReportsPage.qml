// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import "../components"

Page {
    id: root
    signal editPupil(int recordId)

    property var birthdayRows: []
    property var recitalRows: []
    property var ensembleRows: []
    property var instrumentData: ({ pupils: [], instruments: [], sizes: [], rentalCount: 0, nextSizeCount: 0 })

    function reload() {
        birthdayRows = App.birthdays()
        recitalRows = App.overdueRecitalPupils()
        ensembleRows = App.pupilsWithoutEnsemble()
        instrumentData = App.instrumentOverview()
    }

    function reminder(pupilId, text) {
        App.saveReminder({ id: -1, description: text, mode: 2, pupilId: pupilId, sound: true })
        reminderSaved.open()
    }

    Action { id: editPupilAction; onTriggered: source => root.editPupil(source.recordId) }
    Action { id: addReminderAction; onTriggered: source => root.reminder(source.pupilId, source.reminderText) }
    Action {
        id: rentalDocumentAction
        onTriggered: rentalPreview.showDocument(App.rentalInstrumentDocumentHtml(),
                                                  qsTr("Rental instrument inventory list"), "", false)
    }

    ReportsPageForm {
        anchors.fill: parent
        birthdayRows: root.birthdayRows
        recitalRows: root.recitalRows
        ensembleRows: root.ensembleRows
        instrumentData: root.instrumentData
        editPupilAction: editPupilAction
        addReminderAction: addReminderAction
        rentalDocumentAction: rentalDocumentAction
    }

    DocumentPreviewDialog { id: rentalPreview }
    Popup { id: reminderSaved; anchors.centerIn: parent; Label { text: qsTr("Reminder added") } }

    Component.onCompleted: reload()
}

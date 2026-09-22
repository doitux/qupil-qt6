// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Page {
    id: root
    property int loanId: -1

    Action {
        id: addAction
        onTriggered: {
            if (App.addSheetMusic(form.authorField.text, form.titleField.text, form.publisherField.text) >= 0)
                form.titleField.text = ""
        }
    }

    Action {
        id: loanOrReturnAction
        onTriggered: source => {
            if (source.itemAvailable) {
                root.loanId = source.recordId
                form.loanPupil.currentIndex = 0
                form.loanDialog.open()
            } else {
                App.returnSheetMusic(source.recordId)
            }
        }
    }

    Action {
        id: deleteAction
        onTriggered: source => App.deleteSheetMusic(source.recordId)
    }

    LibraryPageForm {
        id: form
        anchors.fill: parent
        libraryModel: App.library
        pupilsModel: App.pupils
        addAction: addAction
        loanOrReturnAction: loanOrReturnAction
        deleteAction: deleteAction
        canAdd: authorField.text.trim().length > 0
                && titleField.text.trim().length > 0
                && publisherField.text.trim().length > 0

        loanDialog.onAccepted: {
            if (loanPupil.currentIndex >= 0)
                App.loanSheetMusic(root.loanId, loanPupil.currentValue)
        }
    }
}

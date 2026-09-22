// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Page {
    id: root
    property int pupilId: -1
    property var memberships: []
    property var notes: []
    property var pieces: []
    property var activities: []
    property var loans: []
    signal done()

    function load() {
        if (pupilId < 0) {
            form.forename.text = ""
            form.surname.text = ""
            form.firstLesson.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
            form.birthday.text = "2000-01-01"
            form.rentalSince.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
            return
        }
        const p = App.pupil(pupilId)
        form.forename.text = p.forename || ""
        form.surname.text = p.surname || ""
        form.addressField.text = p.address || ""
        form.email.text = p.email || ""
        form.phone.text = p.phone || ""
        form.mobile.text = p.mobile || ""
        form.birthday.text = p.birthday || ""
        form.personalNotes.text = p.notes || ""
        form.fatherName.text = p.fatherName || ""
        form.fatherJob.text = p.fatherJob || ""
        form.fatherPhone.text = p.fatherPhone || ""
        form.motherName.text = p.motherName || ""
        form.motherJob.text = p.motherJob || ""
        form.motherPhone.text = p.motherPhone || ""
        form.firstLesson.text = p.firstLessonDate || ""
        form.instrument.text = p.instrument || ""
        form.instrumentSize.text = p.instrumentSize || ""
        form.needsNextSize.checked = !!p.needsNextInstrumentSize
        form.rentalInstrument.checked = !!p.hasRentalInstrument
        form.rentalNumber.text = p.rentalInstrumentNumber || ""
        form.rentalSince.text = p.rentalInstrumentSince || ""
        form.recitalInterval.currentIndex = Math.max(0, Math.min(9, p.recitalInterval || 0))
        form.ensembleExpected.checked = !!p.ensembleActivityRequested
        reloadRelated()
    }

    function reloadRelated() {
        if (pupilId < 0)
            return
        memberships = App.pupilLessonMemberships(pupilId)
        notes = App.notesForPupil(pupilId)
        pieces = App.piecesForPupil(pupilId)
        activities = App.activitiesForPupil(pupilId)
        loans = App.loanedMusicForPupil(pupilId)
    }

    function keepEditorCursorVisible(scrollView, editor) {
        const flick = scrollView.contentItem
        if (!flick || !editor)
            return
        const margin = 8
        const cursorTop = Math.max(0, editor.cursorRectangle.y - margin)
        const cursorBottom = editor.cursorRectangle.y + editor.cursorRectangle.height + margin
        const viewportTop = flick.contentY
        const viewportBottom = viewportTop + scrollView.availableHeight
        if (cursorTop < viewportTop) {
            flick.contentY = cursorTop
        } else if (cursorBottom > viewportBottom) {
            const maxY = Math.max(0, flick.contentHeight - scrollView.availableHeight)
            flick.contentY = Math.min(maxY, cursorBottom - scrollView.availableHeight)
        }
    }

    function useNoteAsTemplate(content) {
        form.tabs.currentIndex = 1
        form.noteText.text = App.noteTemplateText(content || "")
        Qt.callLater(function() {
            if (form.notesScroll.contentItem)
                form.notesScroll.contentItem.contentY = 0
            form.noteText.forceActiveFocus()
            form.noteText.cursorPosition = form.noteText.text.length
            root.keepEditorCursorVisible(form.pupilLessonNoteEditor, form.noteText)
        })
    }

    function save() {
        const id = App.savePupil({
            id: pupilId,
            forename: form.forename.text,
            surname: form.surname.text,
            address: form.addressField.text,
            email: form.email.text,
            phone: form.phone.text,
            mobile: form.mobile.text,
            birthday: form.birthday.text,
            notes: form.personalNotes.text,
            fatherName: form.fatherName.text,
            fatherJob: form.fatherJob.text,
            fatherPhone: form.fatherPhone.text,
            motherName: form.motherName.text,
            motherJob: form.motherJob.text,
            motherPhone: form.motherPhone.text,
            firstLessonDate: form.firstLesson.text,
            instrument: form.instrument.text,
            instrumentSize: form.instrumentSize.text,
            needsNextInstrumentSize: form.needsNextSize.checked,
            hasRentalInstrument: form.rentalInstrument.checked,
            rentalInstrumentNumber: form.rentalNumber.text,
            rentalInstrumentSince: form.rentalSince.text,
            recitalInterval: form.recitalInterval.currentIndex,
            ensembleActivityRequested: form.ensembleExpected.checked
        })
        if (id >= 0) {
            pupilId = id
            reloadRelated()
            savedNotice.open()
        }
    }

    Action { id: backAction; onTriggered: root.done() }
    Action { id: saveAction; onTriggered: root.save() }
    Action { id: openArchiveAction; onTriggered: form.archiveConfirm.open() }
    Action { id: openDeleteAction; onTriggered: form.deleteConfirm.open() }
    Action {
        id: addNoteAction
        onTriggered: {
            if (App.addNote(form.noteMembership.currentValue, form.noteDate.text, form.noteText.text) >= 0) {
                form.noteText.text = ""
                root.notes = App.notesForPupil(root.pupilId)
            }
        }
    }
    Action { id: useNoteAction; onTriggered: source => root.useNoteAsTemplate(source.noteContent) }
    Action {
        id: deleteNoteAction
        onTriggered: source => {
            App.deleteNote(source.noteId)
            root.notes = App.notesForPupil(root.pupilId)
        }
    }
    Action {
        id: addPieceAction
        onTriggered: {
            if (App.addPiece(form.pieceMembership.currentValue, form.composer.text, form.pieceTitle.text,
                             form.genre.text, form.duration.value, form.pieceState.currentIndex) >= 0) {
                form.pieceTitle.text = ""
                root.pieces = App.piecesForPupil(root.pupilId)
            }
        }
    }
    Action {
        id: deletePieceAction
        onTriggered: source => {
            App.deletePiece(source.pieceId)
            root.pieces = App.piecesForPupil(root.pupilId)
        }
    }
    Action {
        id: addActivityAction
        onTriggered: {
            if (App.addActivity(root.pupilId, form.activityContinuous.checked, {
                                    description: form.activityDescription.text,
                                    date: form.activityDate.text,
                                    time: form.activityTime.text,
                                    day: form.activityDay.currentIndex,
                                    type: form.activityType.currentIndex
                                }) >= 0) {
                form.activityDescription.text = ""
                root.activities = App.activitiesForPupil(root.pupilId)
            }
        }
    }
    Action {
        id: deleteActivityAction
        onTriggered: source => {
            App.deleteActivity(source.activityId)
            root.activities = App.activitiesForPupil(root.pupilId)
        }
    }
    Action {
        id: returnLoanAction
        onTriggered: source => {
            App.returnSheetMusic(source.musicId)
            root.loans = App.loanedMusicForPupil(root.pupilId)
        }
    }

    PupilDetailPageForm {
        id: form
        anchors.fill: parent
        pupilId: root.pupilId
        displayName: (forename.text + " " + surname.text).trim()
        memberships: root.memberships
        notes: root.notes
        pieces: root.pieces
        activities: root.activities
        loans: root.loans
        paletteText: root.palette.text
        canAddNote: root.memberships.length > 0 && noteText.text.trim().length > 0
        canAddPiece: root.memberships.length > 0 && composer.text.trim().length > 0 && pieceTitle.text.trim().length > 0
        canAddActivity: activityDescription.text.trim().length > 0
        backAction: backAction
        saveAction: saveAction
        openArchiveAction: openArchiveAction
        openDeleteAction: openDeleteAction
        addNoteAction: addNoteAction
        useNoteAction: useNoteAction
        deleteNoteAction: deleteNoteAction
        addPieceAction: addPieceAction
        deletePieceAction: deletePieceAction
        addActivityAction: addActivityAction
        deleteActivityAction: deleteActivityAction
        returnLoanAction: returnLoanAction

        personalNotes.onCursorRectangleChanged: root.keepEditorCursorVisible(personalNotesEditor, personalNotes)
        noteText.onCursorRectangleChanged: root.keepEditorCursorVisible(pupilLessonNoteEditor, noteText)
        deleteConfirm.onAccepted: if (App.deletePupil(root.pupilId)) root.done()
        archiveConfirm.onAccepted: if (App.archivePupil(root.pupilId)) root.done()
    }

    Popup {
        id: savedNotice
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Label { text: qsTr("Saved") }
    }

    Component.onCompleted: load()
    Connections { target: App; function onDataChanged() { root.reloadRelated() } }
}

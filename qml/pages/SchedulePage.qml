// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Page {
    id: root
    signal editLesson(int recordId)
    signal editPupil(int recordId)

    property var rows: []
    property int selectedPalId: -1
    property int selectedPupilId: -1
    property int selectedLessonId: -1
    property var workContext: ({})
    property var workNotes: []
    property var workPieces: []
    property bool compactWorkView: width < 860
    property bool shareLessonContent: App.settingValue("saveNotesPiecesForAllPupils", true)

    function reload() {
        rows = App.scheduleForDay(form.days.currentIndex)
    }

    function reloadWork() {
        if (selectedPalId < 0) {
            workContext = ({})
            workNotes = []
            workPieces = []
            return
        }
        workContext = App.lessonMembershipContext(selectedPalId)
        workNotes = App.notesForMembership(selectedPalId)
        workPieces = App.piecesForMembership(selectedPalId)
    }

    function selectMembership(membership, lessonId) {
        selectedPalId = Number(membership.palId)
        selectedPupilId = Number(membership.pupilId)
        selectedLessonId = Number(lessonId)
        reloadWork()
        form.workTabs.currentIndex = 0
    }

    function closeWork() {
        selectedPalId = -1
        selectedPupilId = -1
        selectedLessonId = -1
        reloadWork()
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
        form.noteText.text = App.noteTemplateText(content || "")
        form.workTabs.currentIndex = 0
        Qt.callLater(function() {
            if (form.workNotesScroll.contentItem)
                form.workNotesScroll.contentItem.contentY = 0
            form.noteText.forceActiveFocus()
            form.noteText.cursorPosition = form.noteText.text.length
            root.keepEditorCursorVisible(form.scheduleNoteEditor, form.noteText)
        })
    }

    Action {
        id: editLessonAction
        onTriggered: source => root.editLesson(source.recordId)
    }

    Action {
        id: selectMembershipAction
        onTriggered: source => root.selectMembership(source.membershipData, source.lessonId)
    }

    Action { id: closeWorkAction; onTriggered: root.closeWork() }
    Action { id: editPupilAction; onTriggered: root.editPupil(root.selectedPupilId) }
    Action { id: editSelectedLessonAction; onTriggered: root.editLesson(root.selectedLessonId) }

    Action {
        id: addNoteAction
        onTriggered: {
            if (App.addNote(root.selectedPalId, form.noteDate.text, form.noteText.text) >= 0)
                form.noteText.clear()
        }
    }

    Action {
        id: useNoteAction
        onTriggered: source => root.useNoteAsTemplate(source.noteContent)
    }

    Action {
        id: deleteNoteAction
        onTriggered: source => App.deleteNote(source.noteId)
    }

    Action {
        id: addPieceAction
        onTriggered: {
            if (App.addPiece(root.selectedPalId,
                             form.workComposer.text,
                             form.workPieceTitle.text,
                             form.workGenre.text,
                             form.workDuration.value,
                             form.workPieceState.currentIndex) >= 0) {
                form.workPieceTitle.clear()
            }
        }
    }

    Action {
        id: deletePieceAction
        onTriggered: source => App.deletePiece(source.pieceId)
    }

    Connections {
        target: App
        function onDataChanged() {
            root.reload()
            root.reloadWork()
        }
    }

    SchedulePageForm {
        id: form
        anchors.fill: parent
        rows: root.rows
        selectedPalId: root.selectedPalId
        workContext: root.workContext
        workNotes: root.workNotes
        workPieces: root.workPieces
        compactWorkView: root.compactWorkView
        shareLessonContent: root.shareLessonContent
        canAddNote: root.selectedPalId >= 0 && noteText.text.trim().length > 0
        canAddPiece: root.selectedPalId >= 0
                     && workComposer.text.trim().length > 0
                     && workPieceTitle.text.trim().length > 0
        paletteBase: root.palette.base
        paletteMid: root.palette.mid
        paletteMidlight: root.palette.midlight
        paletteHighlight: root.palette.highlight
        paletteHighlightedText: root.palette.highlightedText
        paletteText: root.palette.text

        editLessonAction: editLessonAction
        selectMembershipAction: selectMembershipAction
        closeWorkAction: closeWorkAction
        editPupilAction: editPupilAction
        editSelectedLessonAction: editSelectedLessonAction
        addNoteAction: addNoteAction
        useNoteAction: useNoteAction
        deleteNoteAction: deleteNoteAction
        addPieceAction: addPieceAction
        deletePieceAction: deletePieceAction

        days.onCurrentIndexChanged: root.reload()
        noteText.onCursorRectangleChanged: root.keepEditorCursorVisible(scheduleNoteEditor, noteText)
    }

    Component.onCompleted: {
        const currentDay = new Date().getDay()
        form.days.currentIndex = Math.max(0, Math.min(6, currentDay === 0 ? 6 : currentDay - 1))
        reload()
    }
}

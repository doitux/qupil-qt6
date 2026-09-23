// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import "../components"

Page {
    id: root
    property int recitalId: -1
    property int recitalState: 0
    property var eventPieces: []
    property var candidates: []
    property bool programOrderDirty: false
    signal done()

    function reloadPieces() {
        if (recitalId < 0) {
            eventPieces = []
            candidates = []
            return
        }
        eventPieces = App.recitalPieces(recitalId)
        candidates = App.readyPieces()
        programOrderDirty = false
    }

    function moveProgramPiece(parId, direction) {
        let from = -1
        for (let i = 0; i < eventPieces.length; ++i) {
            if (eventPieces[i].parId === parId) {
                from = i
                break
            }
        }
        const to = from + direction
        if (from < 0 || to < 0 || to >= eventPieces.length)
            return

        const reordered = eventPieces.slice()
        const moved = reordered.splice(from, 1)[0]
        reordered.splice(to, 0, moved)
        eventPieces = reordered
        programOrderDirty = true
    }

    function saveProgramOrder() {
        if (!programOrderDirty || recitalId < 0)
            return true

        const parIds = []
        for (let i = 0; i < eventPieces.length; ++i)
            parIds.push(eventPieces[i].parId)

        if (!App.saveRecitalPieceOrder(recitalId, parIds))
            return false

        reloadPieces()
        return true
    }

    function programPdfBaseName() {
        const parts = []
        const description = form.eventDescription.text.trim()
        const location = form.eventLocation.text.trim()
        const date = form.eventDate.text.trim()

        if (description.length > 0)
            parts.push(description)
        if (location.length > 0)
            parts.push(location)
        if (date.length > 0)
            parts.push(date)

        return parts.length > 0 ? parts.join("_") : "Qupil"
    }

    function load() {
        if (recitalId < 0) {
            recitalState = 0
            form.eventDescription.text = ""
            form.eventDate.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
            form.eventTime.text = "18:00"
            form.eventLocation.text = ""
            form.organizer.text = ""
            form.accompanist.text = ""
            return
        }
        const e = App.recital(recitalId)
        recitalState = e.state || 0
        form.eventDescription.text = e.description || ""
        form.eventDate.text = e.date || ""
        form.eventTime.text = e.time || ""
        form.eventLocation.text = e.location || ""
        form.organizer.text = e.organizer || ""
        form.accompanist.text = e.accompanist || ""
        reloadPieces()
    }

    function save() {
        const id = App.saveRecital({
            id: recitalId,
            description: form.eventDescription.text,
            date: form.eventDate.text,
            time: form.eventTime.text,
            location: form.eventLocation.text,
            organizer: form.organizer.text,
            accompanist: form.accompanist.text,
            state: recitalState
        })
        if (id >= 0) {
            recitalId = id
            if (!saveProgramOrder())
                return
            load()
            saved.open()
        }
    }

    Action { id: backAction; onTriggered: root.done() }
    Action { id: saveAction; onTriggered: root.save() }
    Action {
        id: documentAction
        onTriggered: {
            if (!root.saveProgramOrder())
                return
            recitalPreview.showDocument(
                App.recitalDocumentHtml(root.recitalId),
                qsTr("Program overview for events"),
                root.programPdfBaseName(),
                true)
        }
    }
    Action {
        id: moveProgramPieceAction
        onTriggered: source => root.moveProgramPiece(source.parId, source.direction)
    }
    Action {
        id: saveProgramOrderAction
        enabled: root.programOrderDirty
        onTriggered: {
            if (root.saveProgramOrder())
                saved.open()
        }
    }
    Action {
        id: removePieceAction
        onTriggered: source => {
            if (!root.saveProgramOrder())
                return
            if (App.removePieceFromRecital(source.parId))
                root.reloadPieces()
        }
    }
    Action {
        id: addCandidateAction
        onTriggered: source => {
            if (!root.saveProgramOrder())
                return
            if (App.addPieceToRecital(root.recitalId, source.pieceId))
                root.reloadPieces()
        }
    }
    Action {
        id: addExternalAction
        onTriggered: {
            if (!root.saveProgramOrder())
                return
            if (App.addExternalPieceToRecital(root.recitalId,
                                              form.externalComposer.text,
                                              form.externalTitle.text,
                                              form.externalGenre.text,
                                              form.externalDuration.value,
                                              form.externalMusician.text)) {
                form.externalTitle.text = ""
                root.reloadPieces()
            }
        }
    }
    Action { id: openFinishAction; onTriggered: form.finishDialog.open() }
    Action { id: openDeleteAction; onTriggered: form.deleteDialog.open() }

    RecitalDetailPageForm {
        id: form
        anchors.fill: parent
        recitalId: root.recitalId
        recitalState: root.recitalState
        eventPieces: root.eventPieces
        candidates: root.candidates
        backAction: backAction
        saveAction: saveAction
        documentAction: documentAction
        removePieceAction: removePieceAction
        moveProgramPieceAction: moveProgramPieceAction
        saveProgramOrderAction: saveProgramOrderAction
        programOrderDirty: root.programOrderDirty
        addCandidateAction: addCandidateAction
        addExternalAction: addExternalAction
        openFinishAction: openFinishAction
        openDeleteAction: openDeleteAction
        canAddExternal: externalTitle.text.trim().length > 0

        finishDialog.onAccepted: {
            if (App.finishRecital(root.recitalId, addActivities.checked, finishPieces.checked))
                root.done()
        }
        deleteDialog.onAccepted: {
            if (App.deleteRecital(root.recitalId))
                root.done()
        }
    }

    DocumentPreviewDialog { id: recitalPreview }
    Popup { id: saved; anchors.centerIn: parent; Label { text: qsTr("Saved") } }
    Component.onCompleted: load()
}

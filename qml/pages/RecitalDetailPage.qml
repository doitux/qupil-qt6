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
    signal done()

    function reloadPieces() {
        if (recitalId < 0) {
            eventPieces = []
            candidates = []
            return
        }
        eventPieces = App.recitalPieces(recitalId)
        candidates = App.readyPieces()
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
            load()
            saved.open()
        }
    }

    Action { id: backAction; onTriggered: root.done() }
    Action { id: saveAction; onTriggered: root.save() }
    Action {
        id: documentAction
        onTriggered: recitalPreview.showDocument(
            App.recitalDocumentHtml(root.recitalId),
            qsTr("Program overview for events"),
            form.eventDescription.text + "_" + form.eventLocation.text + "_" + form.eventDate.text,
            true)
    }
    Action {
        id: removePieceAction
        onTriggered: source => {
            if (App.removePieceFromRecital(source.parId))
                root.reloadPieces()
        }
    }
    Action {
        id: addCandidateAction
        onTriggered: source => {
            if (App.addPieceToRecital(root.recitalId, source.pieceId))
                root.reloadPieces()
        }
    }
    Action {
        id: addExternalAction
        onTriggered: {
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

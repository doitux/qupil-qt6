// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

Page {
    id: root
    property int recitalId: -1
    property var eventPieces: []
    property var candidates: []
    signal done()

    function reloadPieces() {
        if (recitalId < 0) { eventPieces = []; candidates = []; return }
        eventPieces = App.recitalPieces(recitalId)
        candidates = App.readyPieces()
    }

    function load() {
        if (recitalId < 0) {
            eventDescription.text = ""
            eventDate.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
            eventTime.text = "18:00"
            eventLocation.text = ""
            organizer.text = ""
            accompanist.text = ""
            return
        }
        const e = App.recital(recitalId)
        eventDescription.text = e.description || ""
        eventDate.text = e.date || ""
        eventTime.text = e.time || ""
        eventLocation.text = e.location || ""
        organizer.text = e.organizer || ""
        accompanist.text = e.accompanist || ""
        reloadPieces()
    }

    function save() {
        const previous = recitalId >= 0 ? App.recital(recitalId) : ({state: 0})
        const id = App.saveRecital({
            id: recitalId,
            description: eventDescription.text,
            date: eventDate.text,
            time: eventTime.text,
            location: eventLocation.text,
            organizer: organizer.text,
            accompanist: accompanist.text,
            state: previous.state || 0
        })
        if (id >= 0) {
            recitalId = id
            reloadPieces()
            saved.open()
        }
    }

    Component.onCompleted: load()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true; Layout.margins: 10
            Button { text: "‹ " + qsTr("Back"); onClicked: root.done() }
            Label { text: recitalId < 0 ? qsTr("New event") : eventDescription.text; font.bold: true; font.pixelSize: 20; Layout.fillWidth: true; elide: Text.ElideRight }
            Button { text: qsTr("Save"); onClicked: root.save() }
        }

        ScrollView {
            id: scroll
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scroll.availableWidth
                spacing: 12

                SectionCard {
                    title: qsTr("Event details")
                    Layout.fillWidth: true; Layout.margins: 12
                    GridLayout {
                        columns: root.width > 760 ? 2 : 1
                        Layout.fillWidth: true
                        LabeledField { id: eventDescription; label: qsTr("Description") }
                        LabeledField { id: eventLocation; label: qsTr("Location") }
                        LabeledField { id: eventDate; label: qsTr("Date (YYYY-MM-DD)") }
                        LabeledField { id: eventTime; label: qsTr("Time (HH:mm)") }
                        LabeledField { id: organizer; label: qsTr("Organizer") }
                        LabeledField { id: accompanist; label: qsTr("Default accompanist") }
                    }
                }

                SectionCard {
                    title: qsTr("Program")
                    visible: recitalId >= 0
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                    Button {
                        text: qsTr("Document ...")
                        onClicked: recitalPreview.showDocument(
                            App.recitalDocumentHtml(root.recitalId),
                            qsTr("Program overview for events"),
                            eventDescription.text + "_" + eventLocation.text + "_" + eventDate.text,
                            true)
                    }
                    Label { visible: root.eventPieces.length === 0; text: qsTr("No pieces in the program yet."); opacity: 0.65 }
                    Repeater {
                        model: root.eventPieces
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label { text: modelData.composer + " — " + modelData.title; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                Label { text: modelData.genre + (modelData.duration ? " · " + modelData.duration + " min" : "") + (modelData.external ? " · " + qsTr("external") : ""); opacity: 0.65 }
                            }
                            ToolButton { text: "×"; onClicked: if (App.removePieceFromRecital(modelData.parId)) root.reloadPieces() }
                        }
                    }
                }

                SectionCard {
                    title: qsTr("Ready for concert")
                    visible: recitalId >= 0
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                    Label { visible: root.candidates.length === 0; text: qsTr("No pieces are currently marked ready for concert."); opacity: 0.65 }
                    Repeater {
                        model: root.candidates
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label { text: modelData.composer + " — " + modelData.title; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                Label { text: [modelData.pupils, modelData.lessonName, modelData.genre].filter(x => x && x.length).join(" · "); opacity: 0.65; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                            Button { text: qsTr("Add"); onClicked: if (App.addPieceToRecital(root.recitalId, modelData.id)) root.reloadPieces() }
                        }
                    }
                }

                SectionCard {
                    title: qsTr("External piece")
                    visible: recitalId >= 0
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                    GridLayout {
                        columns: root.width > 760 ? 2 : 1
                        Layout.fillWidth: true
                        LabeledField { id: externalComposer; label: qsTr("Composer") }
                        LabeledField { id: externalTitle; label: qsTr("Title") }
                        LabeledField { id: externalGenre; label: qsTr("Genre") }
                        LabeledField { id: externalMusician; label: qsTr("Musician") }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: qsTr("Duration (minutes)"); font.bold: true }
                            SpinBox { id: externalDuration; from: 0; to: 180; value: 5; editable: true; Layout.fillWidth: true }
                        }
                    }
                    Button {
                        text: qsTr("Add external piece")
                        enabled: externalTitle.text.trim().length > 0
                        onClicked: {
                            if (App.addExternalPieceToRecital(root.recitalId, externalComposer.text, externalTitle.text, externalGenre.text, externalDuration.value, externalMusician.text)) {
                                externalTitle.clear(); root.reloadPieces()
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; Layout.margins: 12
                    Button { text: qsTr("Save"); onClicked: root.save() }
                    Button { visible: recitalId >= 0 && (App.recital(recitalId).state || 0) === 0; text: qsTr("Finish event…"); onClicked: finishDialog.open() }
                    Item { Layout.fillWidth: true }
                    Button { visible: recitalId >= 0; text: qsTr("Delete"); onClicked: deleteDialog.open() }
                }
                Item { Layout.preferredHeight: 12 }
            }
        }
    }

    DocumentPreviewDialog { id: recitalPreview }

    Dialog {
        id: finishDialog
        anchors.centerIn: parent
        width: Math.min(500, root.width - 32)
        title: qsTr("Finish event")
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: if (App.finishRecital(root.recitalId, addActivities.checked, finishPieces.checked)) root.done()
        ColumnLayout {
            width: parent.width
            Label { text: qsTr("Choose how Qupil should update the participating pupils."); wrapMode: Text.WordWrap; Layout.fillWidth: true }
            CheckBox { id: addActivities; text: qsTr("Add this event to pupil activities"); checked: true }
            CheckBox { id: finishPieces; text: qsTr("Mark performed pieces as finished"); checked: true }
        }
    }

    Dialog {
        id: deleteDialog
        anchors.centerIn: parent
        title: qsTr("Delete event?")
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: if (App.deleteRecital(root.recitalId)) root.done()
        Label { text: qsTr("The event and its program links will be deleted.") }
    }

    Popup { id: saved; anchors.centerIn: parent; Label { text: qsTr("Saved") } }
}

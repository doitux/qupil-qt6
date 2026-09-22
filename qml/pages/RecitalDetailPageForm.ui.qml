// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    width: 1100
    height: 760

    property int recitalId: -1
    property int recitalState: 0
    property var eventPieces: []
    property var candidates: []

    property var backAction: null
    property var saveAction: null
    property var documentAction: null
    property var removePieceAction: null
    property var addCandidateAction: null
    property var addExternalAction: null
    property var openFinishAction: null
    property var openDeleteAction: null
    property bool canAddExternal: false

    property alias eventDescription: eventDescription
    property alias eventLocation: eventLocation
    property alias eventDate: eventDate
    property alias eventTime: eventTime
    property alias organizer: organizer
    property alias accompanist: accompanist
    property alias externalComposer: externalComposer
    property alias externalTitle: externalTitle
    property alias externalGenre: externalGenre
    property alias externalMusician: externalMusician
    property alias externalDuration: externalDuration
    property alias finishDialog: finishDialog
    property alias addActivities: addActivities
    property alias finishPieces: finishPieces
    property alias deleteDialog: deleteDialog

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            Button { text: "‹ " + qsTr("Back"); action: root.backAction }
            Label { text: root.recitalId < 0 ? qsTr("New event") : eventDescription.text; font.bold: true; font.pixelSize: 20; Layout.fillWidth: true; elide: Text.ElideRight }
            Button { text: qsTr("Save"); action: root.saveAction }
        }

        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scroll.availableWidth
                spacing: 12

                SectionCard {
                    title: qsTr("Event details")
                    Layout.fillWidth: true
                    Layout.margins: 12
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
                    visible: root.recitalId >= 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Button { text: qsTr("Document ..."); action: root.documentAction }
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
                            ToolButton {
                                property int parId: modelData.parId
                                text: "×"
                                action: root.removePieceAction
                            }
                        }
                    }
                }

                SectionCard {
                    title: qsTr("Ready for concert")
                    visible: root.recitalId >= 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Label { visible: root.candidates.length === 0; text: qsTr("No pieces are currently marked ready for concert."); opacity: 0.65 }
                    Repeater {
                        model: root.candidates
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label { text: modelData.composer + " — " + modelData.title; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                Label {
                                    text: (modelData.pupils || "") + ((modelData.pupils || "") && (modelData.lessonName || "") ? " · " : "") + (modelData.lessonName || "") + (((modelData.pupils || "") || (modelData.lessonName || "")) && (modelData.genre || "") ? " · " : "") + (modelData.genre || "")
                                    opacity: 0.65
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }
                            Button {
                                property int pieceId: modelData.id
                                text: qsTr("Add")
                                action: root.addCandidateAction
                            }
                        }
                    }
                }

                SectionCard {
                    title: qsTr("External piece")
                    visible: root.recitalId >= 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
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
                        enabled: root.canAddExternal
                        action: root.addExternalAction
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 12
                    Button { text: qsTr("Save"); action: root.saveAction }
                    Button { visible: root.recitalId >= 0 && root.recitalState === 0; text: qsTr("Finish event…"); action: root.openFinishAction }
                    Item { Layout.fillWidth: true }
                    Button { visible: root.recitalId >= 0; text: qsTr("Delete"); action: root.openDeleteAction }
                }
                Item { Layout.preferredHeight: 12 }
            }
        }
    }

    Dialog {
        id: finishDialog
        anchors.centerIn: parent
        width: Math.min(500, root.width - 32)
        title: qsTr("Finish event")
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
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
        Label { text: qsTr("The event and its program links will be deleted.") }
    }
}

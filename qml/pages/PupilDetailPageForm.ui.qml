// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    width: 1100
    height: 760

    property int pupilId: -1
    property string displayName: ""
    property var memberships: []
    property var notes: []
    property var pieces: []
    property var activities: []
    property var loans: []
    property color paletteText: "#202020"
    property bool canAddNote: false
    property bool canAddPiece: false
    property bool canAddActivity: false

    property var backAction: null
    property var saveAction: null
    property var openArchiveAction: null
    property var openDeleteAction: null
    property var addNoteAction: null
    property var useNoteAction: null
    property var deleteNoteAction: null
    property var addPieceAction: null
    property var deletePieceAction: null
    property var addActivityAction: null
    property var deleteActivityAction: null
    property var returnLoanAction: null

    property alias tabs: tabs
    property alias forename: forename
    property alias surname: surname
    property alias addressField: addressField
    property alias email: email
    property alias phone: phone
    property alias mobile: mobile
    property alias birthday: birthday
    property alias firstLesson: firstLesson
    property alias personalNotesEditor: personalNotesEditor
    property alias personalNotes: personalNotes
    property alias fatherName: fatherName
    property alias fatherJob: fatherJob
    property alias fatherPhone: fatherPhone
    property alias motherName: motherName
    property alias motherJob: motherJob
    property alias motherPhone: motherPhone
    property alias instrument: instrument
    property alias instrumentSize: instrumentSize
    property alias needsNextSize: needsNextSize
    property alias rentalInstrument: rentalInstrument
    property alias rentalNumber: rentalNumber
    property alias rentalSince: rentalSince
    property alias recitalInterval: recitalInterval
    property alias ensembleExpected: ensembleExpected
    property alias notesScroll: notesScroll
    property alias noteMembership: noteMembership
    property alias noteDate: noteDate
    property alias pupilLessonNoteEditor: pupilLessonNoteEditor
    property alias noteText: noteText
    property alias pieceMembership: pieceMembership
    property alias composer: composer
    property alias pieceTitle: pieceTitle
    property alias genre: genre
    property alias duration: duration
    property alias pieceState: pieceState
    property alias activityDescription: activityDescription
    property alias activityContinuous: activityContinuous
    property alias activityDate: activityDate
    property alias activityTime: activityTime
    property alias activityDay: activityDay
    property alias activityType: activityType
    property alias deleteConfirm: deleteConfirm
    property alias archiveConfirm: archiveConfirm

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            Button { text: "‹ " + qsTr("Back"); action: root.backAction }
            Label {
                text: root.pupilId < 0 ? qsTr("New pupil") : root.displayName
                font.bold: true
                font.pixelSize: 20
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Button { text: qsTr("Save"); action: root.saveAction }
        }

        TabBar {
            id: tabs
            Layout.fillWidth: true
            currentIndex: 0
            TabButton { text: qsTr("Personal") }
            TabButton { text: qsTr("Notes"); enabled: root.pupilId >= 0 }
            TabButton { text: qsTr("Pieces"); enabled: root.pupilId >= 0 }
            TabButton { text: qsTr("Activities"); enabled: root.pupilId >= 0 }
            TabButton { text: qsTr("Loaned music"); enabled: root.pupilId >= 0 }
        }

        StackLayout {
            currentIndex: tabs.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true

            ScrollView {
                id: personalScroll
                contentWidth: availableWidth
                ColumnLayout {
                    width: personalScroll.availableWidth
                    spacing: 12

                    SectionCard {
                        title: qsTr("Contact")
                        Layout.fillWidth: true
                        Layout.margins: 12
                        GridLayout {
                            columns: root.width > 720 ? 2 : 1
                            Layout.fillWidth: true
                            LabeledField { id: forename; label: qsTr("First name") }
                            LabeledField { id: surname; label: qsTr("Last name") }
                            LabeledField { id: addressField; label: qsTr("Address") }
                            LabeledField { id: email; label: qsTr("E-mail") }
                            LabeledField { id: phone; label: qsTr("Phone") }
                            LabeledField { id: mobile; label: qsTr("Mobile") }
                            LabeledField { id: birthday; label: qsTr("Birthday (YYYY-MM-DD)") }
                            LabeledField { id: firstLesson; label: qsTr("First lesson (YYYY-MM-DD)") }
                        }
                    }

                    SectionCard {
                        title: qsTr("Personal event interval")
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        ComboBox {
                            id: recitalInterval
                            Layout.fillWidth: true
                            model: [qsTr("Never"), qsTr("1 month"), qsTr("2 months"), qsTr("3 months"), qsTr("4 months"), qsTr("6 months"), qsTr("9 months"), qsTr("12 months"), qsTr("18 months"), qsTr("24 months")]
                        }
                    }

                    SectionCard {
                        title: qsTr("Instrument")
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        GridLayout {
                            columns: root.width > 720 ? 2 : 1
                            Layout.fillWidth: true
                            LabeledField { id: instrument; label: qsTr("Instrument") }
                            LabeledField { id: instrumentSize; label: qsTr("Size") }
                            CheckBox { id: needsNextSize; text: qsTr("Next size needed"); Layout.columnSpan: root.width > 720 ? 2 : 1 }
                            CheckBox { id: ensembleExpected; text: qsTr("Participation in ensemble expected"); Layout.columnSpan: root.width > 720 ? 2 : 1 }
                        }

                        Label {
                            text: qsTr("Rental instrument")
                            font.pixelSize: 17
                            font.bold: true
                            Layout.fillWidth: true
                            Layout.topMargin: 10
                        }
                        CheckBox { id: rentalInstrument; text: qsTr("Pupil has a rental instrument") }
                        GridLayout {
                            columns: root.width > 720 ? 2 : 1
                            enabled: rentalInstrument.checked
                            Layout.fillWidth: true
                            LabeledField { id: rentalNumber; label: qsTr("Inventory number") }
                            LabeledField { id: rentalSince; label: qsTr("Rented since (YYYY-MM-DD)") }
                        }
                    }

                    SectionCard {
                        title: qsTr("Parents")
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        GridLayout {
                            columns: root.width > 720 ? 2 : 1
                            Layout.fillWidth: true
                            LabeledField { id: motherName; label: qsTr("Mother – name") }
                            LabeledField { id: fatherName; label: qsTr("Father – name") }
                            LabeledField { id: motherJob; label: qsTr("Mother – job") }
                            LabeledField { id: fatherJob; label: qsTr("Father – job") }
                            LabeledField { id: motherPhone; label: qsTr("Mother – phone") }
                            LabeledField { id: fatherPhone; label: qsTr("Father – phone") }
                        }
                    }

                    SectionCard {
                        title: qsTr("Notes")
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        ScrollView {
                            id: personalNotesEditor
                            Layout.fillWidth: true
                            Layout.preferredHeight: 130
                            clip: true
                            contentWidth: availableWidth
                            contentHeight: personalNotes.height
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            TextArea {
                                id: personalNotes
                                width: personalNotesEditor.availableWidth
                                height: Math.max(personalNotesEditor.availableHeight, contentHeight + topPadding + bottomPadding)
                                placeholderText: qsTr("Personal notes")
                                wrapMode: TextArea.Wrap
                                selectByMouse: true
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.margins: 12
                        Button { text: qsTr("Save"); action: root.saveAction }
                        Item { Layout.fillWidth: true }
                        Button { visible: root.pupilId >= 0; text: qsTr("Archive"); action: root.openArchiveAction }
                        Button { visible: root.pupilId >= 0; text: qsTr("Delete"); action: root.openDeleteAction }
                    }
                    Item { Layout.preferredHeight: 12 }
                }
            }

            ScrollView {
                id: notesScroll
                contentWidth: availableWidth
                ColumnLayout {
                    width: notesScroll.availableWidth
                    spacing: 10
                    SectionCard {
                        title: qsTr("Add lesson note")
                        Layout.fillWidth: true
                        Layout.margins: 12
                        ComboBox { id: noteMembership; Layout.fillWidth: true; model: root.memberships; textRole: "lessonName"; valueRole: "palId" }
                        LabeledField { id: noteDate; label: qsTr("Date (YYYY-MM-DD)"); text: Qt.formatDate(new Date(), "yyyy-MM-dd") }
                        ScrollView {
                            id: pupilLessonNoteEditor
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            clip: true
                            contentWidth: availableWidth
                            contentHeight: noteText.height
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            TextArea {
                                id: noteText
                                width: pupilLessonNoteEditor.availableWidth
                                height: Math.max(pupilLessonNoteEditor.availableHeight, contentHeight + topPadding + bottomPadding)
                                placeholderText: qsTr("Note")
                                wrapMode: TextArea.Wrap
                                selectByMouse: true
                            }
                        }
                        Button { text: qsTr("Add note"); enabled: root.canAddNote; action: root.addNoteAction }
                    }
                    Repeater {
                        model: root.notes
                        delegate: Pane {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            ColumnLayout {
                                anchors.fill: parent
                                RowLayout {
                                    Layout.fillWidth: true
                                    Button {
                                        property string noteContent: modelData.content || ""
                                        text: modelData.date + " · " + modelData.lessonName
                                        flat: true
                                        Layout.fillWidth: true
                                        action: root.useNoteAction
                                    }
                                    ToolButton {
                                        property int noteId: modelData.id
                                        text: "×"
                                        action: root.deleteNoteAction
                                    }
                                }
                                Button {
                                    property string noteContent: modelData.content || ""
                                    flat: true
                                    padding: 0
                                    Layout.fillWidth: true
                                    action: root.useNoteAction
                                    contentItem: Label {
                                        text: modelData.content
                                        textFormat: Text.RichText
                                        wrapMode: Text.Wrap
                                        color: root.paletteText
                                    }
                                }
                            }
                        }
                    }
                    Item { Layout.preferredHeight: 12 }
                }
            }

            ScrollView {
                id: piecesScroll
                contentWidth: availableWidth
                ColumnLayout {
                    width: piecesScroll.availableWidth
                    spacing: 10
                    SectionCard {
                        title: qsTr("Add music piece")
                        Layout.fillWidth: true
                        Layout.margins: 12
                        ComboBox { id: pieceMembership; Layout.fillWidth: true; model: root.memberships; textRole: "lessonName"; valueRole: "palId" }
                        GridLayout {
                            columns: root.width > 720 ? 2 : 1
                            Layout.fillWidth: true
                            LabeledField { id: composer; label: qsTr("Composer") }
                            LabeledField { id: pieceTitle; label: qsTr("Title") }
                            LabeledField { id: genre; label: qsTr("Genre") }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label { text: qsTr("Duration (minutes)"); font.bold: true; opacity: 0.8 }
                                SpinBox { id: duration; from: 0; to: 180; value: 5; editable: true; Layout.fillWidth: true }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label { text: qsTr("State"); font.bold: true; opacity: 0.8 }
                                ComboBox { id: pieceState; model: [qsTr("Planned"), qsTr("In progress"), qsTr("Paused"), qsTr("Ready for concert"), qsTr("Finished")]; Layout.fillWidth: true }
                            }
                        }
                        Button { text: qsTr("Add piece"); enabled: root.canAddPiece; action: root.addPieceAction }
                    }
                    Repeater {
                        model: root.pieces
                        delegate: ItemDelegate {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            contentItem: RowLayout {
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Label { text: modelData.composer + " — " + modelData.title; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Label {
                                        text: (modelData.lessonName || "") + ((modelData.lessonName || "") && (modelData.genre || "") ? " · " : "") + (modelData.genre || "") + (((modelData.lessonName || "") || (modelData.genre || "")) && (modelData.stateName || "") ? " · " : "") + (modelData.stateName || "")
                                        opacity: 0.65
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }
                                ToolButton { property int pieceId: modelData.id; text: "×"; action: root.deletePieceAction }
                            }
                        }
                    }
                }
            }

            ScrollView {
                id: activityScroll
                contentWidth: availableWidth
                ColumnLayout {
                    width: activityScroll.availableWidth
                    spacing: 10
                    SectionCard {
                        title: qsTr("Add activity")
                        Layout.fillWidth: true
                        Layout.margins: 12
                        LabeledField { id: activityDescription; label: qsTr("Description") }
                        CheckBox { id: activityContinuous; text: qsTr("Regular activity") }
                        GridLayout {
                            columns: root.width > 720 ? 2 : 1
                            Layout.fillWidth: true
                            LabeledField { id: activityDate; label: activityContinuous.checked ? qsTr("Start (YYYY-MM-DD)") : qsTr("Date (YYYY-MM-DD)"); text: Qt.formatDate(new Date(), "yyyy-MM-dd") }
                            LabeledField { id: activityTime; visible: activityContinuous.checked; label: qsTr("Time (HH:mm)") }
                            ColumnLayout {
                                visible: activityContinuous.checked
                                Layout.fillWidth: true
                                Label { text: qsTr("Weekday"); font.bold: true; opacity: 0.8 }
                                ComboBox { id: activityDay; Layout.fillWidth: true; model: [qsTr("Monday"),qsTr("Tuesday"),qsTr("Wednesday"),qsTr("Thursday"),qsTr("Friday"),qsTr("Saturday"),qsTr("Sunday"),qsTr("Irregular")] }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label { text: qsTr("Type"); font.bold: true; opacity: 0.8 }
                                ComboBox { id: activityType; Layout.fillWidth: true; model: activityContinuous.checked ? [qsTr("Ensemble"),qsTr("Theory lesson"),qsTr("Piano coaching"),qsTr("Other")] : [qsTr("Solo recital"),qsTr("Ensemble recital"),qsTr("Other")] }
                            }
                        }
                        Button { text: qsTr("Add activity"); enabled: root.canAddActivity; action: root.addActivityAction }
                    }
                    Repeater {
                        model: root.activities
                        delegate: ItemDelegate {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            contentItem: RowLayout {
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Label { text: modelData.description; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Label { text: modelData.typeName + " · " + modelData.date + (modelData.time ? " · " + modelData.time : ""); opacity: 0.65 }
                                }
                                ToolButton { property int activityId: modelData.id; text: "×"; action: root.deleteActivityAction }
                            }
                        }
                    }
                }
            }

            ScrollView {
                id: loanScroll
                contentWidth: availableWidth
                ColumnLayout {
                    width: loanScroll.availableWidth
                    spacing: 8
                    Label {
                        visible: root.loans.length === 0
                        text: qsTr("No music is currently loaned to this pupil.")
                        opacity: 0.65
                        Layout.margins: 18
                    }
                    Repeater {
                        model: root.loans
                        delegate: ItemDelegate {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            contentItem: RowLayout {
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Label { text: modelData.author + " — " + modelData.title; font.bold: true; Layout.fillWidth: true }
                                    Label { text: modelData.publisher + (modelData.rentDate ? " · " + modelData.rentDate : ""); opacity: 0.65 }
                                }
                                Button { property int musicId: modelData.id; text: qsTr("Return"); action: root.returnLoanAction }
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: deleteConfirm
        anchors.centerIn: parent
        modal: true
        title: qsTr("Delete pupil?")
        standardButtons: Dialog.Ok | Dialog.Cancel
        Label { text: qsTr("The pupil and linked lesson content will be deleted."); wrapMode: Text.WordWrap; width: Math.min(420, root.width - 64) }
    }

    Dialog {
        id: archiveConfirm
        anchors.centerIn: parent
        modal: true
        title: qsTr("Archive pupil?")
        standardButtons: Dialog.Ok | Dialog.Cancel
        Label { text: qsTr("A readable archive entry is created before the active pupil is removed."); wrapMode: Text.WordWrap; width: Math.min(420, root.width - 64) }
    }
}

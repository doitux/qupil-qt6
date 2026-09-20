// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

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
            forename.text = ""
            surname.text = ""
            firstLesson.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
            birthday.text = "2000-01-01"
            rentalSince.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
            return
        }
        const p = App.pupil(pupilId)
        forename.text = p.forename || ""
        surname.text = p.surname || ""
        address.text = p.address || ""
        email.text = p.email || ""
        phone.text = p.phone || ""
        mobile.text = p.mobile || ""
        birthday.text = p.birthday || ""
        personalNotes.text = p.notes || ""
        fatherName.text = p.fatherName || ""
        fatherJob.text = p.fatherJob || ""
        fatherPhone.text = p.fatherPhone || ""
        motherName.text = p.motherName || ""
        motherJob.text = p.motherJob || ""
        motherPhone.text = p.motherPhone || ""
        firstLesson.text = p.firstLessonDate || ""
        instrument.text = p.instrument || ""
        instrumentSize.text = p.instrumentSize || ""
        needsNextSize.checked = !!p.needsNextInstrumentSize
        rentalInstrument.checked = !!p.hasRentalInstrument
        rentalNumber.text = p.rentalInstrumentNumber || ""
        rentalSince.text = p.rentalInstrumentSince || ""
        recitalInterval.currentIndex = Math.max(0, Math.min(9, p.recitalInterval || 0))
        ensembleExpected.checked = !!p.ensembleActivityRequested
        reloadRelated()
    }

    function reloadRelated() {
        if (pupilId < 0) return
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
        tabs.currentIndex = 1
        noteText.text = App.noteTemplateText(content || "")
        Qt.callLater(function() {
            if (notesScroll.contentItem)
                notesScroll.contentItem.contentY = 0
            noteText.forceActiveFocus()
            noteText.cursorPosition = noteText.text.length
            root.keepEditorCursorVisible(pupilLessonNoteEditor, noteText)
        })
    }

    function save() {
        const id = App.savePupil({
            id: pupilId,
            forename: forename.text,
            surname: surname.text,
            address: address.text,
            email: email.text,
            phone: phone.text,
            mobile: mobile.text,
            birthday: birthday.text,
            notes: personalNotes.text,
            fatherName: fatherName.text,
            fatherJob: fatherJob.text,
            fatherPhone: fatherPhone.text,
            motherName: motherName.text,
            motherJob: motherJob.text,
            motherPhone: motherPhone.text,
            firstLessonDate: firstLesson.text,
            instrument: instrument.text,
            instrumentSize: instrumentSize.text,
            needsNextInstrumentSize: needsNextSize.checked,
            hasRentalInstrument: rentalInstrument.checked,
            rentalInstrumentNumber: rentalNumber.text,
            rentalInstrumentSince: rentalSince.text,
            recitalInterval: recitalInterval.currentIndex,
            ensembleActivityRequested: ensembleExpected.checked
        })
        if (id >= 0) {
            pupilId = id
            reloadRelated()
            savedNotice.open()
        }
    }

    Component.onCompleted: load()
    Connections { target: App; function onDataChanged() { root.reloadRelated() } }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            Button { text: "‹ " + qsTr("Back"); onClicked: root.done() }
            Label {
                text: pupilId < 0 ? qsTr("New pupil") : (forename.text + " " + surname.text).trim()
                font.bold: true
                font.pixelSize: 20
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Button { text: qsTr("Save"); onClicked: root.save() }
        }

        TabBar {
            id: tabs
            Layout.fillWidth: true
            currentIndex: 0
            TabButton { text: qsTr("Personal") }
            TabButton { text: qsTr("Notes"); enabled: pupilId >= 0 }
            TabButton { text: qsTr("Pieces"); enabled: pupilId >= 0 }
            TabButton { text: qsTr("Activities"); enabled: pupilId >= 0 }
            TabButton { text: qsTr("Loaned music"); enabled: pupilId >= 0 }
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
                            LabeledField { id: address; label: qsTr("Address") }
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
                        Layout.leftMargin: 12; Layout.rightMargin: 12
                        ComboBox {
                            id: recitalInterval
                            Layout.fillWidth: true
                            model: [qsTr("Never"), qsTr("1 month"), qsTr("2 months"), qsTr("3 months"), qsTr("4 months"), qsTr("6 months"), qsTr("9 months"), qsTr("12 months"), qsTr("18 months"), qsTr("24 months")]
                        }
                    }

                    SectionCard {
                        title: qsTr("Instrument")
                        Layout.fillWidth: true
                        Layout.leftMargin: 12; Layout.rightMargin: 12
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
                        Layout.leftMargin: 12; Layout.rightMargin: 12
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
                        Layout.leftMargin: 12; Layout.rightMargin: 12
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
                                height: Math.max(personalNotesEditor.availableHeight,
                                                 contentHeight + topPadding + bottomPadding)
                                placeholderText: qsTr("Personal notes")
                                wrapMode: TextArea.Wrap
                                selectByMouse: true
                                onCursorRectangleChanged: root.keepEditorCursorVisible(personalNotesEditor, personalNotes)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.margins: 12
                        Button { text: qsTr("Save"); onClicked: root.save() }
                        Item { Layout.fillWidth: true }
                        Button { visible: pupilId >= 0; text: qsTr("Archive"); onClicked: archiveConfirm.open() }
                        Button { visible: pupilId >= 0; text: qsTr("Delete"); onClicked: deleteConfirm.open() }
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
                        Layout.fillWidth: true; Layout.margins: 12
                        ComboBox {
                            id: noteMembership
                            Layout.fillWidth: true
                            model: root.memberships
                            textRole: "lessonName"
                            valueRole: "palId"
                        }
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
                                height: Math.max(pupilLessonNoteEditor.availableHeight,
                                                 contentHeight + topPadding + bottomPadding)
                                placeholderText: qsTr("Note")
                                wrapMode: TextArea.Wrap
                                selectByMouse: true
                                onCursorRectangleChanged: root.keepEditorCursorVisible(pupilLessonNoteEditor, noteText)
                            }
                        }
                        Button {
                            text: qsTr("Add note")
                            enabled: root.memberships.length > 0 && noteText.text.trim().length > 0
                            onClicked: {
                                if (App.addNote(noteMembership.currentValue, noteDate.text, noteText.text) >= 0) {
                                    noteText.clear(); root.notes = App.notesForPupil(root.pupilId)
                                }
                            }
                        }
                    }
                    Repeater {
                        model: root.notes
                        delegate: Pane {
                            required property var modelData
                            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                            ColumnLayout {
                                anchors.fill: parent
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        text: modelData.date + " · " + modelData.lessonName
                                        font.bold: true
                                        Layout.fillWidth: true
                                        TapHandler { onTapped: root.useNoteAsTemplate(modelData.content) }
                                    }
                                    ToolButton { text: "×"; onClicked: { App.deleteNote(modelData.id); root.notes = App.notesForPupil(root.pupilId) } }
                                }
                                Label {
                                    text: modelData.content
                                    textFormat: Text.RichText
                                    wrapMode: Text.Wrap
                                    color: root.palette.text
                                    Layout.fillWidth: true
                                    TapHandler { onTapped: root.useNoteAsTemplate(modelData.content) }
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
                        Layout.fillWidth: true; Layout.margins: 12
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
                        Button {
                            text: qsTr("Add piece")
                            enabled: root.memberships.length > 0 && composer.text.trim().length > 0 && pieceTitle.text.trim().length > 0
                            onClicked: {
                                if (App.addPiece(pieceMembership.currentValue, composer.text, pieceTitle.text, genre.text, duration.value, pieceState.currentIndex) >= 0) {
                                    pieceTitle.clear(); root.pieces = App.piecesForPupil(root.pupilId)
                                }
                            }
                        }
                    }
                    Repeater {
                        model: root.pieces
                        delegate: ItemDelegate {
                            required property var modelData
                            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                            contentItem: RowLayout {
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Label { text: modelData.composer + " — " + modelData.title; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Label { text: [modelData.lessonName, modelData.genre, modelData.stateName].filter(x => x && x.length).join(" · "); opacity: 0.65; Layout.fillWidth: true; elide: Text.ElideRight }
                                }
                                ToolButton { text: "×"; onClicked: { App.deletePiece(modelData.id); root.pieces = App.piecesForPupil(root.pupilId) } }
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
                        Layout.fillWidth: true; Layout.margins: 12
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
                        Button {
                            text: qsTr("Add activity")
                            enabled: activityDescription.text.trim().length > 0
                            onClicked: {
                                if (App.addActivity(root.pupilId, activityContinuous.checked, { description: activityDescription.text, date: activityDate.text, time: activityTime.text, day: activityDay.currentIndex, type: activityType.currentIndex }) >= 0) {
                                    activityDescription.clear(); root.activities = App.activitiesForPupil(root.pupilId)
                                }
                            }
                        }
                    }
                    Repeater {
                        model: root.activities
                        delegate: ItemDelegate {
                            required property var modelData
                            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                            contentItem: RowLayout {
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Label { text: modelData.description; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Label { text: modelData.typeName + " · " + modelData.date + (modelData.time ? " · " + modelData.time : ""); opacity: 0.65 }
                                }
                                ToolButton { text: "×"; onClicked: { App.deleteActivity(modelData.id); root.activities = App.activitiesForPupil(root.pupilId) } }
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
                            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                            contentItem: RowLayout {
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Label { text: modelData.author + " — " + modelData.title; font.bold: true; Layout.fillWidth: true }
                                    Label { text: modelData.publisher + (modelData.rentDate ? " · " + modelData.rentDate : ""); opacity: 0.65 }
                                }
                                Button { text: qsTr("Return"); onClicked: { App.returnSheetMusic(modelData.id); root.loans = App.loanedMusicForPupil(root.pupilId) } }
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
        onAccepted: if (App.deletePupil(root.pupilId)) root.done()
    }

    Dialog {
        id: archiveConfirm
        anchors.centerIn: parent
        modal: true
        title: qsTr("Archive pupil?")
        standardButtons: Dialog.Ok | Dialog.Cancel
        Label { text: qsTr("A readable archive entry is created before the active pupil is removed."); wrapMode: Text.WordWrap; width: Math.min(420, root.width - 64) }
        onAccepted: if (App.archivePupil(root.pupilId)) root.done()
    }

    Popup {
        id: savedNotice
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Label { text: qsTr("Saved") }
    }
}

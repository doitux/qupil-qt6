// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

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

    function reload() {
        rows = App.scheduleForDay(days.currentIndex)
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
        workTabs.currentIndex = 0
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
        noteText.text = App.noteTemplateText(content || "")
        workTabs.currentIndex = 0
        Qt.callLater(function() {
            if (workNotesScroll.contentItem)
                workNotesScroll.contentItem.contentY = 0
            noteText.forceActiveFocus()
            noteText.cursorPosition = noteText.text.length
            root.keepEditorCursorVisible(scheduleNoteEditor, noteText)
        })
    }

    Component.onCompleted: {
        days.currentIndex = Math.max(0, Math.min(6, new Date().getDay() === 0 ? 6 : new Date().getDay() - 1))
        reload()
    }

    Connections {
        target: App
        function onDataChanged() {
            root.reload()
            root.reloadWork()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            contentHeight: 52
            contentWidth: days.implicitWidth
            ScrollBar.horizontal.policy: ScrollBar.AsNeeded
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            clip: true

            TabBar {
                id: days
                height: 52
                onCurrentIndexChanged: root.reload()
                Repeater {
                    model: [qsTr("Mon"), qsTr("Tue"), qsTr("Wed"), qsTr("Thu"), qsTr("Fri"), qsTr("Sat"), qsTr("Sun")]
                    TabButton {
                        required property var modelData
                        text: modelData
                        width: 72
                        height: 48
                        font.pixelSize: 16
                        leftPadding: 12
                        rightPadding: 12
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Pane {
                id: schedulePane
                visible: !root.compactWorkView || root.selectedPalId < 0
                Layout.fillHeight: true
                Layout.fillWidth: root.compactWorkView
                Layout.preferredWidth: root.compactWorkView ? -1 : Math.max(360, Math.min(470, root.width * 0.42))
                padding: 0

                ListView {
                    id: schedule
                    anchors.fill: parent
                    model: root.rows
                    spacing: 8
                    clip: true

                    delegate: Pane {
                        id: lessonCard
                        required property var modelData
                        width: schedule.width
                        padding: 0

                        background: Rectangle {
                            radius: 7
                            color: root.palette.base
                            border.color: root.palette.mid
                        }

                        contentItem: ColumnLayout {
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.margins: 8
                                spacing: 8

                                ColumnLayout {
                                    Layout.preferredWidth: 92
                                    spacing: 0
                                    Label { text: lessonCard.modelData.start || "—"; font.pixelSize: 18; font.bold: true }
                                    Label { text: lessonCard.modelData.stop || ""; opacity: 0.6 }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label {
                                        text: lessonCard.modelData.name
                                        font.bold: true
                                        font.pixelSize: 16
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        text: [lessonCard.modelData.typeName, lessonCard.modelData.location].filter(x => x && x.length).join(" · ")
                                        opacity: 0.62
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                ToolButton {
                                    text: "⚙"
                                    font.pixelSize: 18
                                    Accessible.name: qsTr("Lesson details")
                                    onClicked: root.editLesson(Number(lessonCard.modelData.id))
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: root.palette.mid
                                opacity: 0.55
                            }

                            Label {
                                visible: !lessonCard.modelData.memberships || lessonCard.modelData.memberships.length === 0
                                text: qsTr("No pupils")
                                opacity: 0.6
                                Layout.margins: 10
                            }

                            Repeater {
                                model: lessonCard.modelData.memberships || []
                                delegate: ItemDelegate {
                                    id: pupilRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    leftPadding: 10
                                    rightPadding: 10
                                    topPadding: 4
                                    bottomPadding: 4

                                    property bool active: Number(modelData.palId) === root.selectedPalId

                                    background: Rectangle {
                                        radius: 5
                                        color: pupilRow.active ? root.palette.highlight : (pupilRow.hovered ? root.palette.midlight : "transparent")
                                        opacity: pupilRow.active ? 0.82 : (pupilRow.hovered ? 0.3 : 1.0)
                                    }

                                    contentItem: RowLayout {
                                        spacing: 9
                                        Label {
                                            text: "♙"
                                            Layout.preferredWidth: 24
                                            horizontalAlignment: Text.AlignHCenter
                                            color: pupilRow.active ? root.palette.highlightedText : root.palette.text
                                        }
                                        Label {
                                            text: pupilRow.modelData.pupilName
                                            Layout.fillWidth: true
                                            font.pixelSize: 16
                                            color: pupilRow.active ? root.palette.highlightedText : root.palette.text
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            text: "›"
                                            font.pixelSize: 22
                                            color: pupilRow.active ? root.palette.highlightedText : root.palette.text
                                            opacity: 0.7
                                        }
                                    }

                                    onClicked: root.selectMembership(modelData, lessonCard.modelData.id)
                                }
                            }
                        }
                    }

                    EmptyState {
                        anchors.centerIn: parent
                        visible: schedule.count === 0
                        title: qsTr("No lessons on this day")
                    }
                }
            }

            Rectangle {
                visible: !root.compactWorkView
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: root.palette.mid
            }

            Pane {
                id: workPane
                visible: !root.compactWorkView || root.selectedPalId >= 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 0

                StackLayout {
                    anchors.fill: parent
                    currentIndex: root.selectedPalId >= 0 ? 1 : 0

                    Item {
                        EmptyState {
                            anchors.centerIn: parent
                            title: qsTr("Select a pupil from the schedule")
                        }
                    }

                    ColumnLayout {
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            Layout.rightMargin: 8

                            Button {
                                visible: root.compactWorkView
                                text: "‹ " + qsTr("Back")
                                onClicked: root.closeWork()
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label {
                                    text: root.workContext.pupilName || ""
                                    font.pixelSize: 22
                                    font.bold: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Label {
                                    text: [root.workContext.lessonName,
                                           [root.workContext.start, root.workContext.stop].filter(x => x && x.length).join("–"),
                                           root.workContext.location].filter(x => x && x.length).join(" · ")
                                    opacity: 0.65
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            Button {
                                text: qsTr("Pupil")
                                onClicked: root.editPupil(root.selectedPupilId)
                            }
                            Button {
                                text: qsTr("Lesson details")
                                onClicked: root.editLesson(root.selectedLessonId)
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.leftMargin: 10
                            Layout.rightMargin: 10
                            text: App.settingValue("saveNotesPiecesForAllPupils", true)
                                  ? qsTr("Saved for all active pupils in this lesson")
                                  : qsTr("Saved only for this pupil")
                            opacity: 0.68
                            wrapMode: Text.WordWrap
                        }

                        TabBar {
                            id: workTabs
                            Layout.fillWidth: true
                            TabButton { text: qsTr("Notes") }
                            TabButton { text: qsTr("Pieces") }
                        }

                        StackLayout {
                            currentIndex: workTabs.currentIndex
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ScrollView {
                                id: workNotesScroll
                                contentWidth: availableWidth

                                ColumnLayout {
                                    width: workNotesScroll.availableWidth
                                    spacing: 10

                                    SectionCard {
                                        title: qsTr("Add lesson note")
                                        Layout.fillWidth: true
                                        Layout.margins: 8
                                        LabeledField {
                                            id: noteDate
                                            label: qsTr("Date (YYYY-MM-DD)")
                                            text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                                        }
                                        ScrollView {
                                            id: scheduleNoteEditor
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 120
                                            clip: true
                                            contentWidth: availableWidth
                                            contentHeight: noteText.height
                                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                            TextArea {
                                                id: noteText
                                                width: scheduleNoteEditor.availableWidth
                                                height: Math.max(scheduleNoteEditor.availableHeight,
                                                                 contentHeight + topPadding + bottomPadding)
                                                placeholderText: qsTr("Note")
                                                wrapMode: TextArea.Wrap
                                                selectByMouse: true
                                                onCursorRectangleChanged: root.keepEditorCursorVisible(scheduleNoteEditor, noteText)
                                            }
                                        }
                                        Button {
                                            text: qsTr("Add note")
                                            enabled: root.selectedPalId >= 0 && noteText.text.trim().length > 0
                                            onClicked: {
                                                if (App.addNote(root.selectedPalId, noteDate.text, noteText.text) >= 0)
                                                    noteText.clear()
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: root.workNotes
                                        delegate: Pane {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 8
                                            Layout.rightMargin: 8
                                            ColumnLayout {
                                                anchors.fill: parent
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Label {
                                                        text: modelData.date
                                                        font.bold: true
                                                        Layout.fillWidth: true
                                                        TapHandler { onTapped: root.useNoteAsTemplate(modelData.content) }
                                                    }
                                                    ToolButton { text: "×"; onClicked: App.deleteNote(modelData.id) }
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
                                    Item { Layout.preferredHeight: 8 }
                                }
                            }

                            ScrollView {
                                id: workPiecesScroll
                                contentWidth: availableWidth

                                ColumnLayout {
                                    width: workPiecesScroll.availableWidth
                                    spacing: 10

                                    SectionCard {
                                        title: qsTr("Add music piece")
                                        Layout.fillWidth: true
                                        Layout.margins: 8
                                        GridLayout {
                                            columns: root.width > 980 ? 2 : 1
                                            Layout.fillWidth: true
                                            LabeledField { id: workComposer; label: qsTr("Composer") }
                                            LabeledField { id: workPieceTitle; label: qsTr("Title") }
                                            LabeledField { id: workGenre; label: qsTr("Genre") }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Label { text: qsTr("Duration (minutes)"); font.bold: true; opacity: 0.8 }
                                                SpinBox { id: workDuration; from: 0; to: 180; value: 5; editable: true; Layout.fillWidth: true }
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Label { text: qsTr("State"); font.bold: true; opacity: 0.8 }
                                                ComboBox {
                                                    id: workPieceState
                                                    model: [qsTr("Planned"), qsTr("In progress"), qsTr("Paused"), qsTr("Ready for concert"), qsTr("Finished")]
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                        Button {
                                            text: qsTr("Add piece")
                                            enabled: root.selectedPalId >= 0 && workComposer.text.trim().length > 0 && workPieceTitle.text.trim().length > 0
                                            onClicked: {
                                                if (App.addPiece(root.selectedPalId, workComposer.text, workPieceTitle.text,
                                                                 workGenre.text, workDuration.value, workPieceState.currentIndex) >= 0)
                                                    workPieceTitle.clear()
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: root.workPieces
                                        delegate: ItemDelegate {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 8
                                            Layout.rightMargin: 8
                                            contentItem: RowLayout {
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Label {
                                                        text: modelData.composer + " — " + modelData.title
                                                        font.bold: true
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }
                                                    Label {
                                                        text: [modelData.genre, modelData.stateName].filter(x => x && x.length).join(" · ")
                                                        opacity: 0.65
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                                ToolButton { text: "×"; onClicked: App.deletePiece(modelData.id) }
                                            }
                                        }
                                    }
                                    Item { Layout.preferredHeight: 8 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

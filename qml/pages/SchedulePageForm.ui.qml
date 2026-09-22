// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    width: 1100
    height: 760

    property var rows: []
    property int selectedPalId: -1
    property var workContext: ({})
    property var workNotes: []
    property var workPieces: []
    property bool compactWorkView: false
    property bool shareLessonContent: true
    property bool canAddNote: false
    property bool canAddPiece: false

    property color paletteBase: "white"
    property color paletteMid: "#808080"
    property color paletteMidlight: "#b0b0b0"
    property color paletteHighlight: "#3584e4"
    property color paletteHighlightedText: "white"
    property color paletteText: "black"

    property var editLessonAction: null
    property var selectMembershipAction: null
    property var closeWorkAction: null
    property var editPupilAction: null
    property var editSelectedLessonAction: null
    property var addNoteAction: null
    property var useNoteAction: null
    property var deleteNoteAction: null
    property var addPieceAction: null
    property var deletePieceAction: null

    property alias days: days
    property alias workTabs: workTabs
    property alias workNotesScroll: workNotesScroll
    property alias scheduleNoteEditor: scheduleNoteEditor
    property alias noteText: noteText
    property alias noteDate: noteDate
    property alias workComposer: workComposer
    property alias workPieceTitle: workPieceTitle
    property alias workGenre: workGenre
    property alias workDuration: workDuration
    property alias workPieceState: workPieceState

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
                            color: root.paletteBase
                            border.color: root.paletteMid
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
                                        text: (lessonCard.modelData.typeName || "")
                                              + ((lessonCard.modelData.typeName || "") && (lessonCard.modelData.location || "") ? " · " : "")
                                              + (lessonCard.modelData.location || "")
                                        opacity: 0.62
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                ToolButton {
                                    property int recordId: lessonCard.modelData.id
                                    text: "⚙"
                                    font.pixelSize: 18
                                    Accessible.name: qsTr("Lesson details")
                                    action: root.editLessonAction
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: root.paletteMid
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
                                    property var membershipData: modelData
                                    property int lessonId: lessonCard.modelData.id
                                    property bool active: modelData.palId === root.selectedPalId

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    leftPadding: 10
                                    rightPadding: 10
                                    topPadding: 4
                                    bottomPadding: 4
                                    action: root.selectMembershipAction

                                    background: Rectangle {
                                        radius: 5
                                        color: pupilRow.active ? root.paletteHighlight : (pupilRow.hovered ? root.paletteMidlight : "transparent")
                                        opacity: pupilRow.active ? 0.82 : (pupilRow.hovered ? 0.3 : 1.0)
                                    }

                                    contentItem: RowLayout {
                                        spacing: 9
                                        Label {
                                            text: "♙"
                                            Layout.preferredWidth: 24
                                            horizontalAlignment: Text.AlignHCenter
                                            color: pupilRow.active ? root.paletteHighlightedText : root.paletteText
                                        }
                                        Label {
                                            text: pupilRow.modelData.pupilName
                                            Layout.fillWidth: true
                                            font.pixelSize: 16
                                            color: pupilRow.active ? root.paletteHighlightedText : root.paletteText
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            text: "›"
                                            font.pixelSize: 22
                                            color: pupilRow.active ? root.paletteHighlightedText : root.paletteText
                                            opacity: 0.7
                                        }
                                    }
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
                color: root.paletteMid
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
                                action: root.closeWorkAction
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
                                    text: (root.workContext.lessonName || "")
                                          + ((root.workContext.lessonName || "") && ((root.workContext.start || "") || (root.workContext.stop || "")) ? " · " : "")
                                          + (root.workContext.start || "")
                                          + ((root.workContext.start || "") && (root.workContext.stop || "") ? "–" : "")
                                          + (root.workContext.stop || "")
                                          + (((root.workContext.lessonName || "") || (root.workContext.start || "") || (root.workContext.stop || "")) && (root.workContext.location || "") ? " · " : "")
                                          + (root.workContext.location || "")
                                    opacity: 0.65
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            Button { text: qsTr("Pupil"); action: root.editPupilAction }
                            Button { text: qsTr("Lesson details"); action: root.editSelectedLessonAction }
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.leftMargin: 10
                            Layout.rightMargin: 10
                            text: root.shareLessonContent
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
                                            }
                                        }
                                        Button {
                                            text: qsTr("Add note")
                                            enabled: root.canAddNote
                                            action: root.addNoteAction
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
                                                    Button {
                                                        property string noteContent: modelData.content || ""
                                                        text: modelData.date
                                                        flat: true
                                                        font.bold: true
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
                                                    id: noteContentButton
                                                    property string noteContent: modelData.content || ""
                                                    flat: true
                                                    Layout.fillWidth: true
                                                    action: root.useNoteAction
                                                    contentItem: Label {
                                                        text: noteContentButton.noteContent
                                                        textFormat: Text.RichText
                                                        wrapMode: Text.Wrap
                                                        color: root.paletteText
                                                    }
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
                                            enabled: root.canAddPiece
                                            action: root.addPieceAction
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
                                                        text: (modelData.composer || "") + " — " + (modelData.title || "")
                                                        font.bold: true
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }
                                                    Label {
                                                        text: (modelData.genre || "")
                                                              + ((modelData.genre || "") && (modelData.stateName || "") ? " · " : "")
                                                              + (modelData.stateName || "")
                                                        opacity: 0.65
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                                ToolButton {
                                                    property int pieceId: modelData.id
                                                    text: "×"
                                                    action: root.deletePieceAction
                                                }
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

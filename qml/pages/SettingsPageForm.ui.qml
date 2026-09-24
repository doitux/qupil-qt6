// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    width: 1100
    height: 760

    property string databasePath: ""
    property bool importedLegacyDatabase: false
    property int languageIndex: 0
    property bool androidExactAlarmGranted: true
    property string nativeReminderDiagnostics: ""

    property var backupAction: null
    property var restoreAction: null
    property var csvImportAction: null
    property var saveAction: null
    property var chooseLessonEndSoundAction: null
    property var defaultLessonEndSoundAction: null
    property var testLessonEndSoundAction: null
    property var chooseReminderSoundAction: null
    property var defaultReminderSoundAction: null
    property var testReminderSoundAction: null
    property var exactAlarmAction: null
    property var iosBackgroundTestAction: null
    property var iosDiagnosticsRefreshAction: null

    property alias languageCombo: languageCombo
    property alias birthdayReminder: birthdayReminder
    property alias lessonEndReminder: lessonEndReminder
    property alias lessonEndMinutes: lessonEndMinutes
    property alias lessonEndSoundPath: lessonEndSoundPath
    property alias lessonEndVolume: lessonEndVolume
    property alias reminderSoundPath: reminderSoundPath
    property alias reminderVolume: reminderVolume
    property alias shareLessonContent: shareLessonContent
    property alias locations: locations
    property alias genres: genres
    property alias instruments: instruments
    property alias sizes: sizes
    property alias restoreConfirm: restoreConfirm

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 12

            SectionCard {
                title: qsTr("Language")
                Layout.fillWidth: true
                Layout.margins: 12
                Label { text: qsTr("Interface language"); opacity: 0.8 }
                ComboBox {
                    id: languageCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(44, implicitHeight)
                    model: [qsTr("System language"), qsTr("English"), qsTr("German")]
                    currentIndex: root.languageIndex
                }
            }

            SectionCard {
                title: qsTr("Application")
                Layout.fillWidth: true
                Layout.margins: 12
                CheckBox { id: birthdayReminder; text: qsTr("Birthday reminder") }
                RowLayout {
                    Layout.fillWidth: true
                    CheckBox { id: lessonEndReminder; text: qsTr("Lesson end reminder") }
                    Label { text: qsTr("Minutes before end"); enabled: lessonEndReminder.checked }
                    SpinBox { id: lessonEndMinutes; from: 1; to: 30; editable: true; enabled: lessonEndReminder.checked }
                    Item { Layout.fillWidth: true }
                }

                Label { text: qsTr("Lesson end sound"); font.bold: true; Layout.topMargin: 4 }
                TextField { id: lessonEndSoundPath; readOnly: true; Layout.fillWidth: true }
                RowLayout {
                    Layout.fillWidth: true
                    Button { text: qsTr("Choose…"); action: root.chooseLessonEndSoundAction }
                    Button { text: qsTr("Default"); action: root.defaultLessonEndSoundAction }
                    Button { text: qsTr("Test"); action: root.testLessonEndSoundAction }
                    Item { Layout.fillWidth: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr("Volume") }
                    Slider { id: lessonEndVolume; from: 0; to: 10; stepSize: 1; Layout.fillWidth: true }
                    Label { text: Math.round(lessonEndVolume.value).toString(); Layout.preferredWidth: 24; horizontalAlignment: Text.AlignRight }
                }

                Label { text: qsTr("Sound for reminders"); font.bold: true; Layout.topMargin: 4 }
                TextField { id: reminderSoundPath; readOnly: true; Layout.fillWidth: true }
                RowLayout {
                    Layout.fillWidth: true
                    Button { text: qsTr("Choose…"); action: root.chooseReminderSoundAction }
                    Button { text: qsTr("Default"); action: root.defaultReminderSoundAction }
                    Button { text: qsTr("Test"); action: root.testReminderSoundAction }
                    Item { Layout.fillWidth: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr("Volume") }
                    Slider { id: reminderVolume; from: 0; to: 10; stepSize: 1; Layout.fillWidth: true }
                    Label { text: Math.round(reminderVolume.value).toString(); Layout.preferredWidth: 24; horizontalAlignment: Text.AlignRight }
                }

                Label {
                    visible: Qt.platform.os === "ios"
                    text: qsTr("On iOS/iPadOS, background notification sounds use the system notification volume. Custom background sounds must be WAV, AIFF or CAF and shorter than 30 seconds.")
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                    Layout.fillWidth: true
                }
                ColumnLayout {
                    visible: Qt.platform.os === "ios"
                    Layout.fillWidth: true
                    spacing: 6
                    Label {
                        text: qsTr("iOS background notification test")
                        font.bold: true
                    }
                    Label {
                        text: qsTr("Schedules a real iOS local notification 15 seconds in the future. Start the test, put Qupil in the background immediately, and wait.")
                        wrapMode: Text.WordWrap
                        opacity: 0.75
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Button { text: qsTr("Test in 15 seconds"); action: root.iosBackgroundTestAction }
                        Button { text: qsTr("Refresh status"); action: root.iosDiagnosticsRefreshAction }
                        Item { Layout.fillWidth: true }
                    }
                    Label {
                        text: root.nativeReminderDiagnostics
                        font.family: "monospace"
                        wrapMode: Text.WrapAnywhere
                        opacity: 0.8
                        Layout.fillWidth: true
                    }
                }
                RowLayout {
                    visible: Qt.platform.os === "android" && !root.androidExactAlarmGranted
                    Layout.fillWidth: true
                    Label {
                        text: qsTr("Android needs the 'Alarms & reminders' permission for exact background timing.")
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Button { text: qsTr("Allow exact alarms"); action: root.exactAlarmAction }
                }

                CheckBox {
                    id: shareLessonContent
                    text: qsTr("Share notes and pieces with all active pupils in the selected lesson")
                    Layout.fillWidth: true
                }
                Label { text: qsTr("Database"); font.bold: true }
                Label { text: root.databasePath; wrapMode: Text.WrapAnywhere; opacity: 0.65; Layout.fillWidth: true }
                Label {
                    visible: root.importedLegacyDatabase
                    text: qsTr("A legacy desktop database was copied into the new application data directory on first start. The original was left unchanged.")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                RowLayout {
                    Button { text: qsTr("Create backup…"); action: root.backupAction }
                    Button { text: qsTr("Restore backup…"); action: root.restoreAction }
                }
                Button { text: qsTr("Import pupils from CSV…"); action: root.csvImportAction }
            }

            GridLayout {
                columns: root.width > 760 ? 2 : 1
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12

                SectionCard {
                    title: qsTr("Lesson locations")
                    Layout.fillWidth: true
                    TextArea { id: locations; Layout.fillWidth: true; Layout.preferredHeight: 180; wrapMode: TextArea.Wrap }
                }
                SectionCard {
                    title: qsTr("Music styles")
                    Layout.fillWidth: true
                    TextArea { id: genres; Layout.fillWidth: true; Layout.preferredHeight: 180; wrapMode: TextArea.Wrap }
                }
                SectionCard {
                    title: qsTr("Instruments")
                    Layout.fillWidth: true
                    TextArea { id: instruments; Layout.fillWidth: true; Layout.preferredHeight: 220; wrapMode: TextArea.Wrap }
                }
                SectionCard {
                    title: qsTr("Instrument sizes")
                    Layout.fillWidth: true
                    TextArea { id: sizes; Layout.fillWidth: true; Layout.preferredHeight: 220; wrapMode: TextArea.Wrap }
                }
            }

            Button { text: qsTr("Save settings"); Layout.margins: 12; action: root.saveAction }
            Item { Layout.preferredHeight: 12 }
        }
    }

    Dialog {
        id: restoreConfirm
        title: qsTr("Restore backup")
        modal: true
        width: Math.max(280, Math.min(root.width - 32, 520))
        standardButtons: Dialog.Ok | Dialog.Cancel
        contentItem: Label {
            width: Math.max(0, restoreConfirm.availableWidth)
            text: qsTr("Restoring replaces the current data. Qupil creates a local safety copy before the replacement. Continue?")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
        }
    }
}

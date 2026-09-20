// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qupil
import "../components"

Page {
    id: root
    signal openCsvImport()

    function load() {
        locations.text = App.settingList("lessonLocations").join("\n")
        genres.text = App.settingList("genres").join("\n")
        instruments.text = App.settingList("instruments").join("\n")
        sizes.text = App.settingList("instrumentSizes").join("\n")
        birthdayReminder.checked = App.settingValue("birthdayReminder", true)
        lessonEndReminder.checked = App.settingValue("lessonEndReminder", true)
        lessonEndMinutes.value = App.settingValue("minutesToLessonEndReminder", 3)
        shareLessonContent.checked = App.settingValue("saveNotesPiecesForAllPupils", true)
    }

    function cleanedLines(text) {
        return text.split(/\r?\n/).map(x => x.trim()).filter(x => x.length)
    }

    function save() {
        App.setSettingList("lessonLocations", cleanedLines(locations.text))
        App.setSettingList("genres", cleanedLines(genres.text))
        App.setSettingList("instruments", cleanedLines(instruments.text))
        App.setSettingList("instrumentSizes", cleanedLines(sizes.text))
        App.setSettingValue("birthdayReminder", birthdayReminder.checked)
        App.setSettingValue("lessonEndReminder", lessonEndReminder.checked)
        App.setSettingValue("minutesToLessonEndReminder", lessonEndMinutes.value)
        App.setSettingValue("saveNotesPiecesForAllPupils", shareLessonContent.checked)
        saved.open()
    }

    Component.onCompleted: load()
    Connections { target: Language; function onEffectiveLanguageChanged() { root.load() } }

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
                    id: languageComboV13
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(44, implicitHeight)
                    model: [qsTr("System language"), qsTr("English"), qsTr("German")]
                    currentIndex: Language.mode === "de" ? 2 : Language.mode === "en" ? 1 : 0
                    onActivated: {
                        const modes = ["system", "en", "de"]
                        Language.setMode(modes[currentIndex])
                    }
                }
            }

            SectionCard {
                title: qsTr("Application")
                Layout.fillWidth: true; Layout.margins: 12
                CheckBox { id: birthdayReminder; text: qsTr("Birthday reminder") }
                RowLayout {
                    Layout.fillWidth: true
                    CheckBox { id: lessonEndReminder; text: qsTr("Lesson end reminder") }
                    Label { text: qsTr("Minutes before end"); enabled: lessonEndReminder.checked }
                    SpinBox { id: lessonEndMinutes; from: 1; to: 30; editable: true; enabled: lessonEndReminder.checked }
                    Item { Layout.fillWidth: true }
                }
                CheckBox {
                    id: shareLessonContent
                    text: qsTr("Share notes and pieces with all active pupils in the selected lesson")
                    Layout.fillWidth: true
                }
                Label { text: qsTr("Database"); font.bold: true }
                Label { text: App.databasePath; wrapMode: Text.WrapAnywhere; opacity: 0.65; Layout.fillWidth: true }
                Label {
                    visible: App.importedLegacyDatabase
                    text: qsTr("A legacy desktop database was copied into the new application data directory on first start. The original was left unchanged.")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                RowLayout {
                    Button { text: qsTr("Create backup…"); onClicked: backupDialog.open() }
                    Button { text: qsTr("Restore backup…"); onClicked: restoreConfirm.open() }
                }
                Button { text: qsTr("Import pupils from CSV…"); onClicked: root.openCsvImport() }
            }

            GridLayout {
                columns: root.width > 760 ? 2 : 1
                Layout.fillWidth: true
                Layout.leftMargin: 12; Layout.rightMargin: 12

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

            Button { text: qsTr("Save settings"); Layout.margins: 12; onClicked: root.save() }
            Item { Layout.preferredHeight: 12 }
        }
    }

    FileDialog {
        id: backupDialog
        title: qsTr("Create Qupil backup")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "db"
        nameFilters: [qsTr("Qupil backup (*.db)")]
        onAccepted: if (App.exportBackup(selectedFile)) backupSaved.open()
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
        onAccepted: restoreDialog.open()
    }

    FileDialog {
        id: restoreDialog
        title: qsTr("Open Qupil backup")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("Qupil backup (*.db)")]
        onAccepted: if (App.restoreBackup(selectedFile)) { root.load(); backupRestored.open() }
    }

    Popup { id: backupSaved; anchors.centerIn: parent; Label { text: qsTr("Backup created") } }
    Popup { id: backupRestored; anchors.centerIn: parent; Label { text: qsTr("Backup restored") } }
    Popup { id: saved; anchors.centerIn: parent; Label { text: qsTr("Settings saved") } }
}

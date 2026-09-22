// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

Page {
    id: root
    signal openCsvImport()

    function load() {
        form.locations.text = App.settingList("lessonLocations").join("\n")
        form.genres.text = App.settingList("genres").join("\n")
        form.instruments.text = App.settingList("instruments").join("\n")
        form.sizes.text = App.settingList("instrumentSizes").join("\n")
        form.birthdayReminder.checked = App.settingValue("birthdayReminder", true)
        form.lessonEndReminder.checked = App.settingValue("lessonEndReminder", true)
        form.lessonEndMinutes.value = App.settingValue("minutesToLessonEndReminder", 3)
        form.shareLessonContent.checked = App.settingValue("saveNotesPiecesForAllPupils", true)
    }

    function cleanedLines(text) {
        return text.split(/\r?\n/).map(x => x.trim()).filter(x => x.length)
    }

    function save() {
        App.setSettingList("lessonLocations", cleanedLines(form.locations.text))
        App.setSettingList("genres", cleanedLines(form.genres.text))
        App.setSettingList("instruments", cleanedLines(form.instruments.text))
        App.setSettingList("instrumentSizes", cleanedLines(form.sizes.text))
        App.setSettingValue("birthdayReminder", form.birthdayReminder.checked)
        App.setSettingValue("lessonEndReminder", form.lessonEndReminder.checked)
        App.setSettingValue("minutesToLessonEndReminder", form.lessonEndMinutes.value)
        App.setSettingValue("saveNotesPiecesForAllPupils", form.shareLessonContent.checked)
        saved.open()
    }

    Action { id: backupAction; onTriggered: backupDialog.open() }
    Action { id: restoreAction; onTriggered: form.restoreConfirm.open() }
    Action { id: csvImportAction; onTriggered: root.openCsvImport() }
    Action { id: saveAction; onTriggered: root.save() }

    SettingsPageForm {
        id: form
        anchors.fill: parent
        databasePath: App.databasePath
        importedLegacyDatabase: App.importedLegacyDatabase
        languageIndex: Language.mode === "de" ? 2 : Language.mode === "en" ? 1 : 0
        backupAction: backupAction
        restoreAction: restoreAction
        csvImportAction: csvImportAction
        saveAction: saveAction

        languageCombo.onActivated: {
            const modes = ["system", "en", "de"]
            Language.setMode(modes[languageCombo.currentIndex])
        }
        restoreConfirm.onAccepted: restoreDialog.open()
    }

    FileDialog {
        id: backupDialog
        title: qsTr("Create Qupil backup")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "db"
        nameFilters: [qsTr("Qupil backup (*.db)")]
        onAccepted: if (App.exportBackup(selectedFile)) backupSaved.open()
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

    Component.onCompleted: load()
    Connections { target: Language; function onEffectiveLanguageChanged() { root.load() } }
}

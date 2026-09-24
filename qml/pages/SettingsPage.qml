// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

Page {
    id: root
    signal openCsvImport()

    property string lessonEndSoundPath: ""
    property string reminderSoundPath: ""

    function soundName(path, fallbackName) {
        if (!path || path.length === 0)
            return qsTr("Built-in: %1").arg(fallbackName)
        const normalized = path.replace(/\\/g, "/")
        const parts = normalized.split("/")
        return parts.length ? parts[parts.length - 1] : path
    }

    function load() {
        form.locations.text = App.settingList("lessonLocations").join("\n")
        form.genres.text = App.settingList("genres").join("\n")
        form.instruments.text = App.settingList("instruments").join("\n")
        form.sizes.text = App.settingList("instrumentSizes").join("\n")
        form.birthdayReminder.checked = App.settingValue("birthdayReminder", true)
        form.lessonEndReminder.checked = App.settingValue("lessonEndReminder", true)
        form.lessonEndMinutes.value = App.settingValue("minutesToLessonEndReminder", 3)
        root.lessonEndSoundPath = App.settingValue("lessonEndSoundPath", "")
        root.reminderSoundPath = App.settingValue("reminderSoundPath", "")
        form.lessonEndSoundPath.text = soundName(root.lessonEndSoundPath, "lesson-end.wav")
        form.reminderSoundPath.text = soundName(root.reminderSoundPath, "reminder.wav")
        form.lessonEndVolume.value = App.settingValue("lessonEndSoundVolume", 7)
        form.reminderVolume.value = App.settingValue("reminderSoundVolume", 7)
        form.androidExactAlarmGranted = App.exactAlarmPermissionGranted()
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
        App.setSettingValue("lessonEndSoundPath", root.lessonEndSoundPath)
        App.setSettingValue("lessonEndSoundVolume", Math.round(form.lessonEndVolume.value))
        App.setSettingValue("reminderSoundPath", root.reminderSoundPath)
        App.setSettingValue("reminderSoundVolume", Math.round(form.reminderVolume.value))
        App.setSettingValue("saveNotesPiecesForAllPupils", form.shareLessonContent.checked)
        App.syncNativeReminders()
        saved.open()
    }

    Action { id: backupAction; onTriggered: backupDialog.open() }
    Action { id: restoreAction; onTriggered: form.restoreConfirm.open() }
    Action { id: csvImportAction; onTriggered: root.openCsvImport() }
    Action { id: saveAction; onTriggered: root.save() }
    Action { id: chooseLessonEndSoundAction; onTriggered: lessonEndSoundDialog.open() }
    Action {
        id: defaultLessonEndSoundAction
        onTriggered: {
            root.lessonEndSoundPath = ""
            form.lessonEndSoundPath.text = root.soundName("", "lesson-end.wav")
        }
    }
    Action {
        id: testLessonEndSoundAction
        onTriggered: Metronome.previewReminderSound("lessonEnd", root.lessonEndSoundPath, Math.round(form.lessonEndVolume.value))
    }
    Action { id: chooseReminderSoundAction; onTriggered: reminderSoundDialog.open() }
    Action {
        id: defaultReminderSoundAction
        onTriggered: {
            root.reminderSoundPath = ""
            form.reminderSoundPath.text = root.soundName("", "reminder.wav")
        }
    }
    Action {
        id: testReminderSoundAction
        onTriggered: Metronome.previewReminderSound("reminder", root.reminderSoundPath, Math.round(form.reminderVolume.value))
    }
    Action { id: exactAlarmAction; onTriggered: App.requestExactAlarmPermission() }

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
        chooseLessonEndSoundAction: chooseLessonEndSoundAction
        defaultLessonEndSoundAction: defaultLessonEndSoundAction
        testLessonEndSoundAction: testLessonEndSoundAction
        chooseReminderSoundAction: chooseReminderSoundAction
        defaultReminderSoundAction: defaultReminderSoundAction
        testReminderSoundAction: testReminderSoundAction
        exactAlarmAction: exactAlarmAction

        languageCombo.onActivated: {
            const modes = ["system", "en", "de"]
            Language.setMode(modes[languageCombo.currentIndex])
        }
        restoreConfirm.onAccepted: restoreDialog.open()
    }

    FileDialog {
        id: lessonEndSoundDialog
        title: qsTr("Choose lesson end sound")
        fileMode: FileDialog.OpenFile
        nameFilters: Qt.platform.os === "ios"
                     ? [qsTr("iOS notification sounds (*.wav *.aiff *.aif *.caf)")]
                     : [qsTr("Sound files (*.wav *.aiff *.aif *.caf *.ogg *.mp3 *.m4a)"), qsTr("All files (*)")]
        onAccepted: {
            const imported = App.importReminderSound("lessonEnd", selectedFile)
            if (imported && imported.length) {
                root.lessonEndSoundPath = imported
                form.lessonEndSoundPath.text = root.soundName(imported, "lesson-end.wav")
            } else {
                soundImportFailed.open()
            }
        }
    }

    FileDialog {
        id: reminderSoundDialog
        title: qsTr("Choose reminder sound")
        fileMode: FileDialog.OpenFile
        nameFilters: Qt.platform.os === "ios"
                     ? [qsTr("iOS notification sounds (*.wav *.aiff *.aif *.caf)")]
                     : [qsTr("Sound files (*.wav *.aiff *.aif *.caf *.ogg *.mp3 *.m4a)"), qsTr("All files (*)")]
        onAccepted: {
            const imported = App.importReminderSound("reminder", selectedFile)
            if (imported && imported.length) {
                root.reminderSoundPath = imported
                form.reminderSoundPath.text = root.soundName(imported, "reminder.wav")
            } else {
                soundImportFailed.open()
            }
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
    Popup {
        id: soundImportFailed
        anchors.centerIn: parent
        width: Math.min(520, root.width - 32)
        Label { width: parent.width; text: App.lastError; wrapMode: Text.WordWrap }
    }

    Component.onCompleted: load()
    Connections { target: Language; function onEffectiveLanguageChanged() { root.load() } }
}

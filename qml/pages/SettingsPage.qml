// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

Page {
    id: root
    signal openCsvImport()

    property string lessonEndSoundPath: ""
    property string reminderSoundPath: ""
    // Programmatic assignments during load/language switching must not write
    // over stored settings or trigger native notification rescheduling.
    property bool loading: true

    function soundName(path, fallbackName) {
        if (!path || path.length === 0)
            return qsTr("Built-in: %1").arg(fallbackName)
        const normalized = path.replace(/\\/g, "/")
        const parts = normalized.split("/")
        return parts.length ? parts[parts.length - 1] : path
    }

    function load() {
        flushPendingWrites()
        root.loading = true
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
        if (Qt.platform.os === "ios")
            App.refreshNativeReminderDiagnostics()
        form.shareLessonContent.checked = App.settingValue("saveNotesPiecesForAllPupils", true)
        root.loading = false
    }

    function cleanedLines(text) {
        return text.split(/\r?\n/).map(x => x.trim()).filter(x => x.length)
    }

    function persistValue(key, value, reschedule) {
        if (root.loading)
            return
        App.setSettingValue(key, value)
        if (reschedule)
            requestReminderSync()
    }

    function requestReminderSync() {
        if (!root.loading)
            reminderSyncTimer.restart()
    }

    function deferListSave() {
        if (!root.loading)
            listSaveTimer.restart()
    }

    function saveListsNow() {
        if (root.loading)
            return
        App.setSettingList("lessonLocations", cleanedLines(form.locations.text))
        App.setSettingList("genres", cleanedLines(form.genres.text))
        App.setSettingList("instruments", cleanedLines(form.instruments.text))
        App.setSettingList("instrumentSizes", cleanedLines(form.sizes.text))
    }

    function flushLists() {
        if (!root.loading && listSaveTimer.running) {
            listSaveTimer.stop()
            saveListsNow()
        }
    }

    function deferVolumes() {
        if (!root.loading)
            volumeSaveTimer.restart()
    }

    function saveVolumesNow() {
        if (root.loading)
            return
        App.setSettingValue("lessonEndSoundVolume", Math.round(form.lessonEndVolume.value))
        App.setSettingValue("reminderSoundVolume", Math.round(form.reminderVolume.value))
        requestReminderSync()
    }

    function flushVolumes() {
        if (!root.loading && volumeSaveTimer.running) {
            volumeSaveTimer.stop()
            saveVolumesNow()
        }
    }

    function flushPendingWrites() {
        flushLists()
        flushVolumes()
        if (reminderSyncTimer.running) {
            reminderSyncTimer.stop()
            App.syncNativeReminders()
        }
    }

    // Coalesce rapid changes to avoid overlapping asynchronous iOS schedule
    // replacements. Every delayed write is flushed on focus loss, navigation,
    // application backgrounding and language reload.
    Timer { id: listSaveTimer; interval: 500; repeat: false; onTriggered: root.saveListsNow() }
    Timer { id: volumeSaveTimer; interval: 350; repeat: false; onTriggered: root.saveVolumesNow() }
    Timer { id: reminderSyncTimer; interval: 180; repeat: false; onTriggered: App.syncNativeReminders() }

    Action { id: backupAction; onTriggered: backupDialog.open() }
    Action { id: restoreAction; onTriggered: form.restoreConfirm.open() }
    Action { id: csvImportAction; onTriggered: root.openCsvImport() }
    Action { id: chooseLessonEndSoundAction; onTriggered: lessonEndSoundDialog.open() }
    Action {
        id: defaultLessonEndSoundAction
        onTriggered: {
            root.lessonEndSoundPath = ""
            form.lessonEndSoundPath.text = root.soundName("", "lesson-end.wav")
            root.persistValue("lessonEndSoundPath", "", true)
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
            root.persistValue("reminderSoundPath", "", true)
        }
    }
    Action {
        id: testReminderSoundAction
        onTriggered: Metronome.previewReminderSound("reminder", root.reminderSoundPath, Math.round(form.reminderVolume.value))
    }
    Action { id: exactAlarmAction; onTriggered: App.requestExactAlarmPermission() }
    Action {
        id: iosBackgroundTestAction
        onTriggered: {
            root.flushPendingWrites()
            if (App.scheduleNativeReminderTest())
                iosTestScheduled.open()
            else
                soundImportFailed.open()
        }
    }
    Action { id: iosDiagnosticsRefreshAction; onTriggered: App.refreshNativeReminderDiagnostics() }

    SettingsPageForm {
        id: form
        anchors.fill: parent
        databasePath: App.databasePath
        importedLegacyDatabase: App.importedLegacyDatabase
        languageIndex: Language.mode === "de" ? 2 : Language.mode === "en" ? 1 : 0
        backupAction: backupAction
        restoreAction: restoreAction
        csvImportAction: csvImportAction
        chooseLessonEndSoundAction: chooseLessonEndSoundAction
        defaultLessonEndSoundAction: defaultLessonEndSoundAction
        testLessonEndSoundAction: testLessonEndSoundAction
        chooseReminderSoundAction: chooseReminderSoundAction
        defaultReminderSoundAction: defaultReminderSoundAction
        testReminderSoundAction: testReminderSoundAction
        exactAlarmAction: exactAlarmAction
        iosBackgroundTestAction: iosBackgroundTestAction
        iosDiagnosticsRefreshAction: iosDiagnosticsRefreshAction
        nativeReminderDiagnostics: App.nativeReminderDiagnostics

        languageCombo.onActivated: {
            const modes = ["system", "en", "de"]
            Language.setMode(modes[languageCombo.currentIndex])
        }
        restoreConfirm.onAccepted: restoreDialog.open()
    }

    // Only user changes are persisted. The load() guard prevents any signals
    // caused by programmatic updates from writing an intermediate state.
    Connections {
        target: form.birthdayReminder
        function onToggled() { root.persistValue("birthdayReminder", form.birthdayReminder.checked, false) }
    }
    Connections {
        target: form.lessonEndReminder
        function onToggled() { root.persistValue("lessonEndReminder", form.lessonEndReminder.checked, true) }
    }
    Connections {
        target: form.lessonEndMinutes
        function onValueChanged() { root.persistValue("minutesToLessonEndReminder", form.lessonEndMinutes.value, true) }
    }
    Connections {
        target: form.shareLessonContent
        function onToggled() { root.persistValue("saveNotesPiecesForAllPupils", form.shareLessonContent.checked, false) }
    }
    Connections {
        target: form.lessonEndVolume
        function onValueChanged() { root.deferVolumes() }
        function onPressedChanged() { if (!form.lessonEndVolume.pressed) root.flushVolumes() }
    }
    Connections {
        target: form.reminderVolume
        function onValueChanged() { root.deferVolumes() }
        function onPressedChanged() { if (!form.reminderVolume.pressed) root.flushVolumes() }
    }
    Connections {
        target: form.locations
        function onTextChanged() { root.deferListSave() }
        function onActiveFocusChanged() { if (!form.locations.activeFocus) root.flushLists() }
    }
    Connections {
        target: form.genres
        function onTextChanged() { root.deferListSave() }
        function onActiveFocusChanged() { if (!form.genres.activeFocus) root.flushLists() }
    }
    Connections {
        target: form.instruments
        function onTextChanged() { root.deferListSave() }
        function onActiveFocusChanged() { if (!form.instruments.activeFocus) root.flushLists() }
    }
    Connections {
        target: form.sizes
        function onTextChanged() { root.deferListSave() }
        function onActiveFocusChanged() { if (!form.sizes.activeFocus) root.flushLists() }
    }
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state !== Qt.ApplicationActive)
                root.flushPendingWrites()
        }
        function onAboutToQuit() { root.flushPendingWrites() }
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
                root.persistValue("lessonEndSoundPath", imported, true)
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
                root.persistValue("reminderSoundPath", imported, true)
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
        onAccepted: {
            root.flushPendingWrites()
            if (App.restoreBackup(selectedFile)) { root.load(); backupRestored.open() }
        }
    }

    Popup { id: backupSaved; anchors.centerIn: parent; Label { text: qsTr("Backup created") } }
    Popup { id: backupRestored; anchors.centerIn: parent; Label { text: qsTr("Backup restored") } }
    Popup {
        id: iosTestScheduled
        anchors.centerIn: parent
        width: Math.min(560, root.width - 32)
        Label {
            width: parent.width
            text: qsTr("An iOS local notification is scheduled for 15 seconds from now. Put Qupil in the background immediately and wait for the system notification and sound.")
            wrapMode: Text.WordWrap
        }
    }
    Popup {
        id: soundImportFailed
        anchors.centerIn: parent
        width: Math.min(520, root.width - 32)
        Label { width: parent.width; text: App.lastError; wrapMode: Text.WordWrap }
    }

    Component.onCompleted: load()
    Component.onDestruction: flushPendingWrites()
    Connections { target: Language; function onEffectiveLanguageChanged() { root.load() } }
}

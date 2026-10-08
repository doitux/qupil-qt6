#!/usr/bin/env python3
"""Regression guards for Settings autosave and iOS notification PCM/CAF import."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
page = (root / 'qml/pages/SettingsPage.qml').read_text(encoding='utf-8')
form = (root / 'qml/pages/SettingsPageForm.ui.qml').read_text(encoding='utf-8')
app = (root / 'src/app/appcontroller.cpp').read_text(encoding='utf-8')
header = (root / 'src/app/native_reminders.h').read_text(encoding='utf-8')
ios = (root / 'src/app/native_reminders_ios.mm').read_text(encoding='utf-8')
cmake = (root / 'CMakeLists.txt').read_text(encoding='utf-8')

checks = {
    'manual save control removed': 'Save settings' not in form and 'saveAction' not in page + form,
    'settings load guarded': 'property bool loading: true' in page and 'root.loading = true' in page and 'root.loading = false' in page,
    'saved and reloaded language behavior': 'onEffectiveLanguageChanged() { root.load() }' in page,
    'checkboxes autosaved': all(x in page for x in (
        'persistValue("birthdayReminder"', 'persistValue("lessonEndReminder"',
        'persistValue("saveNotesPiecesForAllPupils"')),
    'spinbox autosaved': 'persistValue("minutesToLessonEndReminder"' in page,
    'sound import saved immediately': page.count('root.persistValue("lessonEndSoundPath"') == 2 and page.count('root.persistValue("reminderSoundPath"') == 2,
    'preview uses selected normalized file': 'Metronome.previewReminderSound("lessonEnd", root.lessonEndSoundPath' in page and 'Metronome.previewReminderSound("reminder", root.reminderSoundPath' in page,
    'volume sliders saved on release': 'function onPressedChanged() { if (!form.lessonEndVolume.pressed) root.flushVolumes() }' in page and 'function onPressedChanged() { if (!form.reminderVolume.pressed) root.flushVolumes() }' in page,
    'lists saved with debounce': 'id: listSaveTimer' in page and all(f'target: form.{name}' in page for name in ('locations', 'genres', 'instruments', 'sizes')),
    'flushed when page destroyed': 'Component.onDestruction: flushPendingWrites()' in page,
    'flushed on background': 'target: Qt.application' in page and 'onStateChanged()' in page,
    'native resync coalesced': 'id: reminderSyncTimer' in page and 'onTriggered: App.syncNativeReminders()' in page,
    'both sound profiles migrated': 'qupilNormalizeIosReminderSound(profile, previousPath, &error)' in app,
    'iOS import is sandbox-staged': 'streamFile(sourcePath, stagedPath, &error)' in app,
    'iOS import is normalized before returned': 'qupilNormalizeIosReminderSound(profile, stagedPath, &error)' in app and 'return normalized;' in app,
    'iOS import isolated from other platforms': '#if defined(Q_OS_IOS)' in app and 'return destination;\n#endif' in app,
    'iOS converter declared': 'qupilNormalizeIosReminderSound' in header and '#ifdef Q_OS_IOS' in header,
    'Core Audio Toolbox linked': '"-framework AudioToolbox"' in cmake,
    'Core Audio CAF writer': 'ExtAudioFileCreateWithURL(' in ios and 'kAudioFileCAFType' in ios,
    '16-bit Linear PCM output': 'kAudioFormatLinearPCM' in ios and 'pcm.mBitsPerChannel = 16' in ios,
    'strict duration constraint': 'double(totalFrames) / pcm.mSampleRate >= 30.0' in ios and 'if (totalFrames == 0)' in ios,
    'atomic replacement': 'std::rename(' in ios and 'QTemporaryFile temporary(' in ios,
    'separate stable profile names': '@"qupil-lesson-end.caf"' in ios and '@"qupil-reminder.caf"' in ios,
    'schedule uses CAF in Library/Sounds': 'NSString *fileName = [profilePrefix stringByAppendingString:@".caf"]' in ios and 'sourceInfo.canonicalFilePath() == expectedInfo.canonicalFilePath()' in ios,
    'both native scheduling and test use same selection': ios.count('prepareNotificationSound(') >= 4,
    'legacy filename copy removed': 'iosNotificationSoundExtensionSupported' not in ios,
}
for name, result in checks.items():
    if not result:
        raise SystemExit(f'FAIL: {name}')
print(f'PASS: Settings autosave + iOS notification sound ({len(checks)} checks)')

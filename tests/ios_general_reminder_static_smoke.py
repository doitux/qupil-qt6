#!/usr/bin/env python3
"""Regression for mode-1/mode-2 reminders delivered natively on iOS.

No iOS SDK is available in the Linux patch-preparation environment. The SQL
fixture executes the *actual query* extracted from nativeReminderSchedule().
Other assertions keep the foreground and sound-profile wiring from regressing.
"""
from pathlib import Path
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
def source(name):
    return (ROOT / name).read_text(encoding='utf-8')

cpp = source('src/app/appcontroller.cpp')
hpp = source('src/app/appcontroller.h')
ios = source('src/app/native_reminders_ios.mm')
native_h = source('src/app/native_reminders.h')
android = source('src/app/native_reminders_android.cpp')
desktop = source('src/app/native_reminders.cpp')
qml = source('qml/Main.qml')
settings = source('qml/pages/SettingsPage.qml')
form = source('qml/pages/SettingsPageForm.ui.qml')

schedule = cpp.split('QVariantList AppController::nativeReminderSchedule() const', 1)[1].split(
    'void AppController::syncNativeReminders()', 1)[0]
match = re.search(r'const auto reminders = selectRows\(QStringLiteral\((.*?)\),\s*\{lessonId\}\);',
                  schedule, re.S)
assert match, 'Native mode-1/mode-2 query missing'
query = ''.join(re.findall(r'"([^"\\]*)"', match.group(1)))
assert 'r.mode=1 OR (r.mode=2 AND EXISTS' in query, 'No native regular/pupil reminders'
assert 'COALESCE(r.notificationsound,0) AS sound' in query

with sqlite3.connect(':memory:') as db:
    db.executescript('''
        CREATE TABLE reminder(reminderid INTEGER, desc TEXT, mode INTEGER,
                              pupilid INTEGER, notificationsound INTEGER);
        CREATE TABLE pupil(pupilid INTEGER, forename TEXT, surname TEXT);
        CREATE TABLE pupilatlesson(lessonid INTEGER, pupilid INTEGER, stopdate TEXT);
        INSERT INTO pupil VALUES (11, 'Ada', 'Lovelace'), (12, 'Alan', 'Turing');
        INSERT INTO pupilatlesson VALUES (7, 11, '9999-99-99'),
                                       (7, 12, '2020-01-01');
        INSERT INTO reminder VALUES
          (1, 'App start only', 0, -1, 1),
          (2, 'Every lesson, audible', 1, -1, 1),
          (3, 'For active pupil', 2, 11, 1),
          (4, 'For former pupil', 2, 12, 1),
          (5, 'Every lesson, quiet', 1, -1, 0);
    ''')
    rows = db.execute(query, (7,)).fetchall()
    names = [row[1] for row in rows]
    assert names == ['Every lesson, audible', 'Every lesson, quiet',
                     'For active pupil'], names
    assert [row[3] for row in rows] == [1, 0, 1], rows

# iOS uses the same native weekly trigger, permission path, and normalized
# Library/Sounds selection as lesson-end. Mode 0 remains a startup QML event.
assert 'item.insert(QStringLiteral("identifier"), QStringLiteral("qupil-reminder-%1")' in schedule
assert 'item.insert(QStringLiteral("kind"), QStringLiteral("reminder"))' in schedule
assert 'item.insert(QStringLiteral("sound"), reminder.value(QStringLiteral("sound")).toBool())' in schedule
assert 'item.insert(QStringLiteral("kind"), QStringLiteral("lessonEnd"))' in schedule
assert 'UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:YES' in ios
assert 'UNAuthorizationOptionAlert | UNAuthorizationOptionSound' in ios
assert 'UNNotificationPresentationOptionBanner |' in ios
assert 'completionHandler(0)' not in ios
assert 'if (lessonEnd)' in ios and 'completionHandler(UNNotificationPresentationOptionSound)' in ios
assert 'item.value(QStringLiteral("sound")).toBool() && reminderVolume > 0' in ios
assert 'NSString *soundName = lessonEnd ? lessonEndSoundName : reminderSoundName;' in ios
assert 'reminderSoundPath,\n        @"qupil-reminder",' in ios
assert 'qupilNormalizeIosReminderSound' in ios
assert 'qupil-reminder.caf' in ios
assert 'replaceQupilSchedule(center, ownedSchedule' in ios
assert 'request.identifier hasPrefix:@"qupil-reminder-"' in ios
assert 'if (Qt.platform.os === "ios")\n            return' in qml
assert qml.index('if (Qt.platform.os === "ios")\n            return') < qml.index(
    'enqueueNotifications(App.lessonReminders(includeCurrentLesson))')
assert 'enqueueNotifications(App.startupReminders())' in qml
assert 'Metronome.playNotificationSound()' in qml  # desktop, Android & startup

# The general 15s test is independent of lesson-end and chooses the same
# normalized profile sound as regular schedules, not the lesson-end WAV.
assert 'Q_INVOKABLE bool scheduleNativeGeneralReminderTest()' in hpp
assert 'bool AppController::scheduleNativeGeneralReminderTest()' in cpp
assert 'return scheduleNativeReminderTestForProfile(QStringLiteral("reminder"));' in cpp
assert 'QStringLiteral("reminderSoundVolume")' in cpp
assert 'QStringLiteral("reminderSoundPath")' in cpp
assert 'bool qupilScheduleNativeReminderTest(const QString &profile,' in native_h
assert 'bool qupilScheduleNativeReminderTest(const QString &profile,' in ios
for stub in (android, desktop):
    assert 'bool qupilScheduleNativeReminderTest(const QString &, const QString &, int,' in stub
assert 'lessonEnd ? @"qupil-lesson-end" : @"qupil-reminder"' in ios
assert 'lessonEnd ? @"lesson-end.wav" : @"reminder.wav"' in ios
assert 'lessonEnd ? @"qupil-test-background" : @"qupil-test-reminder"' in ios
assert ios.count('addDiagnosticTestRequest(center, testIdentifier, soundName, testTitle, testBody)') == 2
assert 'App.scheduleNativeGeneralReminderTest()' in settings
assert 'iosGeneralTestAction: iosGeneralTestAction' in settings
assert 'property var iosGeneralTestAction: null' in form
assert 'action: root.iosGeneralTestAction' in form
assert 'upcomingRequests.emplace_back(' in ios and 'request.content.sound ?' in ios
assert 'emit dataChanged();' in cpp.split('int AppController::saveReminder(', 1)[1].split(
    'bool AppController::deleteReminder(', 1)[0]
print(f'PASS: iOS general reminder native path (SQL fixture: {len(rows)} matching reminders; 31 wiring guards)')

// SPDX-License-Identifier: GPL-2.0-or-later
#include "native_reminders.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

#include <QFile>
#include <QFileInfo>
#include <QStringList>
#include <QVariantMap>

@interface QupilNotificationDelegate : NSObject<UNUserNotificationCenterDelegate>
@end

@implementation QupilNotificationDelegate
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    (void)center;
    const BOOL lessonEnd = [notification.request.identifier hasPrefix:@"qupil-lesson-end-"];
    if (lessonEnd) {
        // Keep the historic foreground behavior: lesson-end reminder means sound,
        // not a Qupil popup/banner. In the background iOS presents the scheduled
        // system notification itself.
        completionHandler(UNNotificationPresentationOptionSound);
        return;
    }
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
        // The existing QML reminder dialog remains the foreground UI.
        completionHandler(0);
        return;
    }
    if (@available(iOS 14.0, *)) {
        completionHandler(UNNotificationPresentationOptionBanner |
                          UNNotificationPresentationOptionList |
                          UNNotificationPresentationOptionSound);
    } else {
        completionHandler(UNNotificationPresentationOptionSound);
    }
}
@end

namespace {

NSString *nsString(const QString &value)
{
    return value.toNSString();
}

QString qtString(NSString *value)
{
    return value ? QString::fromNSString(value) : QString{};
}

bool iosNotificationSoundExtensionSupported(const QString &path)
{
    const QString suffix = QFileInfo(path).suffix().toLower();
    return suffix == QStringLiteral("wav") || suffix == QStringLiteral("aiff")
        || suffix == QStringLiteral("aif") || suffix == QStringLiteral("caf");
}

NSURL *notificationSoundsDirectory()
{
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *library = [fm URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask].firstObject;
    if (!library)
        return nil;
    NSURL *sounds = [library URLByAppendingPathComponent:@"Sounds" isDirectory:YES];
    NSError *error = nil;
    if (![fm createDirectoryAtURL:sounds withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Qupil could not create Library/Sounds: %@", error);
        return nil;
    }
    return sounds;
}

bool copyQtResource(const QString &resourcePath, NSURL *destination)
{
    if (!destination)
        return false;
    const QString destinationPath = qtString(destination.path);
    if (QFileInfo::exists(destinationPath))
        QFile::remove(destinationPath);
    if (QFile::copy(resourcePath, destinationPath))
        return true;
    NSLog(@"Qupil could not materialize notification sound %@ -> %@",
          nsString(resourcePath), destination.path);
    return false;
}

NSString *prepareNotificationSound(const QString &sourcePath,
                                   NSString *profilePrefix,
                                   NSString *fallbackName,
                                   const QString &fallbackResourcePath)
{
    NSURL *sounds = notificationSoundsDirectory();
    if (!sounds)
        return fallbackName;

    NSFileManager *fm = NSFileManager.defaultManager;

    if (sourcePath.isEmpty()) {
        // Qt QRC resources are not files the iOS notification service can read.
        // Materialize the built-in WAV into Library/Sounds before scheduling.
        NSURL *destination = [sounds URLByAppendingPathComponent:fallbackName];
        if (copyQtResource(fallbackResourcePath, destination))
            return fallbackName;
        return fallbackName; // iOS falls back to the default notification sound if unavailable.
    }

    if (!iosNotificationSoundExtensionSupported(sourcePath))
        return fallbackName;

    NSString *extension = nsString(QFileInfo(sourcePath).suffix().toLower());
    NSString *fileName = [NSString stringWithFormat:@"%@.%@", profilePrefix, extension];
    NSURL *destination = [sounds URLByAppendingPathComponent:fileName];

    NSArray<NSURL *> *existing = [fm contentsOfDirectoryAtURL:sounds
                                  includingPropertiesForKeys:nil
                                                     options:0
                                                       error:nil];
    NSString *prefix = [profilePrefix stringByAppendingString:@"."];
    for (NSURL *url in existing) {
        if ([url.lastPathComponent hasPrefix:prefix] && ![url.lastPathComponent isEqualToString:fileName])
            [fm removeItemAtURL:url error:nil];
    }

    [fm removeItemAtURL:destination error:nil];
    NSError *error = nil;
    if (![fm copyItemAtPath:nsString(sourcePath) toPath:destination.path error:&error]) {
        NSLog(@"Qupil could not copy custom notification sound %@: %@", nsString(sourcePath), error);
        return fallbackName;
    }
    return fileName;
}

QupilNotificationDelegate *notificationDelegate()
{
    static QupilNotificationDelegate *delegate = [[QupilNotificationDelegate alloc] init];
    return delegate;
}

NSString *authorizationStatusName(UNAuthorizationStatus status)
{
    switch (status) {
    case UNAuthorizationStatusNotDetermined: return @"notDetermined";
    case UNAuthorizationStatusDenied: return @"denied";
    case UNAuthorizationStatusAuthorized: return @"authorized";
    case UNAuthorizationStatusProvisional: return @"provisional";
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
    case UNAuthorizationStatusEphemeral: return @"ephemeral";
#endif
    }
    return @"unknown";
}

NSString *notificationSettingName(UNNotificationSetting setting)
{
    switch (setting) {
    case UNNotificationSettingNotSupported: return @"notSupported";
    case UNNotificationSettingDisabled: return @"disabled";
    case UNNotificationSettingEnabled: return @"enabled";
    }
    return @"unknown";
}

void installSchedule(UNUserNotificationCenter *center,
                     const QVariantList &schedule,
                     NSString *lessonEndSoundName,
                     int lessonEndVolume,
                     NSString *reminderSoundName,
                     int reminderVolume)
{
    for (const QVariant &value : schedule) {
        const QVariantMap item = value.toMap();
        const QString identifier = item.value(QStringLiteral("identifier")).toString();
        if (identifier.isEmpty())
            continue;

        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        const bool lessonEnd = item.value(QStringLiteral("kind")).toString() == QStringLiteral("lessonEnd");
        content.title = nsString(item.value(QStringLiteral("title")).toString());
        content.body = nsString(item.value(QStringLiteral("body")).toString());
        if (@available(iOS 15.0, *))
            content.interruptionLevel = UNNotificationInterruptionLevelActive;

        const bool shouldPlaySound = lessonEnd
            ? lessonEndVolume > 0
            : item.value(QStringLiteral("sound")).toBool() && reminderVolume > 0;
        if (shouldPlaySound) {
            NSString *soundName = lessonEnd ? lessonEndSoundName : reminderSoundName;
            content.sound = [UNNotificationSound soundNamed:soundName];
        }

        NSDateComponents *components = [[NSDateComponents alloc] init];
        const int day = item.value(QStringLiteral("day")).toInt(); // Monday=0 ... Sunday=6
        components.weekday = day == 6 ? 1 : day + 2;
        components.hour = item.value(QStringLiteral("hour")).toInt();
        components.minute = item.value(QStringLiteral("minute")).toInt();
        components.second = 0;
        components.timeZone = NSTimeZone.localTimeZone;

        UNCalendarNotificationTrigger *trigger =
            [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:YES];
        UNNotificationRequest *request =
            [UNNotificationRequest requestWithIdentifier:nsString(identifier)
                                                  content:content
                                                  trigger:trigger];
        [center addNotificationRequest:request withCompletionHandler:^(NSError *error) {
            if (error)
                NSLog(@"Qupil reminder scheduling failed for %@: %@", nsString(identifier), error);
        }];
    }
}

void replaceQupilSchedule(UNUserNotificationCenter *center,
                          const QVariantList &schedule,
                          NSString *lessonEndSoundName,
                          int lessonEndVolume,
                          NSString *reminderSoundName,
                          int reminderVolume)
{
    const QVariantList ownedSchedule = schedule;
    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
        NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
        for (UNNotificationRequest *request in requests) {
            if ([request.identifier hasPrefix:@"qupil-lesson-end-"] ||
                [request.identifier hasPrefix:@"qupil-reminder-"])
                [identifiers addObject:request.identifier];
        }
        if (identifiers.count > 0)
            [center removePendingNotificationRequestsWithIdentifiers:identifiers];
        installSchedule(center, ownedSchedule, lessonEndSoundName, lessonEndVolume,
                        reminderSoundName, reminderVolume);
    }];
}

void addDiagnosticTestRequest(UNUserNotificationCenter *center,
                              NSString *soundName,
                              NSString *title,
                              NSString *body)
{
    [center removePendingNotificationRequestsWithIdentifiers:@[@"qupil-test-background"]];

    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title;
    content.body = body;
    content.sound = [UNNotificationSound soundNamed:soundName];
    if (@available(iOS 15.0, *))
        content.interruptionLevel = UNNotificationInterruptionLevelActive;

    UNTimeIntervalNotificationTrigger *trigger =
        [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:15.0 repeats:NO];
    UNNotificationRequest *request =
        [UNNotificationRequest requestWithIdentifier:@"qupil-test-background"
                                              content:content
                                              trigger:trigger];
    [center addNotificationRequest:request withCompletionHandler:^(NSError *error) {
        if (error)
            NSLog(@"Qupil iOS background reminder test scheduling failed: %@", error);
        else
            NSLog(@"QUPIL_IOS_REMINDER_TEST scheduled=yes delay=15s sound=%@", soundName);
    }];
}

} // namespace

bool qupilSyncNativeReminders(const QVariantList &schedule,
                              const QString &lessonEndSoundPath,
                              int lessonEndVolume,
                              const QString &reminderSoundPath,
                              int reminderVolume,
                              QString *errorMessage)
{
    (void)errorMessage;

    const QVariantList ownedSchedule = schedule;

    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    center.delegate = notificationDelegate();
    NSString *lessonSound = prepareNotificationSound(
        lessonEndSoundPath,
        @"qupil-lesson-end",
        @"lesson-end.wav",
        QStringLiteral(":/qt/qml/Qupil/data/sounds/lesson-end.wav"));
    NSString *reminderSound = prepareNotificationSound(
        reminderSoundPath,
        @"qupil-reminder",
        @"reminder.wav",
        QStringLiteral(":/qt/qml/Qupil/data/sounds/reminder.wav"));
    if (ownedSchedule.isEmpty()) {
        replaceQupilSchedule(center, {}, lessonSound, lessonEndVolume, reminderSound, reminderVolume);
        return true;
    }

    // Request both alert and sound. Lesson-end notifications remain sound-only
    // while Qupil is foregrounded because the delegate suppresses their banner.
    constexpr UNAuthorizationOptions authorizationOptions =
        UNAuthorizationOptionAlert | UNAuthorizationOptionSound;

    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
            replaceQupilSchedule(center, {}, lessonSound, lessonEndVolume, reminderSound, reminderVolume);
            return;
        }
        if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
            [center requestAuthorizationWithOptions:authorizationOptions
                                  completionHandler:^(BOOL granted, NSError *error) {
                if (error)
                    NSLog(@"Qupil notification permission request failed: %@", error);
                if (granted)
                    replaceQupilSchedule(center, ownedSchedule, lessonSound, lessonEndVolume, reminderSound, reminderVolume);
            }];
            return;
        }
        replaceQupilSchedule(center, ownedSchedule, lessonSound, lessonEndVolume, reminderSound, reminderVolume);
    }];
    return true;
}

bool qupilScheduleNativeReminderTest(const QString &lessonEndSoundPath,
                                     int lessonEndVolume,
                                     const QString &title,
                                     const QString &body,
                                     QString *errorMessage)
{
    if (lessonEndVolume <= 0) {
        if (errorMessage)
            *errorMessage = QStringLiteral("Lesson end sound volume is 0.");
        return false;
    }

    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    center.delegate = notificationDelegate();
    NSString *soundName = prepareNotificationSound(
        lessonEndSoundPath,
        @"qupil-lesson-end",
        @"lesson-end.wav",
        QStringLiteral(":/qt/qml/Qupil/data/sounds/lesson-end.wav"));
    NSString *testTitle = nsString(title);
    NSString *testBody = nsString(body);
    constexpr UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound;

    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
            NSLog(@"QUPIL_IOS_REMINDER_TEST scheduled=no reason=permission-denied");
            return;
        }
        if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
            [center requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError *error) {
                if (error)
                    NSLog(@"Qupil notification test permission request failed: %@", error);
                if (granted)
                    addDiagnosticTestRequest(center, soundName, testTitle, testBody);
            }];
            return;
        }
        addDiagnosticTestRequest(center, soundName, testTitle, testBody);
    }];
    return true;
}

void qupilFetchNativeReminderDiagnostics(QupilReminderDiagnosticsCallback callback)
{
    if (!callback)
        return;

    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
            int qupilCount = 0;
            int lessonEndCount = 0;
            int reminderCount = 0;
            int testCount = 0;
            QStringList nextRequests;

            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss ZZZZ";

            for (UNNotificationRequest *request in requests) {
                if (![request.identifier hasPrefix:@"qupil-"])
                    continue;
                ++qupilCount;
                if ([request.identifier hasPrefix:@"qupil-lesson-end-"])
                    ++lessonEndCount;
                else if ([request.identifier hasPrefix:@"qupil-reminder-"])
                    ++reminderCount;
                else if ([request.identifier hasPrefix:@"qupil-test-"])
                    ++testCount;

                if (nextRequests.size() < 8) {
                    NSDate *nextDate = nil;
                    if ([request.trigger isKindOfClass:[UNCalendarNotificationTrigger class]])
                        nextDate = ((UNCalendarNotificationTrigger *)request.trigger).nextTriggerDate;
                    else if ([request.trigger isKindOfClass:[UNTimeIntervalNotificationTrigger class]])
                        nextDate = ((UNTimeIntervalNotificationTrigger *)request.trigger).nextTriggerDate;
                    const QString when = nextDate ? qtString([formatter stringFromDate:nextDate]) : QStringLiteral("?");
                    nextRequests << QStringLiteral("%1 @ %2")
                                        .arg(qtString(request.identifier), when);
                }
            }

            NSURL *sounds = notificationSoundsDirectory();
            NSFileManager *fm = NSFileManager.defaultManager;
            const bool builtInLessonSoundPresent = sounds &&
                [fm fileExistsAtPath:[sounds URLByAppendingPathComponent:@"lesson-end.wav"].path];
            const bool builtInReminderSoundPresent = sounds &&
                [fm fileExistsAtPath:[sounds URLByAppendingPathComponent:@"reminder.wav"].path];

            QVariantMap result;
            result.insert(QStringLiteral("platform"), QStringLiteral("ios"));
            result.insert(QStringLiteral("available"), true);
            result.insert(QStringLiteral("authorization"), qtString(authorizationStatusName(settings.authorizationStatus)));
            result.insert(QStringLiteral("sound"), qtString(notificationSettingName(settings.soundSetting)));
            result.insert(QStringLiteral("alert"), qtString(notificationSettingName(settings.alertSetting)));
            result.insert(QStringLiteral("notificationCenter"), qtString(notificationSettingName(settings.notificationCenterSetting)));
            result.insert(QStringLiteral("lockScreen"), qtString(notificationSettingName(settings.lockScreenSetting)));
            result.insert(QStringLiteral("pendingQupil"), qupilCount);
            result.insert(QStringLiteral("pendingLessonEnd"), lessonEndCount);
            result.insert(QStringLiteral("pendingReminders"), reminderCount);
            result.insert(QStringLiteral("pendingTests"), testCount);
            result.insert(QStringLiteral("builtInLessonSoundPresent"), builtInLessonSoundPresent);
            result.insert(QStringLiteral("builtInReminderSoundPresent"), builtInReminderSoundPresent);
            result.insert(QStringLiteral("nextRequests"), nextRequests);
            callback(result);
        }];
    }];
}

bool qupilExactAlarmPermissionGranted()
{
    return true;
}

void qupilRequestExactAlarmPermission()
{
}

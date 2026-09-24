// SPDX-License-Identifier: GPL-2.0-or-later
#include "native_reminders.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

#include <QFileInfo>
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
        // Qupil's supported iOS builds are newer; keep a warning-free fallback
        // for older SDK targets instead of using the deprecated Alert option.
        completionHandler(UNNotificationPresentationOptionSound);
    }
}
@end

namespace {

NSString *nsString(const QString &value)
{
    return value.toNSString();
}

bool iosNotificationSoundExtensionSupported(const QString &path)
{
    const QString suffix = QFileInfo(path).suffix().toLower();
    return suffix == QStringLiteral("wav") || suffix == QStringLiteral("aiff")
        || suffix == QStringLiteral("aif") || suffix == QStringLiteral("caf");
}

NSString *prepareCustomSound(const QString &sourcePath, NSString *profilePrefix, NSString *fallbackName)
{
    if (sourcePath.isEmpty() || !iosNotificationSoundExtensionSupported(sourcePath))
        return fallbackName;

    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *library = [fm URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask].firstObject;
    if (!library)
        return fallbackName;
    NSURL *sounds = [library URLByAppendingPathComponent:@"Sounds" isDirectory:YES];
    NSError *error = nil;
    if (![fm createDirectoryAtURL:sounds withIntermediateDirectories:YES attributes:nil error:&error])
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
    if (![fm copyItemAtPath:nsString(sourcePath) toPath:destination.path error:&error])
        return fallbackName;
    return fileName;
}

QupilNotificationDelegate *notificationDelegate()
{
    static QupilNotificationDelegate *delegate = [[QupilNotificationDelegate alloc] init];
    return delegate;
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
        if (!lessonEnd) {
            content.title = nsString(item.value(QStringLiteral("title")).toString());
            content.body = nsString(item.value(QStringLiteral("body")).toString());
        }
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
    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
        NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
        for (UNNotificationRequest *request in requests) {
            if ([request.identifier hasPrefix:@"qupil-lesson-end-"] ||
                [request.identifier hasPrefix:@"qupil-reminder-"])
                [identifiers addObject:request.identifier];
        }
        if (identifiers.count > 0)
            [center removePendingNotificationRequestsWithIdentifiers:identifiers];
        installSchedule(center, schedule, lessonEndSoundName, lessonEndVolume,
                        reminderSoundName, reminderVolume);
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

    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    center.delegate = notificationDelegate();
    NSString *lessonSound = prepareCustomSound(lessonEndSoundPath, @"qupil-lesson-end", @"lesson-end.wav");
    NSString *reminderSound = prepareCustomSound(reminderSoundPath, @"qupil-reminder", @"reminder.wav");
    if (schedule.isEmpty()) {
        replaceQupilSchedule(center, {}, lessonSound, lessonEndVolume, reminderSound, reminderVolume);
        return true;
    }

    UNAuthorizationOptions authorizationOptions = UNAuthorizationOptionSound;
    for (const QVariant &value : schedule) {
        if (value.toMap().value(QStringLiteral("kind")).toString() == QStringLiteral("reminder")) {
            authorizationOptions |= UNAuthorizationOptionAlert;
            break;
        }
    }

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
                    replaceQupilSchedule(center, schedule, lessonSound, lessonEndVolume, reminderSound, reminderVolume);
            }];
            return;
        }
        replaceQupilSchedule(center, schedule, lessonSound, lessonEndVolume, reminderSound, reminderVolume);
    }];
    return true;
}

bool qupilExactAlarmPermissionGranted()
{
    return true;
}

void qupilRequestExactAlarmPermission()
{
}

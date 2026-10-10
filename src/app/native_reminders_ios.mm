// SPDX-License-Identifier: GPL-2.0-or-later
#include "native_reminders.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <AudioToolbox/AudioToolbox.h>

#include <QFile>
#include <QFileInfo>
#include <QStringList>
#include <QTemporaryFile>

#include <algorithm>
#include <cstdio>
#include <cerrno>
#include <cstring>
#include <utility>
#include <vector>
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
    // Generic lesson-start/pupil reminders must use the same native delivery
    // as lesson-end reminders even in the foreground. QML no longer polls
    // these reminders on iOS, so there is no duplicate popup or sound.
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

// Both normal scheduling and the 15-second test reference the exact CAF
// written by qupilNormalizeIosReminderSound. Never copy an unknown codec into
// Library/Sounds and hope that UNNotificationSound can decode it.
NSString *prepareNotificationSound(const QString &sourcePath,
                                   NSString *profilePrefix,
                                   NSString *fallbackName,
                                   const QString &fallbackResourcePath)
{
    NSURL *sounds = notificationSoundsDirectory();
    if (!sounds)
        return fallbackName;

    NSURL *defaultURL = [sounds URLByAppendingPathComponent:fallbackName];
    if (!QFileInfo::exists(qtString(defaultURL.path)))
        copyQtResource(fallbackResourcePath, defaultURL);
    if (sourcePath.isEmpty())
        return fallbackName;

    NSString *fileName = [profilePrefix stringByAppendingString:@".caf"];
    NSURL *expectedURL = [sounds URLByAppendingPathComponent:fileName];
    const QFileInfo sourceInfo(sourcePath);
    const QFileInfo expectedInfo(qtString(expectedURL.path));
    if (sourceInfo.isFile() && expectedInfo.isFile() &&
        sourceInfo.canonicalFilePath() == expectedInfo.canonicalFilePath())
        return fileName;

    NSLog(@"QUPIL_IOS_SOUND invalid custom sound path: %@; using default", nsString(sourcePath));
    return fallbackName;
}

struct ScopedExtAudioFile {
    ExtAudioFileRef ref = nullptr;
    ~ScopedExtAudioFile() { if (ref) ExtAudioFileDispose(ref); }
    ScopedExtAudioFile(const ScopedExtAudioFile &) = delete;
    ScopedExtAudioFile &operator=(const ScopedExtAudioFile &) = delete;
    ScopedExtAudioFile() = default;
};

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
                              NSString *identifier,
                              NSString *soundName,
                              NSString *title,
                              NSString *body)
{
    [center removePendingNotificationRequestsWithIdentifiers:@[identifier]];

    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title;
    content.body = body;
    content.sound = [UNNotificationSound soundNamed:soundName];
    if (@available(iOS 15.0, *))
        content.interruptionLevel = UNNotificationInterruptionLevelActive;

    UNTimeIntervalNotificationTrigger *trigger =
        [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:15.0 repeats:NO];
    UNNotificationRequest *request =
        [UNNotificationRequest requestWithIdentifier:identifier
                                              content:content
                                              trigger:trigger];
    [center addNotificationRequest:request withCompletionHandler:^(NSError *error) {
        if (error)
            NSLog(@"Qupil iOS background reminder test scheduling failed: %@", error);
        else
            NSLog(@"QUPIL_IOS_REMINDER_TEST scheduled=yes id=%@ delay=15s sound=%@",
                  identifier, soundName);
    }];
}

} // namespace

QString qupilNormalizeIosReminderSound(const QString &profile,
                                       const QString &sourcePath,
                                       QString *errorMessage)
{
    auto fail = [errorMessage](const QString &message) -> QString {
        if (errorMessage)
            *errorMessage = message;
        return {};
    };

    NSString *fileName = nil;
    if (profile == QStringLiteral("lessonEnd"))
        fileName = @"qupil-lesson-end.caf";
    else if (profile == QStringLiteral("reminder"))
        fileName = @"qupil-reminder.caf";
    else
        return fail(QStringLiteral("Unknown notification sound profile."));

    NSURL *sounds = notificationSoundsDirectory();
    if (!sounds)
        return fail(QStringLiteral("Library/Sounds is not writable."));
    NSURL *finalURL = [sounds URLByAppendingPathComponent:fileName];
    const QString finalPath = qtString(finalURL.path);
    if (!QFileInfo(sourcePath).isFile())
        return fail(QStringLiteral("The selected audio file is missing or unreadable."));

    // A file generated by an earlier import needs no re-encoding on startup.
    if (QFileInfo(sourcePath).canonicalFilePath() == QFileInfo(finalPath).canonicalFilePath()) {
        if (errorMessage)
            errorMessage->clear();
        return finalPath;
    }

    ScopedExtAudioFile input;
    const OSStatus openStatus = ExtAudioFileOpenURL(
        (__bridge CFURLRef)[NSURL fileURLWithPath:nsString(sourcePath)], &input.ref);
    if (openStatus != noErr)
        return fail(QStringLiteral("Audio decoder could not open the file (OSStatus %1).")
                        .arg(openStatus));

    AudioStreamBasicDescription sourceFormat{};
    UInt32 size = sizeof(sourceFormat);
    OSStatus status = ExtAudioFileGetProperty(input.ref, kExtAudioFileProperty_FileDataFormat,
                                               &size, &sourceFormat);
    if (status != noErr)
        return fail(QStringLiteral("Could not inspect audio format (OSStatus %1).").arg(status));
    if (sourceFormat.mSampleRate <= 0 || sourceFormat.mChannelsPerFrame < 1 ||
        sourceFormat.mChannelsPerFrame > 2)
        return fail(QStringLiteral("The audio must be mono or stereo with a valid sample rate."));

    // 16-bit little-endian signed interleaved PCM in a Core Audio Format file.
    // Keep the source sample rate: decoding and file writing use the same ASBD.
    AudioStreamBasicDescription pcm{};
    pcm.mSampleRate = sourceFormat.mSampleRate;
    pcm.mFormatID = kAudioFormatLinearPCM;
    pcm.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    pcm.mChannelsPerFrame = sourceFormat.mChannelsPerFrame;
    pcm.mBitsPerChannel = 16;
    pcm.mFramesPerPacket = 1;
    pcm.mBytesPerFrame = 2 * pcm.mChannelsPerFrame;
    pcm.mBytesPerPacket = pcm.mBytesPerFrame;
    status = ExtAudioFileSetProperty(input.ref, kExtAudioFileProperty_ClientDataFormat,
                                     sizeof(pcm), &pcm);
    if (status != noErr)
        return fail(QStringLiteral("Audio decoding is unsupported (OSStatus %1).").arg(status));

    // Write a separate file first. A failed import must not break notifications
    // already using the previous CAF at finalPath.
    QTemporaryFile temporary(qtString(sounds.path) + QStringLiteral("/qupil-import-XXXXXX.caf"));
    if (!temporary.open())
        return fail(temporary.errorString());
    const QString temporaryPath = temporary.fileName();
    temporary.close();

    ScopedExtAudioFile output;
    status = ExtAudioFileCreateWithURL(
        (__bridge CFURLRef)[NSURL fileURLWithPath:nsString(temporaryPath)],
        kAudioFileCAFType, &pcm, nullptr, kAudioFileFlags_EraseFile, &output.ref);
    if (status != noErr)
        return fail(QStringLiteral("Could not create PCM/CAF audio (OSStatus %1).").arg(status));
    status = ExtAudioFileSetProperty(output.ref, kExtAudioFileProperty_ClientDataFormat,
                                     sizeof(pcm), &pcm);
    if (status != noErr)
        return fail(QStringLiteral("Could not configure CAF output (OSStatus %1).").arg(status));

    constexpr UInt32 chunkFrames = 2048;
    std::vector<char> samples(chunkFrames * pcm.mBytesPerFrame);
    qint64 totalFrames = 0;
    for (;;) {
        AudioBufferList buffer{};
        buffer.mNumberBuffers = 1;
        buffer.mBuffers[0].mNumberChannels = pcm.mChannelsPerFrame;
        buffer.mBuffers[0].mDataByteSize = UInt32(samples.size());
        buffer.mBuffers[0].mData = samples.data();
        UInt32 frames = chunkFrames;
        status = ExtAudioFileRead(input.ref, &frames, &buffer);
        if (status != noErr)
            return fail(QStringLiteral("Audio decoding failed (OSStatus %1).").arg(status));
        if (frames == 0)
            break;
        totalFrames += frames;
        // Apple requires notification sounds to be strictly shorter than 30 s.
        if (double(totalFrames) / pcm.mSampleRate >= 30.0)
            return fail(QStringLiteral("iOS notification sounds must be shorter than 30 seconds."));
        status = ExtAudioFileWrite(output.ref, frames, &buffer);
        if (status != noErr)
            return fail(QStringLiteral("Writing PCM/CAF failed (OSStatus %1).").arg(status));
    }
    if (totalFrames == 0)
        return fail(QStringLiteral("The audio file is empty."));

    status = ExtAudioFileDispose(output.ref);
    output.ref = nullptr;
    if (status != noErr)
        return fail(QStringLiteral("Finalizing PCM/CAF failed (OSStatus %1).").arg(status));

    // POSIX rename is atomic within Library/Sounds; this is a private sandbox
    // directory and no unfinished conversion is ever visible to the scheduler.
    if (std::rename(temporaryPath.toUtf8().constData(), finalPath.toUtf8().constData()) != 0)
        return fail(QStringLiteral("Could not install notification sound: %1")
                        .arg(QString::fromLocal8Bit(std::strerror(errno))));

    if (errorMessage)
        errorMessage->clear();
    NSLog(@"QUPIL_IOS_SOUND converted profile=%@ duration=%.2fs output=%@",
          nsString(profile), double(totalFrames) / pcm.mSampleRate, nsString(finalPath));
    return finalPath;
}

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

bool qupilScheduleNativeReminderTest(const QString &profile,
                                     const QString &soundPath,
                                     int volume,
                                     const QString &title,
                                     const QString &body,
                                     QString *errorMessage)
{
    if (profile != QStringLiteral("lessonEnd") && profile != QStringLiteral("reminder")) {
        if (errorMessage)
            *errorMessage = QStringLiteral("Unknown notification sound profile.");
        return false;
    }
    if (volume <= 0) {
        if (errorMessage)
            *errorMessage = QStringLiteral("Notification sound volume is 0.");
        return false;
    }

    const bool lessonEnd = profile == QStringLiteral("lessonEnd");
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    center.delegate = notificationDelegate();
    NSString *soundName = prepareNotificationSound(
        soundPath,
        lessonEnd ? @"qupil-lesson-end" : @"qupil-reminder",
        lessonEnd ? @"lesson-end.wav" : @"reminder.wav",
        lessonEnd ? QStringLiteral(":/qt/qml/Qupil/data/sounds/lesson-end.wav")
                  : QStringLiteral(":/qt/qml/Qupil/data/sounds/reminder.wav"));
    NSString *testIdentifier = lessonEnd ? @"qupil-test-background" : @"qupil-test-reminder";
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
                    addDiagnosticTestRequest(center, testIdentifier, soundName, testTitle, testBody);
            }];
            return;
        }
        addDiagnosticTestRequest(center, testIdentifier, soundName, testTitle, testBody);
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
            // Sort by actual next delivery, not by the notification center's
            // arbitrary request enumeration order. Display whether each
            // request has a sound configured for device-side diagnostics.
            std::vector<std::pair<double, QString>> upcomingRequests;

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

                NSDate *nextDate = nil;
                if ([request.trigger isKindOfClass:[UNCalendarNotificationTrigger class]])
                    nextDate = ((UNCalendarNotificationTrigger *)request.trigger).nextTriggerDate;
                else if ([request.trigger isKindOfClass:[UNTimeIntervalNotificationTrigger class]])
                    nextDate = ((UNTimeIntervalNotificationTrigger *)request.trigger).nextTriggerDate;
                if (nextDate) {
                    const QString when = qtString([formatter stringFromDate:nextDate]);
                    const QString sound = request.content.sound ? QStringLiteral("yes") : QStringLiteral("no");
                    upcomingRequests.emplace_back(nextDate.timeIntervalSince1970,
                        QStringLiteral("%1 @ %2 sound=%3")
                            .arg(qtString(request.identifier), when, sound));
                }
            }
            std::sort(upcomingRequests.begin(), upcomingRequests.end(),
                      [](const auto &a, const auto &b) { return a.first < b.first; });
            QStringList nextRequests;
            for (size_t i = 0; i < upcomingRequests.size() && i < 12; ++i)
                nextRequests << upcomingRequests[i].second;

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

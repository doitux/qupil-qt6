// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QtGlobal>

#include <functional>

bool qupilSyncNativeReminders(const QVariantList &schedule,
                              const QString &lessonEndSoundPath,
                              int lessonEndVolume,
                              const QString &reminderSoundPath,
                              int reminderVolume,
                              QString *errorMessage = nullptr);

// Converts an imported iOS notification sound to 16-bit PCM/CAF in
// the app's Library/Sounds. On failure the previously installed sound stays intact.
#ifdef Q_OS_IOS
QString qupilNormalizeIosReminderSound(const QString &profile,
                                       const QString &sourcePath,
                                       QString *errorMessage = nullptr);
#endif

bool qupilExactAlarmPermissionGranted();
void qupilRequestExactAlarmPermission();

using QupilReminderDiagnosticsCallback = std::function<void(const QVariantMap &)>;

// The lessonEnd and reminder profiles use the same sound resolver as real
// scheduled local notifications, but distinct diagnostic request identifiers.
bool qupilScheduleNativeReminderTest(const QString &profile,
                                     const QString &soundPath,
                                     int volume,
                                     const QString &title,
                                     const QString &body,
                                     QString *errorMessage = nullptr);

void qupilFetchNativeReminderDiagnostics(QupilReminderDiagnosticsCallback callback);

// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include <functional>

bool qupilSyncNativeReminders(const QVariantList &schedule,
                              const QString &lessonEndSoundPath,
                              int lessonEndVolume,
                              const QString &reminderSoundPath,
                              int reminderVolume,
                              QString *errorMessage = nullptr);

bool qupilExactAlarmPermissionGranted();
void qupilRequestExactAlarmPermission();

using QupilReminderDiagnosticsCallback = std::function<void(const QVariantMap &)>;

bool qupilScheduleNativeReminderTest(const QString &lessonEndSoundPath,
                                     int lessonEndVolume,
                                     const QString &title,
                                     const QString &body,
                                     QString *errorMessage = nullptr);

void qupilFetchNativeReminderDiagnostics(QupilReminderDiagnosticsCallback callback);

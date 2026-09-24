// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QString>
#include <QVariantList>

bool qupilSyncNativeReminders(const QVariantList &schedule,
                              const QString &lessonEndSoundPath,
                              int lessonEndVolume,
                              const QString &reminderSoundPath,
                              int reminderVolume,
                              QString *errorMessage = nullptr);

bool qupilExactAlarmPermissionGranted();
void qupilRequestExactAlarmPermission();

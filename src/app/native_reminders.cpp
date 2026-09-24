// SPDX-License-Identifier: GPL-2.0-or-later
#include "native_reminders.h"

bool qupilSyncNativeReminders(const QVariantList &, const QString &, int,
                              const QString &, int, QString *)
{
    return true;
}

bool qupilExactAlarmPermissionGranted()
{
    return true;
}

void qupilRequestExactAlarmPermission()
{
}

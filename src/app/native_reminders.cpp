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


bool qupilScheduleNativeReminderTest(const QString &, int, const QString &, const QString &, QString *errorMessage)
{
    if (errorMessage)
        *errorMessage = QStringLiteral("Native reminder test is only available on iOS.");
    return false;
}

void qupilFetchNativeReminderDiagnostics(QupilReminderDiagnosticsCallback callback)
{
    if (callback) {
        callback({{QStringLiteral("platform"), QStringLiteral("desktop")},
                  {QStringLiteral("available"), false}});
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
#include "native_reminders.h"

#include <QCoreApplication>
#include <QJniObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QVariant>

bool qupilSyncNativeReminders(const QVariantList &schedule,
                              const QString &lessonEndSoundPath,
                              int lessonEndVolume,
                              const QString &reminderSoundPath,
                              int reminderVolume,
                              QString *errorMessage)
{
    Q_UNUSED(errorMessage)
    const QString scheduleJson = QString::fromUtf8(
        QJsonDocument(QJsonArray::fromVariantList(schedule)).toJson(QJsonDocument::Compact));

    QNativeInterface::QAndroidApplication::runOnAndroidMainThread(
        [scheduleJson, lessonEndSoundPath, lessonEndVolume, reminderSoundPath, reminderVolume]() {
            const QJniObject context = QNativeInterface::QAndroidApplication::context();
            if (!context.isValid())
                return QVariant(false);

            const QJniObject jJson = QJniObject::fromString(scheduleJson);
            const QJniObject jLessonSound = QJniObject::fromString(lessonEndSoundPath);
            const QJniObject jReminderSound = QJniObject::fromString(reminderSoundPath);
            QJniObject::callStaticMethod<void>(
                "org/qupil/app/QupilReminderScheduler",
                "sync",
                "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;ILjava/lang/String;I)V",
                context.object<jobject>(),
                jJson.object<jstring>(),
                jLessonSound.object<jstring>(),
                jint(lessonEndVolume),
                jReminderSound.object<jstring>(),
                jint(reminderVolume));
            return QVariant(true);
        });
    return true;
}

bool qupilExactAlarmPermissionGranted()
{
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid())
        return false;
    return QJniObject::callStaticMethod<jboolean>(
        "org/qupil/app/QupilReminderScheduler",
        "exactAlarmPermissionGranted",
        "(Landroid/content/Context;)Z",
        context.object<jobject>());
}

void qupilRequestExactAlarmPermission()
{
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([]() {
        const QJniObject context = QNativeInterface::QAndroidApplication::context();
        if (!context.isValid())
            return QVariant(false);
        QJniObject::callStaticMethod<void>(
            "org/qupil/app/QupilReminderScheduler",
            "requestExactAlarmPermission",
            "(Landroid/content/Context;)V",
            context.object<jobject>());
        return QVariant(true);
    });
}


bool qupilScheduleNativeReminderTest(const QString &, int, const QString &, const QString &, QString *errorMessage)
{
    if (errorMessage)
        *errorMessage = QStringLiteral("Native reminder test is currently only available on iOS.");
    return false;
}

void qupilFetchNativeReminderDiagnostics(QupilReminderDiagnosticsCallback callback)
{
    if (callback) {
        callback({{QStringLiteral("platform"), QStringLiteral("android")},
                  {QStringLiteral("available"), false}});
    }
}

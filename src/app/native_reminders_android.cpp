// SPDX-License-Identifier: GPL-2.0-or-later
#include "native_reminders.h"

#include <QCoreApplication>
#include <QJniObject>
#include <QJsonArray>
#include <QJsonDocument>

bool qupilSyncNativeReminders(const QVariantList &schedule,
                              const QString &lessonEndSoundPath,
                              int lessonEndVolume,
                              const QString &reminderSoundPath,
                              int reminderVolume,
                              QString *errorMessage)
{
    Q_UNUSED(errorMessage)
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid())
        return false;

    const QByteArray json = QJsonDocument(QJsonArray::fromVariantList(schedule)).toJson(QJsonDocument::Compact);
    const QJniObject jJson = QJniObject::fromString(QString::fromUtf8(json));
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
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid())
        return;
    QJniObject::callStaticMethod<void>(
        "org/qupil/app/QupilReminderScheduler",
        "requestExactAlarmPermission",
        "(Landroid/content/Context;)V",
        context.object<jobject>());
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

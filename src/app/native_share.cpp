// SPDX-License-Identifier: GPL-2.0-or-later
#include "native_share.h"

#ifdef Q_OS_ANDROID
#include <QCoreApplication>
#include <QFileInfo>
#include <QJniObject>
#include <QVariant>

bool qupilSharePdf(const QString &filePath, const QString &title, QString *errorMessage)
{
    Q_UNUSED(errorMessage)
    const QString fileName = QFileInfo(filePath).fileName();
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([fileName, title]() {
        const QJniObject context = QNativeInterface::QAndroidApplication::context();
        if (!context.isValid())
            return QVariant(false);
        const QJniObject jFileName = QJniObject::fromString(fileName);
        const QJniObject jTitle = QJniObject::fromString(title);
        QJniObject::callStaticMethod<void>(
            "org/qupil/app/QupilShare",
            "sharePdf",
            "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)V",
            context.object<jobject>(), jFileName.object<jstring>(), jTitle.object<jstring>());
        return QVariant(true);
    });
    return true;
}
#else
bool qupilSharePdf(const QString &, const QString &, QString *errorMessage)
{
    if (errorMessage)
        *errorMessage = QStringLiteral("Native sharing is only available on mobile platforms.");
    return false;
}
#endif

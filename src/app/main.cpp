// SPDX-License-Identifier: GPL-2.0-or-later

#include <QCoreApplication>
#ifdef QUPIL_NATIVE_WIDGET_PRINTING
#include <QApplication>
#else
#include <QGuiApplication>
#endif
#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
#include <QDir>
#include <QFileInfo>
#include <QLibraryInfo>
#endif
#include <QIcon>
#include <QDebug>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <cstdlib>

#include "appcontroller.h"
#include "languagecontroller.h"
#include "metronomecontroller.h"
#include "qupil_build_info.h"

int main(int argc, char *argv[])
{
    // QUPIL_NATIVE_SAVE_DIALOG_V1
#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    // An SDK-built QGuiApplication need not load KDE's in-process Qt plugins.
    // The matching Qt portal plugin talks to the system's desktop portal over
    // D-Bus; on Plasma the KDE backend draws the real file chooser.
    // This preference affects Qupil only, not the desktop or other programs.
    // Set QUPIL_FILE_DIALOG_THEME=system to keep an explicitly chosen theme.
    if (qEnvironmentVariable("QUPIL_FILE_DIALOG_THEME") != QStringLiteral("system")) {
        const QString portalPlugin = QDir(QLibraryInfo::path(QLibraryInfo::PluginsPath))
            .filePath(QStringLiteral("platformthemes/libqxdgdesktopportal.so"));
        if (QFileInfo::exists(portalPlugin)) {
            qputenv("QT_QPA_PLATFORMTHEME", QByteArrayLiteral("xdgdesktopportal"));
            qInfo() << "QUPIL_FILE_DIALOGS: requesting xdgdesktopportal";
        } else {
            qWarning() << "QUPIL_FILE_DIALOGS: Qt portal plugin is missing;"
                          " using the default platform dialog integration.";
        }
    }
#endif
#ifdef QUPIL_NATIVE_WIDGET_PRINTING
    QApplication app(argc, argv);
#else
    QGuiApplication app(argc, argv);
#endif
    QCoreApplication::setOrganizationName(QStringLiteral("Qupil"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("qupil.org"));
    QCoreApplication::setApplicationName(QStringLiteral("Qupil"));
    QCoreApplication::setApplicationVersion(QStringLiteral(QUPIL_VERSION));
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/Qupil/qupil.png")));
    app.setApplicationDisplayName(QStringLiteral("Qupil"));

    const QString buildCommit = QStringLiteral(QUPIL_BUILD_COMMIT);
    const QString buildTimestamp = QStringLiteral(QUPIL_BUILD_TIMESTAMP);
    qInfo().noquote()
        << QStringLiteral("QUPIL_BUILD version=%1 commit=%2 timestamp=%3")
               .arg(QCoreApplication::applicationVersion(), buildCommit, buildTimestamp);

    // Install the selected translator before AppController is constructed.
    // AppController populates translated model roles in its constructor, so the
    // translator must already be active at that point.
    QQmlApplicationEngine engine;
    LanguageController languageController(&engine);

    // AppController is owned by QGuiApplication so it outlives the QML engine.
    // Otherwise the stack-local controller is destroyed before 'engine' and
    // QML bindings briefly see App == null during application shutdown.
    auto *controller = new AppController(&app);
    MetronomeController metronome;

    // Rebuild translated C++ model roles whenever the user changes language.
    // QQmlEngine::retranslate() (called by LanguageController) handles qsTr()
    // bindings; refreshAll() handles strings materialized inside C++ models.
    QObject::connect(&languageController, &LanguageController::effectiveLanguageChanged,
                     controller, &AppController::refreshAll);

    // Build/CI-only diagnostic. It verifies both initial translation timing and
    // a live de -> en -> de model round-trip without affecting normal runs.
    if (qEnvironmentVariableIsSet("QUPIL_I18N_SELFTEST")) {
        const auto logModels = [controller](const QString &tag) {
            const QVariantMap lesson = controller->lessons()->get(0);
            const QVariantMap reminder = controller->reminders()->get(0);
            const QVariantMap recital = controller->recitals()->get(0);
            qInfo().noquote()
                << QStringLiteral("QUPIL_I18N_MODELS_%1=%2|%3|%4|%5")
                       .arg(tag,
                            lesson.value(QStringLiteral("typeName")).toString(),
                            lesson.value(QStringLiteral("dayName")).toString(),
                            reminder.value(QStringLiteral("modeName")).toString(),
                            recital.value(QStringLiteral("stateName")).toString());
        };
        logModels(QStringLiteral("DE"));
        languageController.setMode(QStringLiteral("en"));
        logModels(QStringLiteral("EN"));
        languageController.setMode(QStringLiteral("de"));
        logModels(QStringLiteral("DE2"));
    }

    engine.rootContext()->setContextProperty(QStringLiteral("Language"), &languageController);
    engine.rootContext()->setContextProperty(QStringLiteral("App"), controller);
    engine.rootContext()->setContextProperty(QStringLiteral("Metronome"), &metronome);
    engine.rootContext()->setContextProperty(QStringLiteral("QupilBuildCommit"), buildCommit);
    engine.rootContext()->setContextProperty(QStringLiteral("QupilBuildTimestamp"), buildTimestamp);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(EXIT_FAILURE); },
                     Qt::QueuedConnection);

    engine.loadFromModule(QStringLiteral("Qupil"), QStringLiteral("Main"));
    return app.exec();
}

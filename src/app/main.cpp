// SPDX-License-Identifier: GPL-2.0-or-later

#include <QCoreApplication>
#include <QGuiApplication>
#include <QIcon>
#include <QDebug>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <cstdlib>

#include "appcontroller.h"
#include "languagecontroller.h"
#include "metronomecontroller.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("Qupil"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("qupil.org"));
    QCoreApplication::setApplicationName(QStringLiteral("Qupil"));
    QCoreApplication::setApplicationVersion(QStringLiteral(QUPIL_VERSION));
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/Qupil/qupil.png")));
    app.setApplicationDisplayName(QStringLiteral("Qupil"));

    // Install the selected translator before AppController is constructed.
    // AppController populates translated model roles in its constructor, so the
    // translator must already be active at that point.
    QQmlApplicationEngine engine;
    LanguageController languageController(&engine);

    AppController controller;
    MetronomeController metronome;

    // Rebuild translated C++ model roles whenever the user changes language.
    // QQmlEngine::retranslate() (called by LanguageController) handles qsTr()
    // bindings; refreshAll() handles strings materialized inside C++ models.
    QObject::connect(&languageController, &LanguageController::effectiveLanguageChanged,
                     &controller, &AppController::refreshAll);

    // Build/CI-only diagnostic. It verifies both initial translation timing and
    // a live de -> en -> de model round-trip without affecting normal runs.
    if (qEnvironmentVariableIsSet("QUPIL_I18N_SELFTEST")) {
        const auto logModels = [&controller](const QString &tag) {
            const QVariantMap lesson = controller.lessons()->get(0);
            const QVariantMap reminder = controller.reminders()->get(0);
            const QVariantMap recital = controller.recitals()->get(0);
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
    engine.rootContext()->setContextProperty(QStringLiteral("App"), &controller);
    engine.rootContext()->setContextProperty(QStringLiteral("Metronome"), &metronome);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(EXIT_FAILURE); },
                     Qt::QueuedConnection);

    engine.loadFromModule(QStringLiteral("Qupil"), QStringLiteral("Main"));
    return app.exec();
}

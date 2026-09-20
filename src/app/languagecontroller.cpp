#include "languagecontroller.h"
#include <QCoreApplication>
#include <QDebug>
#include <QLocale>
#include <QQmlEngine>
#include <QSettings>
#include <QStandardPaths>
LanguageController::LanguageController(QQmlEngine *engine,QObject *parent):QObject(parent),m_engine(engine){
    const QString forced=qEnvironmentVariable("QUPIL_UI_LANGUAGE");
    m_mode=forced.isEmpty()?loadPersistedMode():normalizedMode(forced);
    apply(false);
}
QString LanguageController::normalizedMode(const QString &mode){
    const QString v=mode.trimmed().toLower();
    return (v==QStringLiteral("de")||v==QStringLiteral("en")||v==QStringLiteral("system"))?v:QStringLiteral("system");
}
QString LanguageController::systemLanguage() const { return QLocale::system().language()==QLocale::German?QStringLiteral("de"):QStringLiteral("en"); }
QString LanguageController::resolvedLanguage(const QString &mode) const { const QString v=normalizedMode(mode); return v==QStringLiteral("system")?systemLanguage():v; }
QString LanguageController::loadPersistedMode() const {
    QSettings settings; const QString key=QStringLiteral("ui/languageMode");
    if(settings.contains(key)) return normalizedMode(settings.value(key).toString());
    const QString legacyPath=QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)+QStringLiteral("/qupil-ui.ini");
    QSettings legacy(legacyPath,QSettings::IniFormat);
    if(legacy.contains(QStringLiteral("languageMode"))){
        const QString migrated=normalizedMode(legacy.value(QStringLiteral("languageMode")).toString());
        settings.setValue(key,migrated); settings.sync(); return migrated;
    }
    return QStringLiteral("system");
}
void LanguageController::storeMode() const { QSettings s; s.setValue(QStringLiteral("ui/languageMode"),m_mode); s.sync(); }
void LanguageController::apply(bool retranslate){
    QCoreApplication::removeTranslator(&m_translator);
    const QString requested=resolvedLanguage(m_mode); bool loaded=true; QString effective=requested;
    if(requested==QStringLiteral("de")){
        loaded=m_translator.load(QStringLiteral(":/i18n/qupil_de.qm"));
        if(loaded) QCoreApplication::installTranslator(&m_translator);
        else { qWarning().noquote()<<"QUPIL_I18N failed to load :/i18n/qupil_de.qm"; effective=QStringLiteral("en"); }
    }
    const bool changed=m_effectiveLanguage!=effective||m_translationLoaded!=loaded;
    m_effectiveLanguage=effective; m_translationLoaded=loaded;
    if(retranslate&&m_engine) m_engine->retranslate();
    if(changed) emit effectiveLanguageChanged();
    qInfo().noquote()<<QStringLiteral("QUPIL_I18N mode=%1 system=%2 effective=%3 loaded=%4").arg(m_mode,systemLanguage(),m_effectiveLanguage,m_translationLoaded?QStringLiteral("yes"):QStringLiteral("no"));
    qInfo().noquote()<<QStringLiteral("QUPIL_I18N_SAMPLE=%1").arg(QCoreApplication::translate("Main","Overview"));
}
void LanguageController::setMode(const QString &mode){
    const QString v=normalizedMode(mode); if(v==m_mode) return; m_mode=v; storeMode(); emit modeChanged(); apply(true);
}

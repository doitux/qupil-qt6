#pragma once
#include <QObject>
#include <QTranslator>
class QQmlEngine;
class LanguageController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(QString systemLanguage READ systemLanguage CONSTANT)
    Q_PROPERTY(QString effectiveLanguage READ effectiveLanguage NOTIFY effectiveLanguageChanged)
    Q_PROPERTY(bool translationLoaded READ translationLoaded NOTIFY effectiveLanguageChanged)
public:
    explicit LanguageController(QQmlEngine *engine, QObject *parent=nullptr);
    QString mode() const { return m_mode; }
    QString systemLanguage() const;
    QString effectiveLanguage() const { return m_effectiveLanguage; }
    bool translationLoaded() const { return m_translationLoaded; }
public slots:
    void setMode(const QString &mode);
signals:
    void modeChanged();
    void effectiveLanguageChanged();
private:
    static QString normalizedMode(const QString &mode);
    QString resolvedLanguage(const QString &mode) const;
    QString loadPersistedMode() const;
    void storeMode() const;
    void apply(bool retranslate);
    QQmlEngine *m_engine=nullptr;
    QTranslator m_translator;
    QString m_mode=QStringLiteral("system");
    QString m_effectiveLanguage=QStringLiteral("en");
    bool m_translationLoaded=true;
};

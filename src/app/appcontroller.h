// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QUrl>

#include "databasemanager.h"
#include "variantlistmodel.h"

class QSqlQuery;

class AppController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QString databasePath READ databasePath CONSTANT)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(bool importedLegacyDatabase READ importedLegacyDatabase CONSTANT)
    Q_PROPERTY(VariantListModel* pupils READ pupils CONSTANT)
    Q_PROPERTY(VariantListModel* lessons READ lessons CONSTANT)
    Q_PROPERTY(VariantListModel* reminders READ reminders CONSTANT)
    Q_PROPERTY(VariantListModel* library READ library CONSTANT)
    Q_PROPERTY(VariantListModel* recitals READ recitals CONSTANT)
    Q_PROPERTY(VariantListModel* archive READ archive CONSTANT)
    Q_PROPERTY(QString pupilFilter READ pupilFilter WRITE setPupilFilter NOTIFY pupilFilterChanged)

public:
    explicit AppController(QObject *parent = nullptr);

    bool ready() const { return m_ready; }
    QString databasePath() const { return m_database.databasePath(); }
    QString lastError() const { return m_lastError; }
    bool importedLegacyDatabase() const { return m_database.importedLegacyDatabase(); }

    VariantListModel *pupils() { return &m_pupils; }
    VariantListModel *lessons() { return &m_lessons; }
    VariantListModel *reminders() { return &m_reminders; }
    VariantListModel *library() { return &m_library; }
    VariantListModel *recitals() { return &m_recitals; }
    VariantListModel *archive() { return &m_archive; }

    QString pupilFilter() const { return m_pupilFilter; }
    void setPupilFilter(const QString &value);

    Q_INVOKABLE void refreshAll();
    Q_INVOKABLE void clearLastError() { clearError(); }
    Q_INVOKABLE bool exportBackup(const QUrl &destination);
    Q_INVOKABLE bool restoreBackup(const QUrl &source);
    Q_INVOKABLE QVariantMap previewPupilCsv(const QUrl &source, const QString &encoding) const;
    Q_INVOKABLE int importPupilCsv(const QUrl &source, const QString &encoding, const QVariantMap &mapping);
    Q_INVOKABLE QVariantMap dashboardStats() const;
    Q_INVOKABLE QVariantList todayLessons() const;
    Q_INVOKABLE QVariantList scheduleForDay(int day) const;
    Q_INVOKABLE QVariantList birthdays() const;
    Q_INVOKABLE QVariantMap instrumentOverview() const;
    Q_INVOKABLE QVariantList overdueRecitalPupils() const;
    Q_INVOKABLE QVariantList pupilsWithoutEnsemble() const;

    Q_INVOKABLE QString timetableDocumentHtml() const;
    Q_INVOKABLE QString dayOverviewDocumentHtml(int day, int noteCount = 3, int freeSpaceCm = 2) const;
    Q_INVOKABLE QString recitalDocumentHtml(int recitalId) const;
    Q_INVOKABLE QString rentalInstrumentDocumentHtml() const;
    Q_INVOKABLE QUrl suggestedPdfUrl(const QString &baseName) const;
    Q_INVOKABLE QString suggestedPdfFileName(const QString &baseName) const;
    Q_INVOKABLE QUrl pdfUrlInFolder(const QUrl &folder, const QString &baseName) const;
    Q_INVOKABLE bool exportDocumentPdf(const QString &html, const QUrl &destination,
                                        const QString &title, bool landscape = false);
    Q_INVOKABLE bool shareDocumentPdf(const QString &html, const QString &baseName,
                                       const QString &title, bool landscape = false);
    Q_INVOKABLE bool printDocumentNative(const QString &html, const QString &title,
                                          bool landscape = false);
    Q_INVOKABLE QStringList availablePrinters() const;
    Q_INVOKABLE QString defaultPrinterName() const;
    Q_INVOKABLE bool printDocument(const QString &html, const QString &printerName,
                                    const QString &title, bool landscape = false);

    Q_INVOKABLE QVariantMap pupil(int pupilId) const;
    Q_INVOKABLE int savePupil(const QVariantMap &values);
    Q_INVOKABLE bool deletePupil(int pupilId);
    Q_INVOKABLE bool archivePupil(int pupilId);
    Q_INVOKABLE QString pupilArchiveHtml(int pupilId) const;
    Q_INVOKABLE bool deleteArchiveEntry(int pupilId);
    Q_INVOKABLE QVariantList pupilLessonMemberships(int pupilId) const;
    Q_INVOKABLE QVariantMap lessonMembershipContext(int palId) const;
    Q_INVOKABLE QVariantList notesForMembership(int palId) const;
    Q_INVOKABLE QVariantList piecesForMembership(int palId) const;
    Q_INVOKABLE QString noteTemplateText(const QString &content) const;
    Q_INVOKABLE QVariantList notesForPupil(int pupilId) const;
    Q_INVOKABLE QVariantList piecesForPupil(int pupilId) const;
    Q_INVOKABLE QVariantList activitiesForPupil(int pupilId) const;
    Q_INVOKABLE QVariantList loanedMusicForPupil(int pupilId) const;
    Q_INVOKABLE int addNote(int palId, const QString &date, const QString &content);
    Q_INVOKABLE bool deleteNote(int noteId);
    Q_INVOKABLE int addPiece(int palId, const QString &composer, const QString &title,
                             const QString &genre, int duration, int state);
    Q_INVOKABLE bool deletePiece(int pieceId);
    Q_INVOKABLE int addActivity(int pupilId, bool continuous, const QVariantMap &values);
    Q_INVOKABLE bool deleteActivity(int activityId);

    Q_INVOKABLE QVariantMap lesson(int lessonId) const;
    Q_INVOKABLE int saveLesson(const QVariantMap &values);
    Q_INVOKABLE bool deleteLesson(int lessonId);
    Q_INVOKABLE QVariantList lessonPupils(int lessonId) const;
    Q_INVOKABLE QVariantList availablePupilsForLesson(int lessonId) const;
    Q_INVOKABLE bool addPupilToLesson(int lessonId, int pupilId);
    Q_INVOKABLE bool removePupilFromLesson(int lessonId, int pupilId);

    Q_INVOKABLE QVariantMap reminder(int reminderId) const;
    Q_INVOKABLE QVariantList startupReminders() const;
    Q_INVOKABLE QVariantList lessonReminders(bool includeCurrentLesson = false) const;
    Q_INVOKABLE QVariantList lessonEndWarnings() const;
    Q_INVOKABLE int saveReminder(const QVariantMap &values);
    Q_INVOKABLE bool deleteReminder(int reminderId);

    Q_INVOKABLE int addSheetMusic(const QString &author, const QString &title, const QString &publisher);
    Q_INVOKABLE bool deleteSheetMusic(int smlId);
    Q_INVOKABLE bool loanSheetMusic(int smlId, int pupilId);
    Q_INVOKABLE bool returnSheetMusic(int smlId);

    Q_INVOKABLE QVariantMap recital(int recitalId) const;
    Q_INVOKABLE int saveRecital(const QVariantMap &values);
    Q_INVOKABLE bool deleteRecital(int recitalId);
    Q_INVOKABLE QVariantList recitalPieces(int recitalId) const;
    Q_INVOKABLE QVariantList readyPieces() const;
    Q_INVOKABLE bool addPieceToRecital(int recitalId, int pieceId);
    Q_INVOKABLE bool addExternalPieceToRecital(int recitalId, const QString &composer, const QString &title,
                                               const QString &genre, int duration, const QString &musician);
    Q_INVOKABLE bool removePieceFromRecital(int parId);
    Q_INVOKABLE bool saveRecitalPieceOrder(int recitalId, const QVariantList &parIds);
    Q_INVOKABLE bool finishRecital(int recitalId, bool createActivities, bool finishPieces);

    Q_INVOKABLE QStringList settingList(const QString &key) const;
    Q_INVOKABLE void setSettingList(const QString &key, const QStringList &values);
    Q_INVOKABLE QVariant settingValue(const QString &key, const QVariant &fallback = {}) const;
    Q_INVOKABLE void setSettingValue(const QString &key, const QVariant &value);

signals:
    void readyChanged();
    void lastErrorChanged();
    void pupilFilterChanged();
    void dataChanged();

#ifdef QUPIL_XDG_PORTAL_PRINTING
private slots:
    void handlePortalPreparePrintResponse(uint response, const QVariantMap &results);
    void handlePortalPrintResponse(uint response, const QVariantMap &results);
#endif

private:
    QVector<QVariantMap> selectRows(const QString &sql, const QVariantList &binds = {}) const;
    QVariantMap selectOne(const QString &sql, const QVariantList &binds = {}) const;
    bool execute(const QString &sql, const QVariantList &binds = {});
    qint64 insert(const QString &sql, const QVariantList &binds = {});
    int ensureLookupId(const QString &table, const QString &idColumn,
                       const QString &valueColumn, const QString &value);
    void setError(const QString &message);
    void clearError();

    void refreshPupils();
    void refreshLessons();
    void refreshReminders();
    void refreshLibrary();
    void refreshRecitals();
    void refreshArchive();
    QVariantMap lessonRecord(int lessonId) const;
    QString lessonDisplayName(int lessonId) const;
    QString archivedLessonDisplayName(int lastLessonNameId) const;
    QString formatAutomaticLessonName(int type, int durationMinutes, const QString &locationToken,
                                      const QString &pupilToken) const;
    QString activeAutomaticLessonName(const QVariantMap &lessonRow, const QVariantList &members) const;
    QString buildPupilArchiveHtml(int pupilId) const;
    void importLegacySettings();
    QString legacyConfigPath() const;

    static QString dayName(int day);
    static QString lessonTypeName(int type);
    static QString recitalStateName(int state);
    static QString reminderModeName(int mode);

#ifdef QUPIL_XDG_PORTAL_PRINTING
    bool startPortalPrintRequest(uint token);
    void finishPortalPrint();

    QString m_portalPrintPdfPath;
    QString m_portalPrintTitle;
    QString m_portalPrepareRequestPath;
    QString m_portalPrintRequestPath;
    bool m_portalPrintInProgress = false;
#endif

    DatabaseManager m_database;
    bool m_ready = false;
    QString m_lastError;
    QString m_pupilFilter;

    VariantListModel m_pupils;
    VariantListModel m_lessons;
    VariantListModel m_reminders;
    VariantListModel m_library;
    VariantListModel m_recitals;
    VariantListModel m_archive;
};

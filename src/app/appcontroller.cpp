// SPDX-License-Identifier: GPL-2.0-or-later
#include "appcontroller.h"
#include "native_share.h"

#include <QDate>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLocale>
#include <QPageLayout>
#include <QPageSize>
#include <QPdfWriter>
#include <QStandardPaths>
#include <QSettings>
#include <QRegularExpression>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QTime>
#include <QTemporaryFile>
#include <QTextDocument>
#ifdef QUPIL_XDG_PORTAL_PRINTING
#include <QUuid>
#endif
#include <QXmlStreamReader>
#include <QtGlobal>
#ifdef QUPIL_DESKTOP_PRINTING
#include <QPrinter>
#include <QPrinterInfo>
#endif
#ifdef QUPIL_NATIVE_WIDGET_PRINTING
#include <QDialog>
#include <QPrintDialog>
#endif
#ifdef QUPIL_XDG_PORTAL_PRINTING
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusUnixFileDescriptor>
#endif
#include <algorithm>
#include <iterator>
#include <utility>

namespace {
QString isoToday()
{
    return QDate::currentDate().toString(Qt::ISODate);
}

QString htmlCell(const QVariant &value)
{
    return value.toString().toHtmlEscaped();
}

QString formattedIsoDate(const QString &value)
{
    const QDate date = QDate::fromString(value, Qt::ISODate);
    return date.isValid() ? date.toString(QStringLiteral("dd.MM.yyyy")) : value;
}

QString documentCss()
{
    return QStringLiteral(
        "body{font-family:sans-serif;color:#000000;font-size:10pt;}"
        "h1{font-size:20pt;margin:0 0 4mm 0;}h2{font-size:14pt;margin:5mm 0 2mm 0;}"
        "p.meta{color:#555;margin:0 0 4mm 0;}table{width:100%;border-collapse:collapse;}"
        "th{background:#ffffff;text-align:left;font-weight:600;}th,td{border:1px solid #9aa0a6;padding:2.2mm;vertical-align:top;}"
        "tr:nth-child(even) td{background:#ffffff;} .day{background:#3d84a8;color:white;padding:2mm 3mm;margin-top:4mm;}"
        ".footer{margin-top:6mm;color:#666;font-size:8pt;text-align:center;}"
        ".notes{font-size:9pt;} .writing{height:9mm;border-bottom:1px solid #c4c7c5;}"
        ".noborder td,.noborder th{border:0;background:transparent;padding:1mm;}"
    );
}

QString documentFrame(const QString &title, const QString &body)
{
    return QStringLiteral("<!doctype html><html><head><meta charset='utf-8'><style>%1</style></head><body>"
                          "<h1>%2</h1>%3<div class='footer'>Qupil %4 - %5</div></body></html>")
        .arg(documentCss(), title.toHtmlEscaped(), body,
             QCoreApplication::applicationVersion().toHtmlEscaped(),
             QStringLiteral("&copy;2006-%1 - Felix Hammer - qupil.de").arg(QDate::currentDate().year()));
}

QString safePdfBaseName(QString value)
{
    value = value.trimmed();
    if (value.isEmpty())
        value = QStringLiteral("Qupil");
    value.replace(QRegularExpression(QStringLiteral("[\\\\/:*?\"<>|]+")), QStringLiteral("_"));
    if (!value.endsWith(QStringLiteral(".pdf"), Qt::CaseInsensitive))
        value += QStringLiteral(".pdf");
    return value;
}

bool writeHtmlPdf(const QString &html, const QString &filePath, const QString &title,
                  bool landscape, QString *error)
{
    QDir().mkpath(QFileInfo(filePath).absolutePath());
    QPdfWriter writer(filePath);
    writer.setTitle(title);
    writer.setCreator(QStringLiteral("Qupil %1").arg(QCoreApplication::applicationVersion()));
    writer.setResolution(300);
    writer.setPageSize(QPageSize(QPageSize::A4));
    writer.setPageOrientation(landscape ? QPageLayout::Landscape : QPageLayout::Portrait);
    writer.setPageMargins(QMarginsF(10, 12, 10, 12), QPageLayout::Millimeter);

    QTextDocument document;
    document.setHtml(html);
    document.print(&writer);
    QFileInfo info(filePath);
    if (!info.exists() || info.size() <= 0) {
        if (error)
            *error = QCoreApplication::translate("AppController", "The PDF file could not be created.");
        return false;
    }
    return true;
}
}

AppController::AppController(QObject *parent)
    : QObject(parent),
      m_pupils({QStringLiteral("id"), QStringLiteral("forename"), QStringLiteral("surname"),
                QStringLiteral("name"), QStringLiteral("instrument"), QStringLiteral("email"),
                QStringLiteral("phone"), QStringLiteral("birthday")}, this),
      m_lessons({QStringLiteral("id"), QStringLiteral("name"), QStringLiteral("type"),
                 QStringLiteral("typeName"), QStringLiteral("day"), QStringLiteral("dayName"),
                 QStringLiteral("start"), QStringLiteral("stop"), QStringLiteral("location"),
                 QStringLiteral("unsteady"), QStringLiteral("pupilNames")}, this),
      m_reminders({QStringLiteral("id"), QStringLiteral("description"), QStringLiteral("mode"),
                   QStringLiteral("modeName"), QStringLiteral("pupilId"), QStringLiteral("pupilName"),
                   QStringLiteral("sound")}, this),
      m_library({QStringLiteral("id"), QStringLiteral("author"), QStringLiteral("title"),
                 QStringLiteral("publisher"), QStringLiteral("rentPupilId"), QStringLiteral("rentPupilName"),
                 QStringLiteral("rentDate"), QStringLiteral("available")}, this),
      m_recitals({QStringLiteral("id"), QStringLiteral("description"), QStringLiteral("date"),
                  QStringLiteral("time"), QStringLiteral("location"), QStringLiteral("organizer"),
                  QStringLiteral("accompanist"), QStringLiteral("state"), QStringLiteral("stateName")}, this),
      m_archive({QStringLiteral("id"), QStringLiteral("forename"), QStringLiteral("surname"),
                 QStringLiteral("name")}, this)
{
    m_ready = m_database.open();
    if (!m_ready)
        setError(m_database.lastError());
    else {
        importLegacySettings();
        refreshAll();
    }
    emit readyChanged();
}

void AppController::setError(const QString &message)
{
    if (m_lastError == message)
        return;
    m_lastError = message;
    emit lastErrorChanged();
}

void AppController::clearError()
{
    setError({});
}

namespace {
QString pathForUrl(const QUrl &url)
{
    return url.isLocalFile() ? url.toLocalFile() : url.toString(QUrl::FullyEncoded);
}

bool streamFile(const QString &sourcePath, const QString &destinationPath, QString *error)
{
    QFile source(sourcePath);
    if (!source.open(QIODevice::ReadOnly)) {
        if (error) *error = source.errorString();
        return false;
    }
    QFile destination(destinationPath);
    if (!destination.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (error) *error = destination.errorString();
        return false;
    }
    QByteArray buffer(256 * 1024, Qt::Uninitialized);
    while (!source.atEnd()) {
        const qint64 read = source.read(buffer.data(), buffer.size());
        if (read < 0) {
            if (error) *error = source.errorString();
            return false;
        }
        if (read > 0 && destination.write(buffer.constData(), read) != read) {
            if (error) *error = destination.errorString();
            return false;
        }
    }
    if (!destination.flush()) {
        if (error) *error = destination.errorString();
        return false;
    }
    return true;
}

QList<QStringList> parseCsvText(const QString &text, QChar delimiter)
{
    QList<QStringList> rows;
    QStringList row;
    QString field;
    bool quoted = false;
    for (qsizetype i = 0; i < text.size(); ++i) {
        const QChar ch = text.at(i);
        if (quoted) {
            if (ch == QLatin1Char('"')) {
                if (i + 1 < text.size() && text.at(i + 1) == QLatin1Char('"')) {
                    field += QLatin1Char('"');
                    ++i;
                } else {
                    quoted = false;
                }
            } else {
                field += ch;
            }
            continue;
        }
        if (ch == QLatin1Char('"') && field.isEmpty()) {
            quoted = true;
        } else if (ch == delimiter) {
            row.push_back(field);
            field.clear();
        } else if (ch == QLatin1Char('\n')) {
            if (field.endsWith(QLatin1Char('\r')))
                field.chop(1);
            row.push_back(field);
            field.clear();
            if (!(row.size() == 1 && row.constFirst().isEmpty()))
                rows.push_back(row);
            row.clear();
        } else {
            field += ch;
        }
    }
    if (!field.isEmpty() || !row.isEmpty()) {
        row.push_back(field);
        rows.push_back(row);
    }
    return rows;
}

QString decodeCsv(const QByteArray &bytes, const QString &encoding)
{
    if (encoding.compare(QStringLiteral("Latin-1"), Qt::CaseInsensitive) == 0
        || encoding.compare(QStringLiteral("Latin1"), Qt::CaseInsensitive) == 0)
        return QString::fromLatin1(bytes);
    QByteArray clean = bytes;
    if (clean.startsWith("\xEF\xBB\xBF"))
        clean.remove(0, 3);
    return QString::fromUtf8(clean);
}

QChar detectCsvDelimiter(const QString &text)
{
    const QString firstLine = text.section(QLatin1Char('\n'), 0, 0);
    int commas = 0;
    int semicolons = 0;
    bool quoted = false;
    for (qsizetype i = 0; i < firstLine.size(); ++i) {
        const QChar ch = firstLine.at(i);
        if (ch == QLatin1Char('"')) {
            if (quoted && i + 1 < firstLine.size() && firstLine.at(i + 1) == QLatin1Char('"'))
                ++i;
            else
                quoted = !quoted;
        } else if (!quoted && ch == QLatin1Char(',')) {
            ++commas;
        } else if (!quoted && ch == QLatin1Char(';')) {
            ++semicolons;
        }
    }
    return semicolons > commas ? QLatin1Char(';') : QLatin1Char(',');
}

QString csvValue(const QStringList &row, const QVariantMap &mapping, const QString &field)
{
    const int column = mapping.value(field, -1).toInt();
    return column >= 0 && column < row.size() ? row.at(column).trimmed() : QString{};
}
}

bool AppController::exportBackup(const QUrl &destination)
{
    const QString target = pathForUrl(destination);
    if (target.isEmpty()) {
        setError(tr("No backup destination was selected."));
        return false;
    }
    if (!m_database.checkpoint()) {
        setError(m_database.lastError());
        return false;
    }
    QString error;
    if (!streamFile(m_database.databasePath(), target, &error)) {
        setError(tr("Could not write backup: %1").arg(error));
        return false;
    }
    clearError();
    return true;
}

bool AppController::restoreBackup(const QUrl &source)
{
    const QString sourceName = pathForUrl(source);
    if (sourceName.isEmpty()) {
        setError(tr("No backup file was selected."));
        return false;
    }

    // A content:// URI cannot be renamed/copied with QFile on Android, but it
    // can be opened after the user grants access through the native picker.
    // Stream it into app-private storage before validating/restoring it.
    QTemporaryFile temporary(QDir(QFileInfo(m_database.databasePath()).absolutePath())
                                .filePath(QStringLiteral("restore-XXXXXX.db")));
    temporary.setAutoRemove(true);
    if (!temporary.open()) {
        setError(tr("Could not create a temporary restore file."));
        return false;
    }
    const QString stagedPath = temporary.fileName();
    temporary.close();

    QString error;
    if (!streamFile(sourceName, stagedPath, &error)) {
        setError(tr("Could not read backup: %1").arg(error));
        return false;
    }
    if (!m_database.restoreFrom(stagedPath)) {
        setError(m_database.lastError());
        return false;
    }
    m_ready = true;
    refreshAll();
    clearError();
    return true;
}

QVariantMap AppController::previewPupilCsv(const QUrl &source, const QString &encoding) const
{
    QVariantMap result;
    QFile file(pathForUrl(source));
    if (!file.open(QIODevice::ReadOnly)) {
        const_cast<AppController *>(this)->setError(tr("Could not open CSV file: %1").arg(file.errorString()));
        return result;
    }
    const QString text = decodeCsv(file.readAll(), encoding);
    const QChar delimiter = detectCsvDelimiter(text);
    const auto rows = parseCsvText(text, delimiter);
    if (rows.isEmpty()) {
        const_cast<AppController *>(this)->setError(tr("The CSV file is empty."));
        return result;
    }

    QVariantList preview;
    for (int i = 1; i < rows.size() && i <= 5; ++i) {
        QVariantList cells;
        for (const QString &cell : rows.at(i))
            cells.push_back(cell);
        preview.push_back(cells);
    }
    result.insert(QStringLiteral("headers"), rows.constFirst());
    result.insert(QStringLiteral("preview"), preview);
    result.insert(QStringLiteral("rowCount"), qMax(0, rows.size() - 1));
    result.insert(QStringLiteral("delimiter"), QString(delimiter));
    return result;
}

int AppController::importPupilCsv(const QUrl &source, const QString &encoding, const QVariantMap &mapping)
{
    QFile file(pathForUrl(source));
    if (!file.open(QIODevice::ReadOnly)) {
        setError(tr("Could not open CSV file: %1").arg(file.errorString()));
        return -1;
    }
    const QString text = decodeCsv(file.readAll(), encoding);
    const QChar delimiter = detectCsvDelimiter(text);
    const auto rows = parseCsvText(text, delimiter);
    if (rows.size() < 2) {
        setError(tr("The CSV file has no data rows."));
        return -1;
    }

    QSqlDatabase &db = m_database.database();
    if (!db.transaction()) {
        setError(db.lastError().text());
        return -1;
    }
    int imported = 0;
    for (int i = 1; i < rows.size(); ++i) {
        const QStringList &row = rows.at(i);
        const QString forename = csvValue(row, mapping, QStringLiteral("forename"));
        const QString surname = csvValue(row, mapping, QStringLiteral("surname"));
        if (forename.isEmpty() && surname.isEmpty())
            continue;

        QString birthday = csvValue(row, mapping, QStringLiteral("birthday"));
        if (!birthday.isEmpty()) {
            QDate date = QDate::fromString(birthday, Qt::ISODate);
            if (!date.isValid())
                date = QDate::fromString(birthday, QStringLiteral("dd.MM.yyyy"));
            if (!date.isValid())
                date = QDate::fromString(birthday, QStringLiteral("MM/dd/yyyy"));
            birthday = date.isValid() ? date.toString(Qt::ISODate) : QString{};
        }

        const QString street = csvValue(row, mapping, QStringLiteral("street"));
        const QString zip = csvValue(row, mapping, QStringLiteral("zip"));
        const QString city = csvValue(row, mapping, QStringLiteral("city"));
        QStringList addressParts;
        if (!street.isEmpty())
            addressParts << street;
        const QString zipCity = QStringLiteral("%1 %2").arg(zip, city).trimmed();
        if (!zipCity.isEmpty())
            addressParts << zipCity;

        if (insert(QStringLiteral(
            "INSERT INTO pupil (forename,surname,birthday,firstlessondate,address,email,telefon,handy) "
            "VALUES (?,?,?,?,?,?,?,?)"),
            {forename, surname, birthday, isoToday(), addressParts.join(QStringLiteral(", ")),
             csvValue(row, mapping, QStringLiteral("email")),
             csvValue(row, mapping, QStringLiteral("phone")),
             csvValue(row, mapping, QStringLiteral("mobile"))}) < 0) {
            db.rollback();
            return -1;
        }
        ++imported;
    }
    if (!db.commit()) {
        setError(db.lastError().text());
        return -1;
    }
    refreshPupils();
    refreshLessons();
    emit dataChanged();
    return imported;
}

QVector<QVariantMap> AppController::selectRows(const QString &sql, const QVariantList &binds) const
{
    QVector<QVariantMap> rows;
    if (!m_ready)
        return rows;

    QSqlQuery query(m_database.database());
    if (!query.prepare(sql))
        return rows;
    for (const QVariant &bind : binds)
        query.addBindValue(bind);
    if (!query.exec()) {
        const_cast<AppController *>(this)->setError(query.lastError().text());
        return rows;
    }

    const QSqlRecord record = query.record();
    while (query.next()) {
        QVariantMap row;
        for (int i = 0; i < record.count(); ++i)
            row.insert(record.fieldName(i), query.value(i));
        rows.push_back(std::move(row));
    }
    return rows;
}

QVariantMap AppController::selectOne(const QString &sql, const QVariantList &binds) const
{
    const auto rows = selectRows(sql, binds);
    return rows.isEmpty() ? QVariantMap{} : rows.constFirst();
}

bool AppController::execute(const QString &sql, const QVariantList &binds)
{
    if (!m_ready)
        return false;
    QSqlQuery query(m_database.database());
    query.prepare(sql);
    for (const QVariant &bind : binds)
        query.addBindValue(bind);
    if (!query.exec()) {
        setError(query.lastError().text());
        return false;
    }
    clearError();
    return true;
}

qint64 AppController::insert(const QString &sql, const QVariantList &binds)
{
    if (!m_ready)
        return -1;
    QSqlQuery query(m_database.database());
    query.prepare(sql);
    for (const QVariant &bind : binds)
        query.addBindValue(bind);
    if (!query.exec()) {
        setError(query.lastError().text());
        return -1;
    }
    clearError();
    return query.lastInsertId().toLongLong();
}

void AppController::setPupilFilter(const QString &value)
{
    if (m_pupilFilter == value)
        return;
    m_pupilFilter = value;
    emit pupilFilterChanged();
    refreshPupils();
}

QString AppController::dayName(int day)
{
    // Do not cache translated strings here: the UI language can change while
    // the application is running. Evaluate tr() on every refresh instead.
    const QStringList names = {
        tr("Monday"), tr("Tuesday"), tr("Wednesday"), tr("Thursday"),
        tr("Friday"), tr("Saturday"), tr("Sunday")
    };
    return day >= 0 && day < names.size() ? names.at(day) : tr("Irregular");
}

QString AppController::lessonTypeName(int type)
{
    switch (type) {
    case 1: return tr("Individual lesson");
    case 2: return tr("Group lesson");
    case 3: return tr("Ensemble lesson");
    default: return tr("Lesson");
    }
}

QString AppController::recitalStateName(int state)
{
    switch (state) {
    case 0: return tr("Planned");
    case 1: return tr("Done");
    default: return tr("Unknown");
    }
}

QString AppController::reminderModeName(int mode)
{
    switch (mode) {
    case 0: return tr("At application start");
    case 1: return tr("Every lesson");
    case 2: return tr("Specific pupil");
    default: return tr("Reminder");
    }
}

void AppController::refreshAll()
{
    if (!m_ready)
        return;
    refreshPupils();
    refreshLessons();
    refreshReminders();
    refreshLibrary();
    refreshRecitals();
    refreshArchive();
    emit dataChanged();
}

void AppController::refreshPupils()
{
    QString sql = QStringLiteral(
        "SELECT pupilid AS id, COALESCE(forename,'') AS forename, COALESCE(surname,'') AS surname, "
        "TRIM(COALESCE(surname,'') || ', ' || COALESCE(forename,''), ', ') AS name, "
        "COALESCE(instrumenttype,'') AS instrument, COALESCE(email,'') AS email, "
        "COALESCE(handy, telefon, '') AS phone, COALESCE(birthday,'') AS birthday "
        "FROM pupil");
    QVariantList binds;
    if (!m_pupilFilter.trimmed().isEmpty()) {
        sql += QStringLiteral(" WHERE forename LIKE ? OR surname LIKE ? OR instrumenttype LIKE ?");
        const QString pattern = QStringLiteral("%%1%").arg(m_pupilFilter.trimmed());
        binds << pattern << pattern << pattern;
    }
    sql += QStringLiteral(" ORDER BY surname COLLATE NOCASE, forename COLLATE NOCASE");
    m_pupils.setRows(selectRows(sql, binds));
}

void AppController::refreshLessons()
{
    auto rows = selectRows(QStringLiteral(
        "SELECT l.lessonid AS id, COALESCE(l.lessonname,'') AS name, l.type AS type, "
        "l.lessonday AS day, COALESCE(l.lessonstarttime,'') AS start, COALESCE(l.lessonstoptime,'') AS stop, "
        "COALESCE(l.lessonlocation,'') AS location, COALESCE(l.unsteadylesson,0) AS unsteady, "
        "COALESCE(GROUP_CONCAT(TRIM(p.forename || ' ' || p.surname), ', '), '') AS pupilNames "
        "FROM lesson l LEFT JOIN pupilatlesson pal ON pal.lessonid=l.lessonid AND pal.stopdate > date('now') "
        "LEFT JOIN pupil p ON p.pupilid=pal.pupilid WHERE l.state=1 "
        "GROUP BY l.lessonid ORDER BY CASE WHEN l.unsteadylesson=1 THEN 8 ELSE COALESCE(l.lessonday,8) END, l.lessonstarttime, l.lessonname"));
    for (auto &row : rows) {
        row.insert(QStringLiteral("typeName"), lessonTypeName(row.value(QStringLiteral("type")).toInt()));
        row.insert(QStringLiteral("dayName"), row.value(QStringLiteral("unsteady")).toInt()
                       ? tr("Irregular") : dayName(row.value(QStringLiteral("day")).toInt()));
    }
    m_lessons.setRows(std::move(rows));
}

void AppController::refreshReminders()
{
    auto rows = selectRows(QStringLiteral(
        "SELECT r.reminderid AS id, COALESCE(r.desc,'') AS description, COALESCE(r.mode,0) AS mode, "
        "COALESCE(r.pupilid,-1) AS pupilId, COALESCE(TRIM(p.forename || ' ' || p.surname),'') AS pupilName, "
        "COALESCE(r.notificationsound,0) AS sound FROM reminder r "
        "LEFT JOIN pupil p ON p.pupilid=r.pupilid ORDER BY r.reminderid DESC"));
    for (auto &row : rows)
        row.insert(QStringLiteral("modeName"), reminderModeName(row.value(QStringLiteral("mode")).toInt()));
    m_reminders.setRows(std::move(rows));
}

void AppController::refreshLibrary()
{
    auto rows = selectRows(QStringLiteral(
        "SELECT sml.smlid AS id, COALESCE(a.author,'') AS author, COALESCE(sml.title,'') AS title, "
        "COALESCE(pub.publisher,'') AS publisher, COALESCE(sml.rentpupilid,-1) AS rentPupilId, "
        "COALESCE(TRIM(p.forename || ' ' || p.surname),'') AS rentPupilName, "
        "COALESCE(sml.lastrentdate,'') AS rentDate "
        "FROM sheetmusiclibrary sml LEFT JOIN smlauthor a ON a.smlauthorid=sml.author "
        "LEFT JOIN smlpublisher pub ON pub.smlpublisherid=sml.publisher "
        "LEFT JOIN pupil p ON p.pupilid=sml.rentpupilid "
        "ORDER BY a.author COLLATE NOCASE, sml.title COLLATE NOCASE"));
    for (auto &row : rows)
        row.insert(QStringLiteral("available"), row.value(QStringLiteral("rentPupilId")).toInt() < 0);
    m_library.setRows(std::move(rows));
}

void AppController::refreshRecitals()
{
    auto rows = selectRows(QStringLiteral(
        "SELECT recitalid AS id, COALESCE(desc,'') AS description, COALESCE(date,'') AS date, "
        "COALESCE(time,'') AS time, COALESCE(location,'') AS location, COALESCE(organisator,'') AS organizer, "
        "COALESCE(defaultaccompanist,'') AS accompanist, COALESCE(state,0) AS state "
        "FROM recital ORDER BY date DESC, time DESC"));
    for (auto &row : rows)
        row.insert(QStringLiteral("stateName"), recitalStateName(row.value(QStringLiteral("state")).toInt()));
    m_recitals.setRows(std::move(rows));
}

void AppController::refreshArchive()
{
    m_archive.setRows(selectRows(QStringLiteral(
        "SELECT pupilid AS id, COALESCE(forename,'') AS forename, COALESCE(surname,'') AS surname, "
        "TRIM(COALESCE(surname,'') || ', ' || COALESCE(forename,''), ', ') AS name "
        "FROM pupilarchive ORDER BY surname COLLATE NOCASE, forename COLLATE NOCASE")));
}

QVariantMap AppController::dashboardStats() const
{
    QVariantMap result;
    const auto one = [this](const QString &sql) -> int {
        return selectOne(sql).value(QStringLiteral("n")).toInt();
    };
    const int today = QDate::currentDate().dayOfWeek() - 1;
    result.insert(QStringLiteral("todayLessons"), selectOne(QStringLiteral(
        "SELECT COUNT(*) AS n FROM lesson WHERE state=1 AND unsteadylesson=0 AND lessonday=?"), {today})
        .value(QStringLiteral("n")).toInt());
    result.insert(QStringLiteral("todayPupils"), selectOne(QStringLiteral(
        "SELECT COUNT(DISTINCT pal.pupilid) AS n FROM lesson l "
        "JOIN pupilatlesson pal ON pal.lessonid=l.lessonid AND pal.stopdate > date('now') "
        "WHERE l.state=1 AND l.unsteadylesson=0 AND l.lessonday=?"), {today})
        .value(QStringLiteral("n")).toInt());
    result.insert(QStringLiteral("pupils"), one(QStringLiteral("SELECT COUNT(*) AS n FROM pupil")));
    result.insert(QStringLiteral("lessons"), one(QStringLiteral("SELECT COUNT(*) AS n FROM lesson WHERE state=1")));
    result.insert(QStringLiteral("reminders"), one(QStringLiteral("SELECT COUNT(*) AS n FROM reminder")));
    result.insert(QStringLiteral("loanedMusic"), one(QStringLiteral("SELECT COUNT(*) AS n FROM sheetmusiclibrary WHERE rentpupilid >= 0")));
    result.insert(QStringLiteral("recitals"), one(QStringLiteral("SELECT COUNT(*) AS n FROM recital WHERE state = 0")));
    return result;
}

QVariantList AppController::todayLessons() const
{
    QVariantList result;
    const int day = QDate::currentDate().dayOfWeek() - 1;
    const auto rows = selectRows(QStringLiteral(
        "SELECT l.lessonid AS id, l.lessonname AS name, l.lessonstarttime AS start, l.lessonstoptime AS stop, "
        "l.lessonlocation AS location, COALESCE(GROUP_CONCAT(TRIM(p.forename || ' ' || p.surname), ', '),'') AS pupils "
        "FROM lesson l LEFT JOIN pupilatlesson pal ON pal.lessonid=l.lessonid AND pal.stopdate > date('now') "
        "LEFT JOIN pupil p ON p.pupilid=pal.pupilid "
        "WHERE l.state=1 AND l.unsteadylesson=0 AND l.lessonday=? GROUP BY l.lessonid ORDER BY l.lessonstarttime"), {day});
    for (const auto &row : rows)
        result.push_back(row);
    return result;
}

QVariantList AppController::scheduleForDay(int day) const
{
    QVariantList result;
    const auto rows = selectRows(QStringLiteral(
        "SELECT l.lessonid AS id, COALESCE(l.lessonname,'') AS name, COALESCE(l.type,1) AS type, "
        "COALESCE(l.lessonstarttime,'') AS start, COALESCE(l.lessonstoptime,'') AS stop, "
        "COALESCE(l.lessonlocation,'') AS location "
        "FROM lesson l WHERE l.state=1 AND l.unsteadylesson=0 AND l.lessonday=? "
        "ORDER BY l.lessonstarttime,l.lessonname"), {day});
    for (QVariantMap row : rows) {
        const auto memberships = selectRows(QStringLiteral(
            "SELECT pal.palid AS palId, p.pupilid AS pupilId, "
            "TRIM(COALESCE(p.forename,'') || ' ' || COALESCE(p.surname,'')) AS pupilName "
            "FROM pupilatlesson pal JOIN pupil p ON p.pupilid=pal.pupilid "
            "WHERE pal.lessonid=? AND pal.stopdate > date('now') "
            "ORDER BY p.surname,p.forename,p.pupilid"), {row.value(QStringLiteral("id"))});
        QVariantList memberList;
        QStringList pupilNames;
        for (const QVariantMap &membership : memberships) {
            memberList << membership;
            pupilNames << membership.value(QStringLiteral("pupilName")).toString();
        }
        row.insert(QStringLiteral("memberships"), memberList);
        row.insert(QStringLiteral("pupils"), pupilNames.join(QStringLiteral(", ")));
        row.insert(QStringLiteral("typeName"), lessonTypeName(row.value(QStringLiteral("type")).toInt()));
        result.push_back(row);
    }
    return result;
}

QString AppController::timetableDocumentHtml() const
{
    const QStringList days = {tr("Monday"), tr("Tuesday"), tr("Wednesday"), tr("Thursday"),
                              tr("Friday"), tr("Saturday"), tr("Sunday"), tr("irregular")};
    QString rowsHtml;
    for (int day = 0; day < 8; ++day) {
        QVector<QVariantMap> lessons;
        if (day < 7) {
            lessons = selectRows(QStringLiteral(
                "SELECT lessonid AS id, COALESCE(lessonname,'') AS name, COALESCE(lessonstarttime,'') AS start, "
                "COALESCE(lessonstoptime,'') AS stop FROM lesson WHERE state=1 AND lessonday=? ORDER BY lessonstarttime ASC"), {day});
        } else {
            lessons = selectRows(QStringLiteral(
                "SELECT lessonid AS id, COALESCE(lessonname,'') AS name FROM lesson WHERE state=1 AND unsteadylesson=1"));
        }
        if (lessons.isEmpty())
            continue;
        rowsHtml += QStringLiteral("<tr><td colspan='3'><h2>%1</h2></td></tr>").arg(days.at(day).toHtmlEscaped());
        for (const QVariantMap &lesson : lessons) {
            const auto pupils = selectRows(QStringLiteral(
                "SELECT COALESCE(p.surname,'') AS surname, COALESCE(p.forename,'') AS forename "
                "FROM pupilatlesson pal, pupil p WHERE pal.lessonid=? AND p.pupilid=pal.pupilid "
                "AND pal.stopdate > date('now') ORDER BY p.surname ASC"), {lesson.value(QStringLiteral("id"))});
            QStringList names;
            for (const QVariantMap &pupil : pupils)
                names << QStringLiteral("%1, %2").arg(pupil.value(QStringLiteral("surname")).toString().toHtmlEscaped(),
                                                      pupil.value(QStringLiteral("forename")).toString().toHtmlEscaped());
            if (day < 7) {
                rowsHtml += QStringLiteral("<tr><td><b>%1 - %2</b></td><td>%3</td><td>%4</td></tr>")
                    .arg(htmlCell(lesson.value(QStringLiteral("start"))), htmlCell(lesson.value(QStringLiteral("stop"))),
                         htmlCell(lesson.value(QStringLiteral("name"))), names.join(QStringLiteral("<br>")));
            } else {
                rowsHtml += QStringLiteral("<tr><td colspan='2'><b>%1</b></td><td>%2</td></tr>")
                    .arg(htmlCell(lesson.value(QStringLiteral("name"))), names.join(QStringLiteral("<br>")));
            }
        }
    }
    const QString title = QStringLiteral("Qupil %1 - %2")
        .arg(QCoreApplication::applicationVersion().toHtmlEscaped(), tr("Timetable").toHtmlEscaped());
    const QString body = QStringLiteral("<p class='meta'><b>%1</b> %2</p><table><tr><th>%3</th><th>%4</th><th>%5</th></tr>%6</table>")
        .arg(tr("Status: ").toHtmlEscaped(), QDate::currentDate().toString(QStringLiteral("dd.MM.yyyy")),
             tr("Time").toHtmlEscaped(), tr("Lesson").toHtmlEscaped(), tr("Pupil").toHtmlEscaped(), rowsHtml);
    return documentFrame(title, body);
}

QString AppController::dayOverviewDocumentHtml(int day, int noteCount, int freeSpaceCm) const
{
    day = std::clamp(day, 0, 7);
    noteCount = std::clamp(noteCount, 0, 99);
    freeSpaceCm = std::clamp(freeSpaceCm, 0, 99);

    QString dayString;
    QString tableHead;
    QVector<QVariantMap> lessons;
    if (day < 7) {
        QDate date = QDate::currentDate();
        const int today = date.dayOfWeek() - 1;
        int delta = day - today;
        if (delta < 0) delta += 7;
        date = date.addDays(delta);
        dayString = QLocale().toString(date, QLocale::LongFormat);
        tableHead = QStringLiteral("<tr><th>%1</th><th>%2</th><th>%3</th></tr>")
            .arg(tr("Time").toHtmlEscaped(), tr("Lesson").toHtmlEscaped(), tr("Pupil").toHtmlEscaped());
        lessons = selectRows(QStringLiteral(
            "SELECT lessonid AS id, COALESCE(lessonname,'') AS name, COALESCE(lessonstarttime,'') AS start, "
            "COALESCE(lessonstoptime,'') AS stop FROM lesson WHERE state=1 AND lessonday=? ORDER BY lessonstarttime ASC"), {day});
    } else {
        dayString = tr("irregular dates");
        tableHead = QStringLiteral("<tr><th>%1</th><th>%2</th></tr>")
            .arg(tr("Lesson").toHtmlEscaped(), tr("Pupil").toHtmlEscaped());
        lessons = selectRows(QStringLiteral(
            "SELECT lessonid AS id, COALESCE(lessonname,'') AS name FROM lesson WHERE state=1 AND unsteadylesson=1"));
    }

    QString rowsHtml;
    for (const QVariantMap &lesson : lessons) {
        const auto pupils = selectRows(QStringLiteral(
            "SELECT pal.palid AS palId, COALESCE(p.forename,'') AS forename, COALESCE(p.surname,'') AS surname "
            "FROM pupilatlesson pal, pupil p WHERE pal.lessonid=? AND p.pupilid=pal.pupilid "
            "AND pal.stopdate > date('now') ORDER BY p.surname ASC"), {lesson.value(QStringLiteral("id"))});
        QStringList names;
        QList<int> palIds;
        for (const QVariantMap &pupil : pupils) {
            palIds << pupil.value(QStringLiteral("palId")).toInt();
            names << QStringLiteral("%1, %2").arg(pupil.value(QStringLiteral("surname")).toString().toHtmlEscaped(),
                                                  pupil.value(QStringLiteral("forename")).toString().toHtmlEscaped());
        }
        if (day < 7)
            rowsHtml += QStringLiteral("<tr><td><h3>%1 - %2</h3></td><td><h3>%3</h3></td><td>%4</td></tr>")
                .arg(htmlCell(lesson.value(QStringLiteral("start"))), htmlCell(lesson.value(QStringLiteral("stop"))),
                     htmlCell(lesson.value(QStringLiteral("name"))), names.join(QStringLiteral("<br>")));
        else
            rowsHtml += QStringLiteral("<tr><td><h3>%1</h3></td><td>%2</td></tr>")
                .arg(htmlCell(lesson.value(QStringLiteral("name"))), names.join(QStringLiteral("<br>")));

        rowsHtml += day < 7 ? QStringLiteral("<tr><td colspan='3'>") : QStringLiteral("<tr><td colspan='2'>");
        if (freeSpaceCm > 0)
            rowsHtml += QStringLiteral("<div style='height:%1mm;border-bottom:1px solid #999;margin-bottom:2mm'></div>")
                .arg(freeSpaceCm * 10);

        const bool shared = settingValue(QStringLiteral("saveNotesPiecesForAllPupils"), true).toBool();
        if (noteCount > 0 && !palIds.isEmpty()) {
            rowsHtml += QStringLiteral("<table class='noborder notes'>");
            if (shared) {
                const auto notes = selectRows(QStringLiteral(
                    "SELECT strftime('%d.%m.%Y',n.date) AS date, COALESCE(n.content,'') AS content "
                    "FROM note n, pupilatlesson pal WHERE pal.palid=? AND pal.palid=n.palid "
                    "AND pal.startdate <= n.date AND pal.stopdate >= n.date ORDER BY n.date DESC LIMIT ?"),
                    {palIds.last(), noteCount});
                for (const QVariantMap &note : notes)
                    rowsHtml += QStringLiteral("<tr><td><u>%1</u>:</td><td>%2</td></tr>")
                        .arg(htmlCell(note.value(QStringLiteral("date"))), note.value(QStringLiteral("content")).toString());
            } else {
                for (int i = 0; i < palIds.size(); ++i) {
                    const auto notes = selectRows(QStringLiteral(
                        "SELECT strftime('%d.%m.%Y',n.date) AS date, COALESCE(n.content,'') AS content "
                        "FROM note n, pupilatlesson pal WHERE pal.palid=? AND pal.palid=n.palid "
                        "AND pal.startdate <= n.date AND pal.stopdate >= n.date ORDER BY n.date DESC LIMIT ?"),
                        {palIds.at(i), noteCount});
                    for (const QVariantMap &note : notes)
                        rowsHtml += QStringLiteral("<tr><td><u>%1</u> (<i>%2</i>):</td><td>%3</td></tr>")
                            .arg(htmlCell(note.value(QStringLiteral("date"))), names.at(i), note.value(QStringLiteral("content")).toString());
                }
            }
            rowsHtml += QStringLiteral("</table>");
        }
        rowsHtml += QStringLiteral("</td></tr>");
    }

    const QString title = QStringLiteral("Qupil %1 - %2 - %3")
        .arg(QCoreApplication::applicationVersion().toHtmlEscaped(), tr("Daily schedule").toHtmlEscaped(), dayString.toHtmlEscaped());
    return documentFrame(title, QStringLiteral("<table>%1%2</table>").arg(tableHead, rowsHtml));
}

QString AppController::recitalDocumentHtml(int recitalId) const
{
    // QUPIL_RECITAL_DOCUMENT_LAYOUT_V1
    const QVariantMap r = selectOne(QStringLiteral(
        "SELECT COALESCE(desc,'') AS description, COALESCE(date,'') AS date, COALESCE(time,'') AS time, "
        "COALESCE(location,'') AS location, COALESCE(organisator,'') AS organizer, "
        "COALESCE(defaultaccompanist,'') AS accompanist FROM recital WHERE recitalid=?"), {recitalId});
    if (r.isEmpty())
        return {};

    struct ProgramRow {
        int sorting = 0;
        QString composer;
        QString title;
        QString genre;
        QString duration;
        QString musician;
        int minutes = 0;
    };

    QVector<ProgramRow> program;

    const auto internal = selectRows(QStringLiteral(
        "SELECT l.lessonid AS lessonId, pc.composer AS composer, p.title AS title, p.genre AS genre, "
        "COALESCE(p.duration,0) AS duration, COALESCE(pu.instrumenttype,'') AS instrument, "
        "CASE WHEN date(pu.birthday, '+' || (strftime('%Y','now') - strftime('%Y',pu.birthday)) || ' years') <= date('now') "
        "THEN strftime('%Y','now') - strftime('%Y',pu.birthday) "
        "ELSE strftime('%Y','now') - strftime('%Y',pu.birthday) - 1 END AS age, "
        "COALESCE(pu.forename,'') AS forename, COALESCE(pu.surname,'') AS surname, par.sorting AS sorting "
        "FROM pupil pu, piece p, lesson l, pupilatlesson pal, piececomposer pc, pieceatrecital par "
        "WHERE pal.palid=p.palid AND p.piececomposerid=pc.piececomposerid AND pal.lessonid=l.lessonid "
        "AND pal.pupilid=pu.pupilid AND pal.stopdate > date('now') AND par.pieceid=p.pieceid "
        "AND par.ifexternalpiece=0 AND par.recitalid=? ORDER BY par.sorting ASC, age ASC"), {recitalId});

    for (const QVariantMap &row : internal) {
        ProgramRow pr;
        pr.sorting = row.value(QStringLiteral("sorting")).toInt();
        pr.composer = row.value(QStringLiteral("composer")).toString();
        pr.title = row.value(QStringLiteral("title")).toString();
        pr.genre = row.value(QStringLiteral("genre")).toString();
        pr.minutes = row.value(QStringLiteral("duration")).toInt();
        pr.duration = QStringLiteral("%1 %2").arg(pr.minutes).arg(tr("Min."));

        const int groupCount = selectOne(QStringLiteral(
            "SELECT COUNT(*) AS n FROM piece p, lesson l, pupilatlesson pal WHERE pal.palid=p.palid "
            "AND pal.lessonid=l.lessonid AND pal.stopdate > date('now') AND l.lessonid=? AND p.title=?"),
            {row.value(QStringLiteral("lessonId")), pr.title})
            .value(QStringLiteral("n")).toInt();

        if (groupCount > 1) {
            const auto members = selectRows(QStringLiteral(
                "SELECT COALESCE(pu.forename,'') AS forename, COALESCE(pu.surname,'') AS surname, "
                "COALESCE(pu.instrumenttype,'') AS instrument, "
                "CASE WHEN date(pu.birthday, '+' || (strftime('%Y','now') - strftime('%Y',pu.birthday)) || ' years') <= date('now') "
                "THEN strftime('%Y','now') - strftime('%Y',pu.birthday) "
                "ELSE strftime('%Y','now') - strftime('%Y',pu.birthday) - 1 END AS age "
                "FROM pupil pu, pupilatlesson pal WHERE pal.pupilid=pu.pupilid AND pal.lessonid=? "
                "AND pal.stopdate > date('now') ORDER BY age ASC"),
                {row.value(QStringLiteral("lessonId"))});

            QStringList people;
            for (const QVariantMap &m : members) {
                people << QStringLiteral("%1, %2 (%3) - %4")
                    .arg(m.value(QStringLiteral("surname")).toString().toHtmlEscaped(),
                         m.value(QStringLiteral("forename")).toString().toHtmlEscaped(),
                         QString::number(m.value(QStringLiteral("age")).toInt()),
                         m.value(QStringLiteral("instrument")).toString().toHtmlEscaped());
            }
            pr.musician = people.join(QStringLiteral("<br>"));
        } else {
            pr.musician = QStringLiteral("%1, %2 (%3) - %4")
                .arg(row.value(QStringLiteral("surname")).toString().toHtmlEscaped(),
                     row.value(QStringLiteral("forename")).toString().toHtmlEscaped(),
                     QString::number(row.value(QStringLiteral("age")).toInt()),
                     row.value(QStringLiteral("instrument")).toString().toHtmlEscaped());
        }

        program.push_back(pr);
    }

    const auto external = selectRows(QStringLiteral(
        "SELECT par.sorting AS sorting, COALESCE(erp.composer,'') AS composer, COALESCE(erp.title,'') AS title, "
        "COALESCE(erp.genre,'') AS genre, COALESCE(erp.duration,0) AS duration, COALESCE(erp.musician,'') AS musician "
        "FROM externalrecitalpiece erp, pieceatrecital par "
        "WHERE par.pieceid=erp.erpid AND par.ifexternalpiece=1 AND par.recitalid=? "
        "ORDER BY par.sorting ASC"), {recitalId});

    for (const QVariantMap &row : external) {
        ProgramRow pr;
        pr.sorting = row.value(QStringLiteral("sorting")).toInt();
        pr.composer = row.value(QStringLiteral("composer")).toString();
        pr.title = row.value(QStringLiteral("title")).toString();
        pr.genre = row.value(QStringLiteral("genre")).toString();
        pr.minutes = row.value(QStringLiteral("duration")).toInt();
        pr.duration = QStringLiteral("%1 %2").arg(pr.minutes).arg(tr("Min."));
        pr.musician = row.value(QStringLiteral("musician")).toString().toHtmlEscaped();
        program.push_back(pr);
    }

    std::sort(program.begin(), program.end(),
              [](const ProgramRow &a, const ProgramRow &b) { return a.sorting < b.sorting; });

    QString rows;
    int pure = 0;
    for (const ProgramRow &pr : program) {
        pure += pr.minutes;
        rows += QStringLiteral(
            "<tr>"
            "<td valign='middle' style='padding:3px'>%1</td>"
            "<td valign='middle' style='padding:3px'>%2</td>"
            "<td valign='middle' style='padding:3px'>%3</td>"
            "<td valign='middle' style='padding:3px'>%4</td>"
            "<td valign='middle' style='padding:3px'>%5</td>"
            "</tr>")
            .arg(pr.composer.toHtmlEscaped(),
                 pr.title.toHtmlEscaped(),
                 pr.genre.toHtmlEscaped(),
                 pr.duration.toHtmlEscaped(),
                 pr.musician);
    }

    const int total = program.isEmpty()
        ? 0
        : settingValue(QStringLiteral("recitalModerationDuration"), 0).toInt()
          + pure
          + int(program.size())
                * settingValue(QStringLiteral("recitalBetweenPiecesDuration"), 0).toInt();

    const QString date = formattedIsoDate(r.value(QStringLiteral("date")).toString()).toHtmlEscaped();
    const QString time = htmlCell(r.value(QStringLiteral("time")));
    const QString location = htmlCell(r.value(QStringLiteral("location")));
    const QString organizer = htmlCell(r.value(QStringLiteral("organizer")));
    const QString accompanist = htmlCell(r.value(QStringLiteral("accompanist")));

    // QUPIL_RECITAL_DOCUMENT_LAYOUT_V3
    // Verhaeltnisse nach dem 1.4.1-Programmdokument.
    // QString::arg() braucht Prozentzeichen nicht als %% escaped.
    QString body = QStringLiteral(
        "<table class='recital-meta' width='100%' border='0' cellspacing='0' cellpadding='0'>"
        "<tr>"
        "<td width='23%' valign='middle' style='padding:3px'><nobr><b>%1:</b>&nbsp;%2</nobr></td>"
        "<td width='20%' valign='middle' style='padding:3px'><nobr><b>%3:</b>&nbsp;%4</nobr></td>"
        "<td width='17%' valign='middle' style='padding:3px'><nobr><b>%5:</b>&nbsp;%6</nobr></td>"
        "<td width='23%' valign='middle' style='padding:3px'><nobr><b>%7:</b>&nbsp;%8</nobr></td>"
        "<td width='17%' valign='middle' style='padding:3px'><nobr><b>%9:</b>&nbsp;%10</nobr></td>"
        "</tr>"
        "</table>"
        "<p style='margin-top:8px;margin-bottom:0px'></p>")
        .arg(tr("Date").toHtmlEscaped(), date,
             tr("Time").toHtmlEscaped(), time,
             tr("Location").toHtmlEscaped(), location,
             tr("Organiser").toHtmlEscaped(), organizer,
             tr("Accompanist").toHtmlEscaped(), accompanist);

    body += QStringLiteral(
        "<table class='recital-program' width='100%' border='1' cellspacing='0' cellpadding='0'>"
        "<tr>"
        "<th width='22%' align='center' valign='middle' bgcolor='#ffffff' style='padding:3px'>%1</th>"
        "<th width='30%' align='center' valign='middle' bgcolor='#ffffff' style='padding:3px'>%2</th>"
        "<th width='11%' align='center' valign='middle' bgcolor='#ffffff' style='padding:3px'>%3</th>"
        "<th width='8%' align='center' valign='middle' bgcolor='#ffffff' style='padding:3px'>%4</th>"
        "<th width='29%' align='center' valign='middle' bgcolor='#ffffff' style='padding:3px'>%5</th>"
        "</tr>%6"
        "</table>")
        .arg(tr("Composer").toHtmlEscaped(),
             tr("Music Piece / Movements").toHtmlEscaped(),
             tr("Genre").toHtmlEscaped(),
             tr("Duration").toHtmlEscaped(),
             tr("Musician (Age) - Instrument").toHtmlEscaped(),
             rows);

    body += QStringLiteral(
        "<p style='margin-top:14px;margin-bottom:3px'><b>%1:</b> %2 %3</p>"
        "<p style='margin-top:3px;margin-bottom:0px'><b>%4:</b> %5 %3</p>")
        .arg(tr("Pure playing time").toHtmlEscaped(),
             QString::number(pure),
             tr("Min.").toHtmlEscaped(),
             tr("Estimated total duration").toHtmlEscaped(),
             QString::number(total));

    const QString title = tr("Program for")
        + QStringLiteral(" \"")
        + r.value(QStringLiteral("description")).toString()
        + QStringLiteral("\"");

    const QString css = documentCss() + QStringLiteral(
        "body{font-size:9pt;background-color:#ffffff;color:#000000;}"
        ".recital-title{font-size:14pt;font-weight:700;margin-top:0px;margin-bottom:30px;}"
        ".recital-meta td{border-width:0px; background-color:#ffffff ;white-space:nowrap;padding:3px;}"
        ".recital-program{border-collapse:collapse;}"
        ".recital-program th{color:#000000; background-color:#ffffff; font-weight:700;padding:3px;}"
        ".recital-program td{background-color:#ffffff;color:#000000;padding:3px;}"
        ".recital-footer{color:#555555;font-size:8pt;font-style:italic;"
            "margin-top:20px;margin-bottom:0px;}");

    return QStringLiteral(
        "<!doctype html>"
        "<html><head><meta charset='utf-8'><style>%1</style></head>"
        "<body bgcolor='#ffffff'>"
        "<h1 class='recital-title' align='center'>%2</h1>"
        "<table width='100%' height='28' border='0' cellspacing='0' cellpadding='0'>"
        "<tr><td></td></tr></table>"
        "%3"
        "<p class='recital-footer' align='center'>Qupil %4 - %5</p>"
        "</body></html>")
        .arg(css,
             title.toHtmlEscaped(),
             body,
             QCoreApplication::applicationVersion().toHtmlEscaped(),
             QStringLiteral("&copy;2006-%1 - Felix Hammer - qupil.de")
                 .arg(QDate::currentDate().year()));
}

QString AppController::rentalInstrumentDocumentHtml() const
{
    const auto rows = selectRows(QStringLiteral(
        "SELECT (COALESCE(surname,'') || ', ' || COALESCE(forename,'')) AS name, strftime('%d.%m.%Y',birthday) AS birthday, "
        "COALESCE(instrumenttype,'') AS instrument, COALESCE(instrumentsize,'') AS size, COALESCE(rentinstrumentdesc,'') AS description, "
        "COALESCE(ifinstrumentnextsize,0) AS nextSize FROM pupil WHERE instrumenttype IS NOT NULL AND instrumentsize IS NOT NULL AND ifrentinstrument=1"));
    QString tableRows;
    for (const QVariantMap &row: rows)
        tableRows += QStringLiteral("<tr><td>%1</td><td>%2</td><td>%3</td><td>%4</td><td>%5</td><td>%6</td></tr>")
            .arg(htmlCell(row.value(QStringLiteral("name"))),htmlCell(row.value(QStringLiteral("birthday"))),htmlCell(row.value(QStringLiteral("instrument"))),
                 htmlCell(row.value(QStringLiteral("size"))),htmlCell(row.value(QStringLiteral("description"))),
                 row.value(QStringLiteral("nextSize")).toBool()?tr("Yes").toHtmlEscaped():tr("No").toHtmlEscaped());
    const QString title=QStringLiteral("Qupil %1 - %2").arg(QCoreApplication::applicationVersion().toHtmlEscaped(),tr("Rental instrument inventory list").toHtmlEscaped());
    const QString body=QStringLiteral("<h2>%1: %2</h2><table><tr><th>%3</th><th>%4</th><th>%5</th><th>%6</th><th>%7</th><th>%8</th></tr>%9</table>")
        .arg(tr("Date").toHtmlEscaped(),QDate::currentDate().toString(QStringLiteral("dd.MM.yyyy")),tr("Name").toHtmlEscaped(),tr("Birthday").toHtmlEscaped(),
             tr("Instrument").toHtmlEscaped(),tr("Size").toHtmlEscaped(),tr("Description").toHtmlEscaped(),tr("Next size required").toHtmlEscaped(),tableRows);
    return documentFrame(title,body);
}

QUrl AppController::suggestedPdfUrl(const QString &baseName) const
{
    if (baseName.trimmed().isEmpty())
        return QUrl::fromLocalFile(QDir::homePath());
    return QUrl::fromLocalFile(QDir(QDir::homePath()).filePath(safePdfBaseName(baseName)));
}

QString AppController::suggestedPdfFileName(const QString &baseName) const
{
    return safePdfBaseName(baseName);
}

QUrl AppController::pdfUrlInFolder(const QUrl &folder, const QString &baseName) const
{
    QString folderPath = folder.isLocalFile() ? folder.toLocalFile() : QString{};
    if (folderPath.trimmed().isEmpty())
        folderPath = QDir::homePath();

    return QUrl::fromLocalFile(
        QDir(folderPath).filePath(safePdfBaseName(baseName)));
}

bool AppController::exportDocumentPdf(const QString &html, const QUrl &destination,
                                      const QString &title, bool landscape)
{
    clearError();
    QString path = pathForUrl(destination);
    if (path.isEmpty()) {
        setError(tr("No PDF destination was selected."));
        return false;
    }
    if (!path.endsWith(QStringLiteral(".pdf"), Qt::CaseInsensitive))
        path += QStringLiteral(".pdf");
    QString error;
    if (!writeHtmlPdf(html, path, title, landscape, &error)) {
        setError(error);
        return false;
    }
    return true;
}

bool AppController::shareDocumentPdf(const QString &html, const QString &baseName,
                                     const QString &title, bool landscape)
{
    clearError();
    const QString shareDir = QDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation))
        .filePath(QStringLiteral("qupil-share"));
    QDir().mkpath(shareDir);
    const QString filePath = QDir(shareDir).filePath(safePdfBaseName(baseName));
    QString error;
    if (!writeHtmlPdf(html, filePath, title, landscape, &error)) {
        setError(error);
        return false;
    }
    if (!qupilSharePdf(filePath, title, &error)) {
        setError(error.isEmpty() ? tr("The PDF could not be shared.") : error);
        return false;
    }
    return true;
}

#ifdef QUPIL_XDG_PORTAL_PRINTING
namespace {
QString portalHandleToken(const QString &prefix)
{
    QString uuid = QUuid::createUuid().toString(QUuid::WithoutBraces);
    uuid.remove(QLatin1Char('-'));
    return prefix + QLatin1Char('_') + uuid;
}

QString portalRequestPath(const QDBusConnection &bus, const QString &token)
{
    QString sender = bus.baseService();
    if (sender.startsWith(QLatin1Char(':')))
        sender.remove(0, 1);
    sender.replace(QLatin1Char('.'), QLatin1Char('_'));
    return QStringLiteral("/org/freedesktop/portal/desktop/request/%1/%2")
        .arg(sender, token);
}
}
#endif

bool AppController::printDocumentNative(const QString &html, const QString &title,
                                        bool landscape)
{
#ifdef QUPIL_XDG_PORTAL_PRINTING
    // QUPIL_NATIVE_PRINT_DIALOG_V2
    // Plasma's portal backend creates/configures its QPrinter in PreparePrint().
    // Therefore use the documented two-stage flow:
    //   PreparePrint -> Response(token) -> Print(pdf, token).
    // This also gives us an explicit response for cancellation and failures.
    if (m_portalPrintInProgress) {
        qInfo() << "QUPIL_PRINT: print request already in progress";
        return true;
    }

    clearError();

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        setError(tr("The desktop print service is not available."));
        return false;
    }

    const QString printDir = QDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation))
        .filePath(QStringLiteral("qupil-print"));
    if (!QDir().mkpath(printDir)) {
        setError(tr("The temporary print directory could not be created."));
        return false;
    }

    QTemporaryFile temporary(QDir(printDir).filePath(QStringLiteral("qupil-print-XXXXXX.pdf")));
    temporary.setAutoRemove(false);
    if (!temporary.open()) {
        setError(tr("The temporary print file could not be created."));
        return false;
    }
    const QString filePath = temporary.fileName();
    temporary.close();

    QString error;
    if (!writeHtmlPdf(html, filePath, title, landscape, &error)) {
        QFile::remove(filePath);
        setError(error);
        return false;
    }

    m_portalPrintPdfPath = filePath;
    m_portalPrintTitle = title;
    m_portalPrintInProgress = true;

    QVariantMap settings;
    settings.insert(QStringLiteral("orientation"),
                    landscape ? QStringLiteral("landscape") : QStringLiteral("portrait"));
    settings.insert(QStringLiteral("print-pages"), QStringLiteral("all"));

    QVariantMap pageSetup;
    pageSetup.insert(QStringLiteral("PPDName"), QStringLiteral("A4"));
    pageSetup.insert(QStringLiteral("Orientation"),
                     landscape ? QStringLiteral("landscape") : QStringLiteral("portrait"));

    const QString handleToken = portalHandleToken(QStringLiteral("qupil_prepare_print"));
    const QString expectedPath = portalRequestPath(bus, handleToken);

    QVariantMap options;
    options.insert(QStringLiteral("handle_token"), handleToken);
    options.insert(QStringLiteral("modal"), true);
    options.insert(QStringLiteral("supported_output_file_formats"),
                   QStringList{QStringLiteral("pdf")});

    if (!bus.connect(QStringLiteral("org.freedesktop.portal.Desktop"),
                     expectedPath,
                     QStringLiteral("org.freedesktop.portal.Request"),
                     QStringLiteral("Response"),
                     this,
                     SLOT(handlePortalPreparePrintResponse(uint,QVariantMap)))) {
        setError(tr("The system print dialog response could not be monitored."));
        finishPortalPrint();
        return false;
    }

    m_portalPrepareRequestPath = expectedPath;

    QDBusMessage request = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.portal.Desktop"),
        QStringLiteral("/org/freedesktop/portal/desktop"),
        QStringLiteral("org.freedesktop.portal.Print"),
        QStringLiteral("PreparePrint"));
    request << QString{} << title << settings << pageSetup << options;

    const QDBusMessage reply = bus.call(request, QDBus::Block, 15000);
    if (reply.type() == QDBusMessage::ErrorMessage) {
        bus.disconnect(QStringLiteral("org.freedesktop.portal.Desktop"),
                       expectedPath,
                       QStringLiteral("org.freedesktop.portal.Request"),
                       QStringLiteral("Response"),
                       this,
                       SLOT(handlePortalPreparePrintResponse(uint,QVariantMap)));
        setError(tr("The system print dialog could not be opened: %1")
                     .arg(reply.errorMessage()));
        finishPortalPrint();
        return false;
    }
    if (reply.arguments().isEmpty()) {
        setError(tr("The system print dialog returned no request handle."));
        finishPortalPrint();
        return false;
    }

    const QDBusObjectPath handle = qvariant_cast<QDBusObjectPath>(reply.arguments().constFirst());
    if (handle.path().isEmpty()) {
        setError(tr("The system print dialog returned an invalid request handle."));
        finishPortalPrint();
        return false;
    }

    if (handle.path() != expectedPath) {
        bus.disconnect(QStringLiteral("org.freedesktop.portal.Desktop"),
                       expectedPath,
                       QStringLiteral("org.freedesktop.portal.Request"),
                       QStringLiteral("Response"),
                       this,
                       SLOT(handlePortalPreparePrintResponse(uint,QVariantMap)));
        if (!bus.connect(QStringLiteral("org.freedesktop.portal.Desktop"),
                         handle.path(),
                         QStringLiteral("org.freedesktop.portal.Request"),
                         QStringLiteral("Response"),
                         this,
                         SLOT(handlePortalPreparePrintResponse(uint,QVariantMap)))) {
            setError(tr("The system print dialog response could not be monitored."));
            finishPortalPrint();
            return false;
        }
        m_portalPrepareRequestPath = handle.path();
    }

    qInfo() << "QUPIL_PRINT: PreparePrint request" << m_portalPrepareRequestPath;
    return true;
#elif defined(QUPIL_NATIVE_WIDGET_PRINTING)
    // QUPIL_NATIVE_PRINT_DIALOG_DESKTOP_V3
    // Qt's QPrintDialog delegates to the native Windows/macOS print dialog.
    // Keep the QPrinter instance alive until the modal dialog is accepted and
    // the QTextDocument has been sent to the selected printer.
    clearError();

    QPrinter printer(QPrinter::HighResolution);
    if (printer.isValid()) {
        // These are initial defaults only. If the user changes them in the
        // native dialog, QPrintDialog writes the chosen values back to printer.
        printer.setDocName(title);
        printer.setPageSize(QPageSize(QPageSize::A4));
        printer.setPageOrientation(landscape ? QPageLayout::Landscape
                                             : QPageLayout::Portrait);
        printer.setPageMargins(QMarginsF(10, 12, 10, 12),
                               QPageLayout::Millimeter);
    }

    QPrintDialog dialog(&printer);
    if (dialog.exec() != QDialog::Accepted) {
        qInfo() << "QUPIL_PRINT: native Windows/macOS print dialog cancelled";
        return true;
    }

    if (!printer.isValid()) {
        setError(tr("No valid printer was selected."));
        return true;
    }

    // The document name is application metadata rather than a page-layout
    // choice, so restore it after the dialog without overriding paper,
    // orientation, copies, duplex, color, or printer selection.
    printer.setDocName(title);

    QTextDocument document;
    document.setHtml(html);
    document.print(&printer);

    if (printer.printerState() == QPrinter::Error) {
        setError(tr("The document could not be printed."));
        return true;
    }

    qInfo() << "QUPIL_PRINT: native Windows/macOS print job submitted to"
            << printer.printerName();
    return true;
#else
    Q_UNUSED(html)
    Q_UNUSED(title)
    Q_UNUSED(landscape)
    return false;
#endif
}

#ifdef QUPIL_XDG_PORTAL_PRINTING
void AppController::handlePortalPreparePrintResponse(uint response, const QVariantMap &results)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!m_portalPrepareRequestPath.isEmpty()) {
        bus.disconnect(QStringLiteral("org.freedesktop.portal.Desktop"),
                       m_portalPrepareRequestPath,
                       QStringLiteral("org.freedesktop.portal.Request"),
                       QStringLiteral("Response"),
                       this,
                       SLOT(handlePortalPreparePrintResponse(uint,QVariantMap)));
        m_portalPrepareRequestPath.clear();
    }

    if (!m_portalPrintInProgress)
        return;

    if (response == 1) {
        qInfo() << "QUPIL_PRINT: print dialog cancelled";
        finishPortalPrint();
        return;
    }
    if (response != 0) {
        setError(tr("The system print dialog failed."));
        finishPortalPrint();
        return;
    }

    bool ok = false;
    const uint token = results.value(QStringLiteral("token")).toUInt(&ok);
    if (!ok || token == 0) {
        setError(tr("The system print dialog returned no print token."));
        finishPortalPrint();
        return;
    }

    qInfo() << "QUPIL_PRINT: PreparePrint accepted, token" << token;
    if (!startPortalPrintRequest(token))
        finishPortalPrint();
}

bool AppController::startPortalPrintRequest(uint token)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        setError(tr("The desktop print service is not available."));
        return false;
    }
    if (!bus.connectionCapabilities().testFlag(QDBusConnection::UnixFileDescriptorPassing)) {
        setError(tr("The desktop print service cannot receive the document."));
        return false;
    }

    QFile pdf(m_portalPrintPdfPath);
    if (!pdf.open(QIODevice::ReadOnly)) {
        setError(tr("The temporary print file could not be opened."));
        return false;
    }

    const QDBusUnixFileDescriptor fd(pdf.handle());
    if (!fd.isValid()) {
        setError(tr("The temporary print file could not be passed to the desktop."));
        return false;
    }

    const QString handleToken = portalHandleToken(QStringLiteral("qupil_print"));
    const QString expectedPath = portalRequestPath(bus, handleToken);

    QVariantMap options;
    options.insert(QStringLiteral("handle_token"), handleToken);
    options.insert(QStringLiteral("modal"), true);
    options.insert(QStringLiteral("token"), token);
    options.insert(QStringLiteral("supported_output_file_formats"),
                   QStringList{QStringLiteral("pdf")});

    if (!bus.connect(QStringLiteral("org.freedesktop.portal.Desktop"),
                     expectedPath,
                     QStringLiteral("org.freedesktop.portal.Request"),
                     QStringLiteral("Response"),
                     this,
                     SLOT(handlePortalPrintResponse(uint,QVariantMap)))) {
        setError(tr("The print job response could not be monitored."));
        return false;
    }

    m_portalPrintRequestPath = expectedPath;

    QDBusMessage request = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.portal.Desktop"),
        QStringLiteral("/org/freedesktop/portal/desktop"),
        QStringLiteral("org.freedesktop.portal.Print"),
        QStringLiteral("Print"));
    request << QString{} << m_portalPrintTitle << QVariant::fromValue(fd) << options;

    const QDBusMessage reply = bus.call(request, QDBus::Block, 15000);
    if (reply.type() == QDBusMessage::ErrorMessage) {
        bus.disconnect(QStringLiteral("org.freedesktop.portal.Desktop"),
                       expectedPath,
                       QStringLiteral("org.freedesktop.portal.Request"),
                       QStringLiteral("Response"),
                       this,
                       SLOT(handlePortalPrintResponse(uint,QVariantMap)));
        m_portalPrintRequestPath.clear();
        setError(tr("The print job could not be submitted: %1").arg(reply.errorMessage()));
        return false;
    }
    if (reply.arguments().isEmpty()) {
        setError(tr("The print service returned no request handle."));
        return false;
    }

    const QDBusObjectPath handle = qvariant_cast<QDBusObjectPath>(reply.arguments().constFirst());
    if (handle.path().isEmpty()) {
        setError(tr("The print service returned an invalid request handle."));
        return false;
    }

    if (handle.path() != expectedPath) {
        bus.disconnect(QStringLiteral("org.freedesktop.portal.Desktop"),
                       expectedPath,
                       QStringLiteral("org.freedesktop.portal.Request"),
                       QStringLiteral("Response"),
                       this,
                       SLOT(handlePortalPrintResponse(uint,QVariantMap)));
        if (!bus.connect(QStringLiteral("org.freedesktop.portal.Desktop"),
                         handle.path(),
                         QStringLiteral("org.freedesktop.portal.Request"),
                         QStringLiteral("Response"),
                         this,
                         SLOT(handlePortalPrintResponse(uint,QVariantMap)))) {
            setError(tr("The print job response could not be monitored."));
            return false;
        }
        m_portalPrintRequestPath = handle.path();
    }

    qInfo() << "QUPIL_PRINT: Print request" << m_portalPrintRequestPath;
    return true;
}

void AppController::handlePortalPrintResponse(uint response, const QVariantMap &results)
{
    Q_UNUSED(results)

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!m_portalPrintRequestPath.isEmpty()) {
        bus.disconnect(QStringLiteral("org.freedesktop.portal.Desktop"),
                       m_portalPrintRequestPath,
                       QStringLiteral("org.freedesktop.portal.Request"),
                       QStringLiteral("Response"),
                       this,
                       SLOT(handlePortalPrintResponse(uint,QVariantMap)));
        m_portalPrintRequestPath.clear();
    }

    if (response == 0) {
        qInfo() << "QUPIL_PRINT: print job completed";
    } else if (response == 1) {
        qInfo() << "QUPIL_PRINT: print job cancelled";
    } else {
        setError(tr("The print job failed."));
    }

    finishPortalPrint();
}

void AppController::finishPortalPrint()
{
    QDBusConnection bus = QDBusConnection::sessionBus();

    if (!m_portalPrepareRequestPath.isEmpty()) {
        bus.disconnect(QStringLiteral("org.freedesktop.portal.Desktop"),
                       m_portalPrepareRequestPath,
                       QStringLiteral("org.freedesktop.portal.Request"),
                       QStringLiteral("Response"),
                       this,
                       SLOT(handlePortalPreparePrintResponse(uint,QVariantMap)));
    }
    if (!m_portalPrintRequestPath.isEmpty()) {
        bus.disconnect(QStringLiteral("org.freedesktop.portal.Desktop"),
                       m_portalPrintRequestPath,
                       QStringLiteral("org.freedesktop.portal.Request"),
                       QStringLiteral("Response"),
                       this,
                       SLOT(handlePortalPrintResponse(uint,QVariantMap)));
    }

    if (!m_portalPrintPdfPath.isEmpty())
        QFile::remove(m_portalPrintPdfPath);

    m_portalPrintPdfPath.clear();
    m_portalPrintTitle.clear();
    m_portalPrepareRequestPath.clear();
    m_portalPrintRequestPath.clear();
    m_portalPrintInProgress = false;
}
#endif


QStringList AppController::availablePrinters() const
{
#ifdef QUPIL_DESKTOP_PRINTING
    return QPrinterInfo::availablePrinterNames();
#else
    return {};
#endif
}

QString AppController::defaultPrinterName() const
{
#ifdef QUPIL_DESKTOP_PRINTING
    return QPrinterInfo::defaultPrinterName();
#else
    return {};
#endif
}

bool AppController::printDocument(const QString &html, const QString &printerName,
                                  const QString &title, bool landscape)
{
#ifdef QUPIL_DESKTOP_PRINTING
    clearError();
    QPrinterInfo info = printerName.isEmpty() ? QPrinterInfo::defaultPrinter() : QPrinterInfo::printerInfo(printerName);
    if (info.isNull()) {
        setError(tr("No printer is available."));
        return false;
    }
    QPrinter printer(info, QPrinter::HighResolution);
    printer.setDocName(title);
    printer.setPageSize(QPageSize(QPageSize::A4));
    printer.setPageOrientation(landscape ? QPageLayout::Landscape : QPageLayout::Portrait);
    printer.setPageMargins(QMarginsF(10, 12, 10, 12), QPageLayout::Millimeter);
    QTextDocument document;
    document.setHtml(html);
    document.print(&printer);
    return printer.printerState() != QPrinter::Error;
#else
    Q_UNUSED(html)
    Q_UNUSED(printerName)
    Q_UNUSED(title)
    Q_UNUSED(landscape)
    setError(tr("Printing is available on the desktop build."));
    return false;
#endif
}

QVariantList AppController::birthdays() const
{
    QVariantList result;
    const QDate today = QDate::currentDate();
    const auto rows = selectRows(QStringLiteral(
        "SELECT pupilid AS id, COALESCE(forename,'') AS forename, COALESCE(surname,'') AS surname, "
        "COALESCE(birthday,'') AS birthday FROM pupil WHERE birthday IS NOT NULL AND birthday != ''"));

    struct Entry { int distance = 0; QVariantMap row; };
    QVector<Entry> entries;
    for (const QVariantMap &source : rows) {
        const QDate birth = QDate::fromString(source.value(QStringLiteral("birthday")).toString(), Qt::ISODate);
        if (!birth.isValid())
            continue;
        QDate thisYear(today.year(), birth.month(), birth.day());
        if (!thisYear.isValid()) // February 29 in a non-leap year.
            thisYear = QDate(today.year(), 2, 28);
        int signedDays = today.daysTo(thisYear);
        QDate next = thisYear;
        if (signedDays < -7) {
            next = QDate(today.year() + 1, birth.month(), birth.day());
            if (!next.isValid())
                next = QDate(today.year() + 1, 2, 28);
        }
        const int ageOnOccurrence = next.year() - birth.year();
        QVariantMap row = source;
        row.insert(QStringLiteral("name"), QStringLiteral("%1 %2").arg(
                       source.value(QStringLiteral("forename")).toString(),
                       source.value(QStringLiteral("surname")).toString()).trimmed());
        row.insert(QStringLiteral("occurrence"), next.toString(Qt::ISODate));
        row.insert(QStringLiteral("days"), today.daysTo(next));
        row.insert(QStringLiteral("age"), ageOnOccurrence);
        row.insert(QStringLiteral("today"), signedDays == 0);
        row.insert(QStringLiteral("recent"), signedDays >= -7 && signedDays < 0);
        entries.push_back({static_cast<int>(today.daysTo(next)), row});
    }
    std::sort(entries.begin(), entries.end(), [](const Entry &a, const Entry &b) { return a.distance < b.distance; });
    for (const Entry &entry : entries)
        result.push_back(entry.row);
    return result;
}

QVariantMap AppController::instrumentOverview() const
{
    QVariantMap result;
    QVariantList pupils;
    const auto pupilRows = selectRows(QStringLiteral(
        "SELECT pupilid AS id, TRIM(COALESCE(surname,'') || ', ' || COALESCE(forename,''), ', ') AS name, "
        "COALESCE(instrumenttype,'') AS instrument, COALESCE(instrumentsize,'') AS size, "
        "COALESCE(ifrentinstrument,0) AS rental, COALESCE(rentinstrumentdesc,'') AS rentalDescription, "
        "COALESCE(ifinstrumentnextsize,0) AS needsNextSize "
        "FROM pupil WHERE COALESCE(instrumenttype,'') != '' OR COALESCE(instrumentsize,'') != '' "
        "ORDER BY surname COLLATE NOCASE, forename COLLATE NOCASE"));
    for (const auto &row : pupilRows)
        pupils.push_back(row);

    QVariantList instruments;
    for (const auto &row : selectRows(QStringLiteral(
             "SELECT instrumenttype AS name, COUNT(*) AS count FROM pupil WHERE COALESCE(instrumenttype,'') != '' "
             "GROUP BY instrumenttype ORDER BY instrumenttype COLLATE NOCASE")))
        instruments.push_back(row);

    QVariantList sizes;
    for (const auto &row : selectRows(QStringLiteral(
             "SELECT instrumentsize AS name, COUNT(*) AS count FROM pupil WHERE COALESCE(instrumentsize,'') != '' "
             "GROUP BY instrumentsize ORDER BY instrumentsize COLLATE NOCASE")))
        sizes.push_back(row);

    result.insert(QStringLiteral("pupils"), pupils);
    result.insert(QStringLiteral("instruments"), instruments);
    result.insert(QStringLiteral("sizes"), sizes);
    result.insert(QStringLiteral("rentalCount"), selectOne(QStringLiteral(
        "SELECT COUNT(*) AS n FROM pupil WHERE ifrentinstrument=1")).value(QStringLiteral("n"), 0));
    result.insert(QStringLiteral("nextSizeCount"), selectOne(QStringLiteral(
        "SELECT COUNT(*) AS n FROM pupil WHERE ifinstrumentnextsize=1")).value(QStringLiteral("n"), 0));
    return result;
}

QVariantList AppController::overdueRecitalPupils() const
{
    QVariantList result;
    const bool soloOnly = settingValue(QStringLiteral("recitalIntervalSoloOnly"), true).toBool();
    const auto pupils = selectRows(QStringLiteral(
        "SELECT pupilid AS id, recitalinterval AS interval, COALESCE(forename,'') AS forename, "
        "COALESCE(surname,'') AS surname, COALESCE(firstlessondate,'') AS firstLessonDate "
        "FROM pupil WHERE COALESCE(recitalinterval,0) != 0 ORDER BY surname,forename"));
    static const int intervalDays[] = {0, 30, 60, 90, 120, 180, 270, 360, 540, 720};
    const QDate today = QDate::currentDate();

    for (const QVariantMap &p : pupils) {
        const int pupilId = p.value(QStringLiteral("id")).toInt();
        const int activeMemberships = selectOne(QStringLiteral(
            "SELECT COUNT(*) AS n FROM pupilatlesson WHERE pupilid=? AND stopdate > date('now')"),
            {pupilId}).value(QStringLiteral("n")).toInt();
        if (activeMemberships == 0)
            continue;

        // The old code checked all piece-at-recital rows. Restrict to planned recitals here,
        // which prevents a finished event from suppressing future reminders indefinitely.
        const int planned = selectOne(QStringLiteral(
            "SELECT COUNT(*) AS n FROM pieceatrecital par JOIN recital r ON r.recitalid=par.recitalid "
            "JOIN piece pc ON par.ifexternalpiece=0 AND pc.cpieceid=par.pieceid "
            "JOIN pupilatlesson pal ON pal.palid=pc.palid "
            "WHERE r.state=0 AND pal.pupilid=?"), {pupilId}).value(QStringLiteral("n")).toInt();
        if (planned > 0)
            continue;

        QString activitySql = QStringLiteral(
            "SELECT date FROM activity WHERE ifcontinous=0 AND pupilid=? AND noncontinoustype=0");
        if (!soloOnly)
            activitySql = QStringLiteral(
                "SELECT date FROM activity WHERE ifcontinous=0 AND pupilid=? AND (noncontinoustype=0 OR noncontinoustype=1)");
        activitySql += QStringLiteral(" ORDER BY date DESC LIMIT 1");
        const QVariantMap activity = selectOne(activitySql, {pupilId});
        QDate reference = QDate::fromString(activity.value(QStringLiteral("date")).toString(), Qt::ISODate);
        if (!reference.isValid())
            reference = QDate::fromString(p.value(QStringLiteral("firstLessonDate")).toString(), Qt::ISODate);
        if (!reference.isValid())
            continue;

        const int interval = p.value(QStringLiteral("interval")).toInt();
        const int limit = interval >= 0 && interval < int(std::size(intervalDays)) ? intervalDays[interval] : 0;
        const int elapsed = reference.daysTo(today);
        if (limit <= 0 || elapsed <= limit)
            continue;

        QVariantMap row = p;
        row.insert(QStringLiteral("name"), QStringLiteral("%1, %2").arg(
                       p.value(QStringLiteral("surname")).toString(), p.value(QStringLiteral("forename")).toString()));
        row.insert(QStringLiteral("referenceDate"), reference.toString(Qt::ISODate));
        row.insert(QStringLiteral("daysSince"), elapsed);
        row.insert(QStringLiteral("intervalDays"), limit);
        result.push_back(row);
    }
    return result;
}

QVariantList AppController::pupilsWithoutEnsemble() const
{
    QVariantList result;
    const auto pupils = selectRows(QStringLiteral(
        "SELECT pupilid AS id, COALESCE(forename,'') AS forename, COALESCE(surname,'') AS surname "
        "FROM pupil WHERE ensembleactivityrequested=1 ORDER BY surname,forename"));
    for (const QVariantMap &p : pupils) {
        const int pupilId = p.value(QStringLiteral("id")).toInt();
        const int activeMemberships = selectOne(QStringLiteral(
            "SELECT COUNT(*) AS n FROM pupilatlesson WHERE pupilid=? AND stopdate > date('now')"),
            {pupilId}).value(QStringLiteral("n")).toInt();
        if (activeMemberships == 0)
            continue;
        const QVariantMap ensemble = selectOne(QStringLiteral(
            "SELECT COALESCE(desc,'') AS description, COALESCE(continousstopdate,'') AS stopDate "
            "FROM activity WHERE ifcontinous=1 AND continoustype=0 AND pupilid=? "
            "ORDER BY continousstopdate DESC LIMIT 1"), {pupilId});
        if (!ensemble.isEmpty() && ensemble.value(QStringLiteral("stopDate")).toString() == QStringLiteral("9999-99-99"))
            continue;
        QVariantMap row = p;
        row.insert(QStringLiteral("name"), QStringLiteral("%1, %2").arg(
                       p.value(QStringLiteral("surname")).toString(), p.value(QStringLiteral("forename")).toString()));
        row.insert(QStringLiteral("lastDescription"), ensemble.value(QStringLiteral("description")));
        row.insert(QStringLiteral("lastStopDate"), ensemble.value(QStringLiteral("stopDate")));
        result.push_back(row);
    }
    return result;
}

QVariantMap AppController::pupil(int pupilId) const
{
    return selectOne(QStringLiteral(
        "SELECT pupilid AS id, COALESCE(forename,'') AS forename, COALESCE(surname,'') AS surname, "
        "COALESCE(address,'') AS address, COALESCE(email,'') AS email, COALESCE(telefon,'') AS phone, "
        "COALESCE(handy,'') AS mobile, COALESCE(birthday,'') AS birthday, COALESCE(notes,'') AS notes, "
        "COALESCE(fathername,'') AS fatherName, COALESCE(fatherjob,'') AS fatherJob, COALESCE(fathertelefon,'') AS fatherPhone, "
        "COALESCE(mothername,'') AS motherName, COALESCE(motherjob,'') AS motherJob, COALESCE(mothertelefon,'') AS motherPhone, "
        "COALESCE(firstlessondate,'') AS firstLessonDate, COALESCE(instrumenttype,'') AS instrument, "
        "COALESCE(instrumentsize,'') AS instrumentSize, COALESCE(ifinstrumentnextsize,0) AS needsNextInstrumentSize, "
        "COALESCE(ifrentinstrument,0) AS hasRentalInstrument, COALESCE(rentinstrumentdesc,'') AS rentalInstrumentNumber, "
        "COALESCE(rentinstrumentstartdate,'') AS rentalInstrumentSince, COALESCE(recitalinterval,5) AS recitalInterval, "
        "COALESCE(ensembleactivityrequested,1) AS ensembleActivityRequested FROM pupil WHERE pupilid=?"), {pupilId});
}

int AppController::savePupil(const QVariantMap &v)
{
    const int id = v.value(QStringLiteral("id"), -1).toInt();
    QVariantList binds = {
        v.value(QStringLiteral("forename")), v.value(QStringLiteral("surname")), v.value(QStringLiteral("address")),
        v.value(QStringLiteral("email")), v.value(QStringLiteral("phone")), v.value(QStringLiteral("mobile")),
        v.value(QStringLiteral("birthday")), v.value(QStringLiteral("notes")), v.value(QStringLiteral("fatherName")),
        v.value(QStringLiteral("fatherJob")), v.value(QStringLiteral("fatherPhone")), v.value(QStringLiteral("motherName")),
        v.value(QStringLiteral("motherJob")), v.value(QStringLiteral("motherPhone")), v.value(QStringLiteral("firstLessonDate")),
        v.value(QStringLiteral("instrument")), v.value(QStringLiteral("instrumentSize")),
        v.value(QStringLiteral("needsNextInstrumentSize"), false).toBool() ? 1 : 0,
        v.value(QStringLiteral("hasRentalInstrument"), false).toBool() ? 1 : 0,
        v.value(QStringLiteral("rentalInstrumentNumber")), v.value(QStringLiteral("rentalInstrumentSince")),
        v.value(QStringLiteral("recitalInterval"), 5),
        v.value(QStringLiteral("ensembleActivityRequested"), true).toBool() ? 1 : 0
    };

    int resultId = id;
    if (id < 0) {
        resultId = int(insert(QStringLiteral(
            "INSERT INTO pupil (forename,surname,address,email,telefon,handy,birthday,notes,fathername,fatherjob,fathertelefon,"
            "mothername,motherjob,mothertelefon,firstlessondate,instrumenttype,instrumentsize,ifinstrumentnextsize,"
            "ifrentinstrument,rentinstrumentdesc,rentinstrumentstartdate,recitalinterval,ensembleactivityrequested) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"), binds));
    } else {
        binds << id;
        if (!execute(QStringLiteral(
            "UPDATE pupil SET forename=?,surname=?,address=?,email=?,telefon=?,handy=?,birthday=?,notes=?,fathername=?,"
            "fatherjob=?,fathertelefon=?,mothername=?,motherjob=?,mothertelefon=?,firstlessondate=?,instrumenttype=?,"
            "instrumentsize=?,ifinstrumentnextsize=?,ifrentinstrument=?,rentinstrumentdesc=?,rentinstrumentstartdate=?,"
            "recitalinterval=?,ensembleactivityrequested=? WHERE pupilid=?"), binds))
            return -1;
    }

    if (resultId >= 0) {
        refreshPupils();
        refreshLessons();
        emit dataChanged();
    }
    return resultId;
}

bool AppController::deletePupil(int pupilId)
{
    QSqlDatabase &db = m_database.database();
    if (!db.transaction()) {
        setError(db.lastError().text());
        return false;
    }

    const bool ok =
        execute(QStringLiteral("UPDATE sheetmusiclibrary SET rentpupilid=-1 WHERE rentpupilid=?"), {pupilId}) &&
        execute(QStringLiteral("DELETE FROM activity WHERE pupilid=?"), {pupilId}) &&
        execute(QStringLiteral("DELETE FROM note WHERE palid IN (SELECT palid FROM pupilatlesson WHERE pupilid=?)"), {pupilId}) &&
        execute(QStringLiteral("DELETE FROM piece WHERE palid IN (SELECT palid FROM pupilatlesson WHERE pupilid=?)"), {pupilId}) &&
        execute(QStringLiteral("DELETE FROM pupilatlesson WHERE pupilid=?"), {pupilId}) &&
        execute(QStringLiteral("DELETE FROM reminder WHERE pupilid=?"), {pupilId}) &&
        execute(QStringLiteral("DELETE FROM pupil WHERE pupilid=?"), {pupilId});

    if (!ok) {
        db.rollback();
        return false;
    }
    if (!db.commit()) {
        setError(db.lastError().text());
        return false;
    }
    refreshAll();
    return true;
}

QString AppController::buildPupilArchiveHtml(int pupilId) const
{
    const QVariantMap p = selectOne(QStringLiteral(
        "SELECT pupilid AS id, COALESCE(forename,'') AS forename, COALESCE(surname,'') AS surname, COALESCE(address,'') AS address, "
        "COALESCE(email,'') AS email, COALESCE(telefon,'') AS phone, COALESCE(handy,'') AS mobile, COALESCE(birthday,'') AS birthday, "
        "COALESCE(notes,'') AS notes, COALESCE(fathername,'') AS fatherName, COALESCE(fatherjob,'') AS fatherJob, COALESCE(fathertelefon,'') AS fatherPhone, "
        "COALESCE(mothername,'') AS motherName, COALESCE(motherjob,'') AS motherJob, COALESCE(mothertelefon,'') AS motherPhone, "
        "COALESCE(firstlessondate,'') AS firstLessonDate, COALESCE(instrumenttype,'') AS instrument, COALESCE(instrumentsize,'') AS size, "
        "COALESCE(rentinstrumentdesc,'') AS rentalDescription, COALESCE(rentinstrumentstartdate,'') AS rentalSince FROM pupil WHERE pupilid=?"), {pupilId});
    if (p.isEmpty()) return {};
    const QDate firstLesson=QDate::fromString(p.value(QStringLiteral("firstLessonDate")).toString(),Qt::ISODate);
    const int lessonYears=firstLesson.isValid()?qAbs(QDate::currentDate().daysTo(firstLesson))/365:0;
    QString body=QStringLiteral("<h2>%1: %2</h2><h2><u>%3:</u></h2><table class='noborder'>")
        .arg(tr("Date").toHtmlEscaped(),QDate::currentDate().toString(QStringLiteral("dd.MM.yyyy")),tr("Personal data").toHtmlEscaped());
    body += QStringLiteral("<tr><td><b>%1:</b></td><td>%2</td><td><b>%3:</b></td><td>%4</td></tr>")
        .arg(tr("First name").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("forename"))),tr("Last name").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("surname"))));
    body += QStringLiteral("<tr><td><b>%1:</b></td><td>%2</td><td><b>%3:</b></td><td>%4</td></tr>")
        .arg(tr("Address").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("address"))),tr("E-Mail").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("email"))));
    body += QStringLiteral("<tr><td><b>%1:</b></td><td>%2</td><td><b>%3:</b></td><td>%4</td></tr>")
        .arg(tr("Phone").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("phone"))),tr("Mobile").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("mobile"))));
    body += QStringLiteral("<tr><td><b>%1:</b></td><td colspan='3'>%2</td></tr>")
        .arg(tr("Birthday").toHtmlEscaped(),formattedIsoDate(p.value(QStringLiteral("birthday")).toString()).toHtmlEscaped());
    body += QStringLiteral("<tr><td><b>%1:</b></td><td>%2</td><td><b>%3:</b></td><td>%4</td></tr>")
        .arg(tr("Name (Father)").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("fatherName"))),tr("Job (Father)").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("fatherJob"))));
    body += QStringLiteral("<tr><td><b>%1:</b></td><td>%2</td><td><b>%3:</b></td><td>%4</td></tr>")
        .arg(tr("Phone (Father)").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("fatherPhone"))),tr("Name (Mother)").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("motherName"))));
    body += QStringLiteral("<tr><td><b>%1:</b></td><td>%2</td><td><b>%3:</b></td><td>%4</td></tr>")
        .arg(tr("Job (Mother)").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("motherJob"))),tr("Phone (Mother)").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("motherPhone"))));
    body += QStringLiteral("<tr><td><b>%1:</b></td><td colspan='3'>%2 (%3 %4 %5)</td></tr>")
        .arg(tr("Lesson since").toHtmlEscaped(),formattedIsoDate(p.value(QStringLiteral("firstLessonDate")).toString()).toHtmlEscaped(),tr("total").toHtmlEscaped(),QString::number(lessonYears),tr("Years").toHtmlEscaped());
    body += QStringLiteral("<tr><td><b>%1:</b></td><td>%2</td><td><b>%3:</b></td><td>%4</td></tr>")
        .arg(tr("Instrument").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("instrument"))),tr("Size").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("size"))));
    body += QStringLiteral("<tr><td><b>%1:</b></td><td>%2</td><td><b>%3:</b></td><td>%4</td></tr>")
        .arg(tr("Rental instrument description").toHtmlEscaped(),htmlCell(p.value(QStringLiteral("rentalDescription"))),tr("Rented since").toHtmlEscaped(),formattedIsoDate(p.value(QStringLiteral("rentalSince")).toString()).toHtmlEscaped());
    body += QStringLiteral("<tr><td><b>%1:</b></td><td colspan='3'>%2</td></tr></table>")
        .arg(tr("Notes").toHtmlEscaped(),p.value(QStringLiteral("notes")).toString());

    const int activityCount=selectOne(QStringLiteral("SELECT COUNT(*) AS n FROM activity WHERE pupilid=?"),{pupilId}).value(QStringLiteral("n")).toInt();
    if(activityCount){
        body += QStringLiteral("<h2><u>%1:</u></h2>").arg(tr("Activities of the student").toHtmlEscaped());
        const QStringList days={tr("Monday"),tr("Tuesday"),tr("Wednesday"),tr("Thursday"),tr("Friday"),tr("Saturday"),tr("Sunday"),tr("irregular")};
        const auto regular=selectRows(QStringLiteral("SELECT COALESCE(desc,'') AS description, COALESCE(continousday,0) AS day, COALESCE(continoustime,'') AS time, strftime('%d.%m.%Y',date) AS start, strftime('%d.%m.%Y',continousstopdate) AS stop FROM activity WHERE pupilid=? AND ifcontinous=1 ORDER BY date DESC"),{pupilId});
        body += QStringLiteral("<h3>%1:</h3><table><tr><th>%2</th><th>%3</th><th>%4</th><th>%5</th><th>%6</th></tr>")
            .arg(tr("Regular activities").toHtmlEscaped(),tr("Description").toHtmlEscaped(),tr("Weekday").toHtmlEscaped(),tr("Time").toHtmlEscaped(),tr("Start").toHtmlEscaped(),tr("End").toHtmlEscaped());
        for(const QVariantMap&r:regular){int d=r.value(QStringLiteral("day")).toInt();body+=QStringLiteral("<tr><td>%1</td><td>%2</td><td>%3</td><td>%4</td><td>%5</td></tr>").arg(htmlCell(r.value(QStringLiteral("description"))),d>=0&&d<days.size()?days.at(d).toHtmlEscaped():QString(),htmlCell(r.value(QStringLiteral("time"))),htmlCell(r.value(QStringLiteral("start"))),htmlCell(r.value(QStringLiteral("stop"))));} body+=QStringLiteral("</table>");
        const QStringList types={tr("Solo Recital"),tr("Ensemble Recital"),tr("Other")};
        const auto irregular=selectRows(QStringLiteral("SELECT COALESCE(desc,'') AS description, strftime('%d.%m.%Y',date) AS date, COALESCE(noncontinoustype,0) AS type FROM activity WHERE pupilid=? AND ifcontinous=0 ORDER BY date DESC"),{pupilId});
        body += QStringLiteral("<h3>%1:</h3><table><tr><th>%2</th><th>%3</th><th>%4</th></tr>").arg(tr("Irregular activities").toHtmlEscaped(),tr("Description").toHtmlEscaped(),tr("Date").toHtmlEscaped(),tr("Type").toHtmlEscaped());
        for(const QVariantMap&r:irregular){int t=r.value(QStringLiteral("type")).toInt();body+=QStringLiteral("<tr><td>%1</td><td>%2</td><td>%3</td></tr>").arg(htmlCell(r.value(QStringLiteral("description"))),htmlCell(r.value(QStringLiteral("date"))),t>=0&&t<types.size()?types.at(t).toHtmlEscaped():QString());} body+=QStringLiteral("</table>");
    }

    const int lessonCount=selectOne(QStringLiteral("SELECT COUNT(*) AS n FROM pupilatlesson WHERE pupilid=?"),{pupilId}).value(QStringLiteral("n")).toInt();
    if(lessonCount){
        body += QStringLiteral("<h2><u>%1:</u></h2>").arg(tr("Lesson notes and music pieces").toHtmlEscaped());
        struct Membership {int palId; QString name,start,stop; bool active;}; QVector<Membership> ms;
        const auto old=selectRows(QStringLiteral("SELECT pal.palid AS palId, COALESCE(lln.lessonname,'') AS name, COALESCE(pal.startdate,'') AS start, COALESCE(pal.stopdate,'') AS stop FROM pupilatlesson pal,lastlessonname lln WHERE pal.llnid=lln.llnid AND pal.pupilid=? AND pal.stopdate <= date('now')"),{pupilId});
        for(const QVariantMap&r:old) ms.push_back({r.value(QStringLiteral("palId")).toInt(),r.value(QStringLiteral("name")).toString(),r.value(QStringLiteral("start")).toString(),r.value(QStringLiteral("stop")).toString(),false});
        const auto active=selectRows(QStringLiteral("SELECT pal.palid AS palId, COALESCE(l.lessonname,'') AS name, COALESCE(pal.startdate,'') AS start FROM pupilatlesson pal,lesson l WHERE pal.pupilid=? AND pal.lessonid=l.lessonid AND pal.stopdate > date('now') ORDER BY pal.startdate ASC"),{pupilId});
        for(const QVariantMap&r:active) ms.push_back({r.value(QStringLiteral("palId")).toInt(),r.value(QStringLiteral("name")).toString(),r.value(QStringLiteral("start")).toString(),QString(),true});
        body += QStringLiteral("<p><b>%1:</b></p><ol>").arg(tr("The student took part in the following lessons").toHtmlEscaped());
        for(const Membership&m:ms) body += QStringLiteral("<li>%1 (%2 %3%4)</li>").arg(m.name.toHtmlEscaped(),m.active?tr("since").toHtmlEscaped():tr("from").toHtmlEscaped(),formattedIsoDate(m.start).toHtmlEscaped(),m.active?QString():QStringLiteral(" %1 %2").arg(tr("to").toHtmlEscaped(),formattedIsoDate(m.stop).toHtmlEscaped()));
        body += QStringLiteral("</ol>");
        const QStringList states={tr("Planned"),tr("In Progress"),tr("Paused"),tr("Ready for Concert"),tr("Finished")};
        for(const Membership&m:ms){
            const QString range=m.active?QStringLiteral("%1 %2").arg(tr("since").toHtmlEscaped(),formattedIsoDate(m.start).toHtmlEscaped()):QStringLiteral("%1 %2 %3 %4").arg(tr("from").toHtmlEscaped(),formattedIsoDate(m.start).toHtmlEscaped(),tr("to").toHtmlEscaped(),formattedIsoDate(m.stop).toHtmlEscaped());
            const auto notes=selectRows(QStringLiteral("SELECT strftime('%d.%m.%Y',n.date) AS date, COALESCE(n.content,'') AS content FROM note n,pupilatlesson pal WHERE pal.palid=? AND pal.palid=n.palid AND pal.startdate <= n.date AND pal.stopdate >= n.date ORDER BY n.date ASC"),{m.palId});
            if(!notes.isEmpty()){body += QStringLiteral("<h3>%1 (%2 - %3)</h3><table><tr><th>%4</th><th>%5</th></tr>").arg(tr("Lesson notes").toHtmlEscaped(),m.name.toHtmlEscaped(),range,tr("Date").toHtmlEscaped(),tr("Note").toHtmlEscaped()); for(const QVariantMap&r:notes)body+=QStringLiteral("<tr><td>%1</td><td>%2</td></tr>").arg(htmlCell(r.value(QStringLiteral("date"))),r.value(QStringLiteral("content")).toString()); body+=QStringLiteral("</table>");}
            const auto pieces=selectRows(QStringLiteral("SELECT COALESCE(p.title,'') AS title,COALESCE(p.genre,'') AS genre,COALESCE(p.duration,0) AS duration,strftime('%d.%m.%Y',p.startdate) AS start,strftime('%d.%m.%Y',p.stopdate) AS stop,COALESCE(p.state,0) AS state FROM piece p,pupilatlesson pal WHERE pal.palid=? AND pal.palid=p.palid AND pal.startdate <= p.startdate AND pal.stopdate >= p.startdate ORDER BY p.startdate ASC"),{m.palId});
            if(!pieces.isEmpty()){body += QStringLiteral("<h3>%1 (%2 - %3)</h3><table><tr><th>%4</th><th>%5</th><th>%6</th><th>%7</th><th>%8</th><th>%9</th></tr>").arg(tr("Music pieces").toHtmlEscaped(),m.name.toHtmlEscaped(),range,tr("Title").toHtmlEscaped(),tr("Genre").toHtmlEscaped(),tr("Duration").toHtmlEscaped(),tr("Start").toHtmlEscaped(),tr("End").toHtmlEscaped(),tr("State").toHtmlEscaped()); for(const QVariantMap&r:pieces){int st=r.value(QStringLiteral("state")).toInt();body+=QStringLiteral("<tr><td>%1</td><td>%2</td><td>%3</td><td>%4</td><td>%5</td><td>%6</td></tr>").arg(htmlCell(r.value(QStringLiteral("title"))),htmlCell(r.value(QStringLiteral("genre"))),htmlCell(r.value(QStringLiteral("duration"))),htmlCell(r.value(QStringLiteral("start"))),htmlCell(r.value(QStringLiteral("stop"))),st>=0&&st<states.size()?states.at(st).toHtmlEscaped():QString());} body+=QStringLiteral("</table>");}
        }
    }
    const QString title=QStringLiteral("Qupil %1 - %2: %3 %4 (#%5)").arg(QCoreApplication::applicationVersion(),tr("Archive Entry"),p.value(QStringLiteral("forename")).toString(),p.value(QStringLiteral("surname")).toString(),QString::number(pupilId));
    return documentFrame(title,body);
}


bool AppController::archivePupil(int pupilId)
{
    const QVariantMap p = pupil(pupilId);
    if (p.isEmpty()) {
        setError(tr("Pupil not found."));
        return false;
    }
    const QString html = buildPupilArchiveHtml(pupilId);
    if (!execute(QStringLiteral("REPLACE INTO pupilarchive (pupilid,forename,surname,data) VALUES (?,?,?,?)"),
                 {pupilId, p.value(QStringLiteral("forename")), p.value(QStringLiteral("surname")), html}))
        return false;
    if (!deletePupil(pupilId))
        return false;
    refreshArchive();
    return true;
}

QString AppController::pupilArchiveHtml(int pupilId) const
{
    return selectOne(QStringLiteral("SELECT COALESCE(data,'') AS data FROM pupilarchive WHERE pupilid=?"), {pupilId})
        .value(QStringLiteral("data")).toString();
}

bool AppController::deleteArchiveEntry(int pupilId)
{
    if (!execute(QStringLiteral("DELETE FROM pupilarchive WHERE pupilid=?"), {pupilId}))
        return false;
    refreshArchive();
    return true;
}

QVariantList AppController::pupilLessonMemberships(int pupilId) const
{
    QVariantList result;
    const auto rows = selectRows(QStringLiteral(
        "SELECT pal.palid AS palId, l.lessonid AS lessonId, COALESCE(l.lessonname,'') AS lessonName, "
        "pal.startdate AS startDate, pal.stopdate AS stopDate, l.state AS lessonState "
        "FROM pupilatlesson pal JOIN lesson l ON l.lessonid=pal.lessonid "
        "WHERE pal.pupilid=? AND pal.stopdate > date('now') ORDER BY l.lessonname"), {pupilId});
    for (const auto &row : rows)
        result << row;
    return result;
}

QVariantMap AppController::lessonMembershipContext(int palId) const
{
    return selectOne(QStringLiteral(
        "SELECT pal.palid AS palId, pal.pupilid AS pupilId, l.lessonid AS lessonId, "
        "TRIM(COALESCE(p.forename,'') || ' ' || COALESCE(p.surname,'')) AS pupilName, "
        "COALESCE(l.lessonname,'') AS lessonName, COALESCE(l.lessonstarttime,'') AS start, "
        "COALESCE(l.lessonstoptime,'') AS stop, COALESCE(l.lessonlocation,'') AS location, "
        "COALESCE(l.type,1) AS type "
        "FROM pupilatlesson pal JOIN pupil p ON p.pupilid=pal.pupilid "
        "JOIN lesson l ON l.lessonid=pal.lessonid WHERE pal.palid=?"), {palId});
}

QVariantList AppController::notesForMembership(int palId) const
{
    QVariantList result;
    const auto rows = selectRows(QStringLiteral(
        "SELECT n.noteid AS id, n.cnoteid AS commonId, n.palid AS palId, "
        "COALESCE(n.date,'') AS date, COALESCE(n.content,'') AS content "
        "FROM note n WHERE n.palid=? ORDER BY n.date DESC, n.noteid DESC"), {palId});
    for (const auto &row : rows)
        result << row;
    return result;
}

QVariantList AppController::piecesForMembership(int palId) const
{
    QVariantList result;
    auto rows = selectRows(QStringLiteral(
        "SELECT p.pieceid AS id, p.cpieceid AS commonId, p.palid AS palId, COALESCE(pc.composer,'') AS composer, "
        "COALESCE(p.title,'') AS title, COALESCE(p.genre,'') AS genre, COALESCE(p.duration,0) AS duration, "
        "COALESCE(p.startdate,'') AS startDate, COALESCE(p.stopdate,'') AS stopDate, COALESCE(p.state,0) AS state "
        "FROM piece p LEFT JOIN piececomposer pc ON pc.piececomposerid=p.piececomposerid "
        "WHERE p.palid=? ORDER BY p.startdate DESC, p.pieceid DESC"), {palId});
    const QStringList states = {tr("Planned"), tr("In progress"), tr("Paused"), tr("Ready for concert"), tr("Finished")};
    for (auto &row : rows) {
        const int state = row.value(QStringLiteral("state")).toInt();
        row.insert(QStringLiteral("stateName"), state >= 0 && state < states.size() ? states.at(state) : tr("Unknown"));
        result << row;
    }
    return result;
}

QString AppController::noteTemplateText(const QString &content) const
{
    if (!Qt::mightBeRichText(content))
        return content;

    QTextDocument document;
    document.setHtml(content);
    return document.toPlainText();
}

QVariantList AppController::notesForPupil(int pupilId) const
{
    QVariantList result;
    const auto rows = selectRows(QStringLiteral(
        "SELECT n.noteid AS id, n.cnoteid AS commonId, n.palid AS palId, COALESCE(l.lessonname,lln.lessonname,'') AS lessonName, "
        "COALESCE(n.date,'') AS date, COALESCE(n.content,'') AS content "
        "FROM note n JOIN pupilatlesson pal ON pal.palid=n.palid "
        "LEFT JOIN lesson l ON l.lessonid=pal.lessonid LEFT JOIN lastlessonname lln ON lln.llnid=pal.llnid "
        "WHERE pal.pupilid=? ORDER BY n.date DESC, n.noteid DESC"), {pupilId});
    for (const auto &row : rows)
        result << row;
    return result;
}

QVariantList AppController::piecesForPupil(int pupilId) const
{
    QVariantList result;
    auto rows = selectRows(QStringLiteral(
        "SELECT p.pieceid AS id, p.cpieceid AS commonId, p.palid AS palId, COALESCE(pc.composer,'') AS composer, "
        "COALESCE(p.title,'') AS title, COALESCE(p.genre,'') AS genre, COALESCE(p.duration,0) AS duration, "
        "COALESCE(p.startdate,'') AS startDate, COALESCE(p.stopdate,'') AS stopDate, COALESCE(p.state,0) AS state, "
        "COALESCE(l.lessonname,lln.lessonname,'') AS lessonName "
        "FROM piece p JOIN pupilatlesson pal ON pal.palid=p.palid "
        "LEFT JOIN lesson l ON l.lessonid=pal.lessonid LEFT JOIN lastlessonname lln ON lln.llnid=pal.llnid "
        "LEFT JOIN piececomposer pc ON pc.piececomposerid=p.piececomposerid "
        "WHERE pal.pupilid=? ORDER BY p.startdate DESC, p.pieceid DESC"), {pupilId});
    const QStringList states = {tr("Planned"), tr("In progress"), tr("Paused"), tr("Ready for concert"), tr("Finished")};
    for (auto &row : rows) {
        const int state = row.value(QStringLiteral("state")).toInt();
        row.insert(QStringLiteral("stateName"), state >= 0 && state < states.size() ? states.at(state) : tr("Unknown"));
        result << row;
    }
    return result;
}

QVariantList AppController::activitiesForPupil(int pupilId) const
{
    QVariantList result;
    auto rows = selectRows(QStringLiteral(
        "SELECT activityid AS id, COALESCE(ifcontinous,0) AS continuous, COALESCE(desc,'') AS description, "
        "COALESCE(continousday,-1) AS day, COALESCE(continoustime,'') AS time, COALESCE(date,'') AS date, "
        "COALESCE(continousstopdate,'') AS stopDate, COALESCE(noncontinoustype,0) AS nonContinuousType, "
        "COALESCE(continoustype,0) AS continuousType FROM activity WHERE pupilid=? ORDER BY date DESC, activityid DESC"), {pupilId});
    for (auto &row : rows) {
        if (row.value(QStringLiteral("continuous")).toBool())
            row.insert(QStringLiteral("typeName"), tr("Regular"));
        else
            row.insert(QStringLiteral("typeName"), tr("Irregular"));
        result << row;
    }
    return result;
}

QVariantList AppController::loanedMusicForPupil(int pupilId) const
{
    QVariantList result;
    const auto rows = selectRows(QStringLiteral(
        "SELECT sml.smlid AS id, COALESCE(a.author,'') AS author, COALESCE(sml.title,'') AS title, "
        "COALESCE(pub.publisher,'') AS publisher, COALESCE(sml.lastrentdate,'') AS rentDate "
        "FROM sheetmusiclibrary sml LEFT JOIN smlauthor a ON a.smlauthorid=sml.author "
        "LEFT JOIN smlpublisher pub ON pub.smlpublisherid=sml.publisher WHERE sml.rentpupilid=? "
        "ORDER BY a.author,sml.title"), {pupilId});
    for (const auto &row : rows)
        result << row;
    return result;
}

int AppController::addNote(int palId, const QString &date, const QString &content)
{
    const QString noteDate = date.isEmpty() ? isoToday() : date;
    const bool shareWithLesson = settingValue(QStringLiteral("saveNotesPiecesForAllPupils"), true).toBool();

    if (!shareWithLesson) {
        const qint64 id = insert(QStringLiteral("INSERT INTO note (palid,date,content) VALUES (?,?,?)"),
                                 {palId, noteDate, content});
        if (id < 0)
            return -1;
        if (!execute(QStringLiteral("UPDATE note SET cnoteid=? WHERE noteid=?"), {id, id}))
            return -1;
        emit dataChanged();
        return int(id);
    }

    const QVariantMap membership = selectOne(QStringLiteral(
        "SELECT lessonid AS lessonId FROM pupilatlesson WHERE palid=?"), {palId});
    if (membership.isEmpty()) {
        setError(tr("The selected lesson membership no longer exists."));
        return -1;
    }
    const auto memberships = selectRows(QStringLiteral(
        "SELECT palid AS palId FROM pupilatlesson WHERE lessonid=? AND stopdate > date('now') ORDER BY palid"),
        {membership.value(QStringLiteral("lessonId"))});
    if (memberships.isEmpty()) {
        setError(tr("The lesson has no active pupils."));
        return -1;
    }

    QSqlDatabase &db = m_database.database();
    if (!db.transaction()) {
        setError(db.lastError().text());
        return -1;
    }

    qint64 commonId = -1;
    for (const QVariantMap &row : memberships) {
        const qint64 id = insert(QStringLiteral("INSERT INTO note (palid,date,content) VALUES (?,?,?)"),
                                 {row.value(QStringLiteral("palId")), noteDate, content});
        if (id < 0) {
            db.rollback();
            return -1;
        }
        if (commonId < 0)
            commonId = id;
        if (!execute(QStringLiteral("UPDATE note SET cnoteid=? WHERE noteid=?"), {commonId, id})) {
            db.rollback();
            return -1;
        }
    }
    if (!db.commit()) {
        setError(db.lastError().text());
        return -1;
    }
    emit dataChanged();
    return int(commonId);
}

bool AppController::deleteNote(int noteId)
{
    const QVariantMap note = selectOne(QStringLiteral(
        "SELECT COALESCE(cnoteid,noteid) AS commonId FROM note WHERE noteid=?"), {noteId});
    if (note.isEmpty())
        return false;
    const int commonId = note.value(QStringLiteral("commonId"), noteId).toInt();
    const int linkedRows = selectOne(QStringLiteral(
        "SELECT COUNT(*) AS n FROM note WHERE cnoteid=?"), {commonId})
        .value(QStringLiteral("n")).toInt();
    const bool ok = linkedRows > 1
        ? execute(QStringLiteral("DELETE FROM note WHERE cnoteid=?"), {commonId})
        : execute(QStringLiteral("DELETE FROM note WHERE noteid=?"), {noteId});
    if (!ok)
        return false;
    emit dataChanged();
    return true;
}

int AppController::ensureLookupId(const QString &table, const QString &idColumn,
                                  const QString &valueColumn, const QString &value)
{
    const auto existing = selectOne(QStringLiteral("SELECT %1 AS id FROM %2 WHERE %3=? LIMIT 1")
                                        .arg(idColumn, table, valueColumn), {value});
    if (!existing.isEmpty())
        return existing.value(QStringLiteral("id")).toInt();
    return int(insert(QStringLiteral("INSERT INTO %1 (%2) VALUES (?)").arg(table, valueColumn), {value}));
}

int AppController::addPiece(int palId, const QString &composer, const QString &title,
                            const QString &genre, int duration, int state)
{
    if (composer.trimmed().isEmpty() || title.trimmed().isEmpty()) {
        setError(tr("Composer and title are required."));
        return -1;
    }
    const int composerId = ensureLookupId(QStringLiteral("piececomposer"), QStringLiteral("piececomposerid"),
                                          QStringLiteral("composer"), composer.trimmed());
    if (composerId < 0)
        return -1;

    const bool shareWithLesson = settingValue(QStringLiteral("saveNotesPiecesForAllPupils"), true).toBool();
    if (!shareWithLesson) {
        const qint64 id = insert(QStringLiteral(
            "INSERT INTO piece (palid,title,genre,duration,startdate,state,piececomposerid) VALUES (?,?,?,?,?,?,?)"),
            {palId, title.trimmed(), genre, duration, isoToday(), state, composerId});
        if (id < 0)
            return -1;
        if (!execute(QStringLiteral("UPDATE piece SET cpieceid=? WHERE pieceid=?"), {id, id}))
            return -1;
        emit dataChanged();
        return int(id);
    }

    const QVariantMap membership = selectOne(QStringLiteral(
        "SELECT lessonid AS lessonId FROM pupilatlesson WHERE palid=?"), {palId});
    if (membership.isEmpty()) {
        setError(tr("The selected lesson membership no longer exists."));
        return -1;
    }
    const auto memberships = selectRows(QStringLiteral(
        "SELECT palid AS palId FROM pupilatlesson WHERE lessonid=? AND stopdate > date('now') ORDER BY palid"),
        {membership.value(QStringLiteral("lessonId"))});
    if (memberships.isEmpty()) {
        setError(tr("The lesson has no active pupils."));
        return -1;
    }

    QSqlDatabase &db = m_database.database();
    if (!db.transaction()) {
        setError(db.lastError().text());
        return -1;
    }
    qint64 commonId = -1;
    for (const QVariantMap &row : memberships) {
        const qint64 id = insert(QStringLiteral(
            "INSERT INTO piece (palid,title,genre,duration,startdate,state,piececomposerid) VALUES (?,?,?,?,?,?,?)"),
            {row.value(QStringLiteral("palId")), title.trimmed(), genre, duration, isoToday(), state, composerId});
        if (id < 0) {
            db.rollback();
            return -1;
        }
        if (commonId < 0)
            commonId = id;
        if (!execute(QStringLiteral("UPDATE piece SET cpieceid=? WHERE pieceid=?"), {commonId, id})) {
            db.rollback();
            return -1;
        }
    }
    if (!db.commit()) {
        setError(db.lastError().text());
        return -1;
    }
    emit dataChanged();
    return int(commonId);
}

bool AppController::deletePiece(int pieceId)
{
    const QVariantMap piece = selectOne(QStringLiteral(
        "SELECT COALESCE(cpieceid,pieceid) AS commonId FROM piece WHERE pieceid=?"), {pieceId});
    if (piece.isEmpty())
        return false;
    const int commonId = piece.value(QStringLiteral("commonId"), pieceId).toInt();
    const int linkedRows = selectOne(QStringLiteral(
        "SELECT COUNT(*) AS n FROM piece WHERE cpieceid=?"), {commonId})
        .value(QStringLiteral("n")).toInt();
    const bool ok = linkedRows > 1
        ? execute(QStringLiteral("DELETE FROM piece WHERE cpieceid=?"), {commonId})
        : execute(QStringLiteral("DELETE FROM piece WHERE pieceid=?"), {pieceId});
    if (!ok)
        return false;
    emit dataChanged();
    return true;
}

int AppController::addActivity(int pupilId, bool continuous, const QVariantMap &v)
{
    qint64 id = -1;
    if (continuous) {
        id = insert(QStringLiteral(
            "INSERT INTO activity (pupilid,ifcontinous,desc,continousday,continoustime,date,continoustype,continousstopdate) "
            "VALUES (?,1,?,?,?,?,?,'9999-99-99')"),
            {pupilId, v.value(QStringLiteral("description")), v.value(QStringLiteral("day"), 0),
             v.value(QStringLiteral("time")), v.value(QStringLiteral("date"), isoToday()),
             v.value(QStringLiteral("type"), 0)});
    } else {
        id = insert(QStringLiteral(
            "INSERT INTO activity (pupilid,ifcontinous,desc,date,noncontinoustype) VALUES (?,0,?,?,?)"),
            {pupilId, v.value(QStringLiteral("description")), v.value(QStringLiteral("date"), isoToday()),
             v.value(QStringLiteral("type"), 0)});
    }
    if (id >= 0)
        emit dataChanged();
    return int(id);
}

bool AppController::deleteActivity(int activityId)
{
    if (!execute(QStringLiteral("DELETE FROM activity WHERE activityid=?"), {activityId}))
        return false;
    emit dataChanged();
    return true;
}

QVariantMap AppController::lesson(int lessonId) const
{
    return selectOne(QStringLiteral(
        "SELECT lessonid AS id, COALESCE(state,1) AS state, COALESCE(type,1) AS type, "
        "COALESCE(autolessonname,1) AS autoName, COALESCE(lessonname,'') AS name, "
        "COALESCE(unsteadylesson,1) AS irregular, COALESCE(lessonday,0) AS day, "
        "COALESCE(lessonstarttime,'') AS start, COALESCE(lessonstoptime,'') AS stop, "
        "COALESCE(lessonlocation,'') AS location FROM lesson WHERE lessonid=?"), {lessonId});
}

int AppController::saveLesson(const QVariantMap &v)
{
    const int id = v.value(QStringLiteral("id"), -1).toInt();
    const int type = v.value(QStringLiteral("type"), 1).toInt();
    const int autoName = v.value(QStringLiteral("autoName"), true).toBool() ? 1 : 0;
    const QString name = v.value(QStringLiteral("name")).toString();
    const int irregular = v.value(QStringLiteral("irregular"), false).toBool() ? 1 : 0;
    const int day = irregular ? -1 : v.value(QStringLiteral("day"), 0).toInt();
    const QString start = irregular ? QString{} : v.value(QStringLiteral("start")).toString();
    const QString stop = irregular ? QString{} : v.value(QStringLiteral("stop")).toString();
    const QString location = v.value(QStringLiteral("location")).toString();

    int resultId = id;
    if (id < 0) {
        resultId = int(insert(QStringLiteral(
            "INSERT INTO lesson (state,type,autolessonname,lessonname,unsteadylesson,lessonday,lessonstarttime,lessonstoptime,lessonlocation) "
            "VALUES (1,?,?,?,?,?,?,?,?)"),
            {type, autoName, name.isEmpty() ? tr("New lesson") : name, irregular, day, start, stop, location}));
    } else {
        if (!execute(QStringLiteral(
            "UPDATE lesson SET type=?,autolessonname=?,lessonname=?,unsteadylesson=?,lessonday=?,lessonstarttime=?,lessonstoptime=?,lessonlocation=? "
            "WHERE lessonid=?"), {type, autoName, name, irregular, day, start, stop, location, id}))
            return -1;
    }

    if (resultId >= 0 && autoName)
        updateLessonAutoName(resultId);
    refreshLessons();
    emit dataChanged();
    return resultId;
}

void AppController::updateLessonAutoName(int lessonId)
{
    const QVariantMap l = lesson(lessonId);
    if (l.isEmpty() || !l.value(QStringLiteral("autoName")).toBool())
        return;

    QString name;
    switch (l.value(QStringLiteral("type")).toInt()) {
    case 1: name = tr("IL-"); break;
    case 2: name = tr("GL-"); break;
    case 3: name = tr("EnsL-"); break;
    default: name = QStringLiteral("L-"); break;
    }

    if (!l.value(QStringLiteral("irregular")).toBool()) {
        const QTime start = QTime::fromString(l.value(QStringLiteral("start")).toString(), QStringLiteral("hh:mm"));
        const QTime stop = QTime::fromString(l.value(QStringLiteral("stop")).toString(), QStringLiteral("hh:mm"));
        if (start.isValid() && stop.isValid())
            name += QString::number(start.secsTo(stop) / 60) + QLatin1Char('-');
    }

    const QString location = l.value(QStringLiteral("location")).toString().trimmed();
    if (!location.isEmpty())
        name += location.left(3) + QLatin1Char('-');

    const auto members = lessonPupils(lessonId);
    if (!members.isEmpty()) {
        if (l.value(QStringLiteral("type")).toInt() == 1) {
            const auto first = members.constFirst().toMap();
            name += first.value(QStringLiteral("forename")).toString().left(3)
                    + first.value(QStringLiteral("surname")).toString().left(3);
        } else {
            for (const QVariant &item : members)
                name += item.toMap().value(QStringLiteral("forename")).toString().left(1);
        }
    }
    execute(QStringLiteral("UPDATE lesson SET lessonname=? WHERE lessonid=?"), {name, lessonId});
}

QVariantList AppController::lessonPupils(int lessonId) const
{
    QVariantList result;
    const auto rows = selectRows(QStringLiteral(
        "SELECT p.pupilid AS id, p.forename AS forename, p.surname AS surname, "
        "TRIM(p.surname || ', ' || p.forename) AS name, pal.palid AS palId, pal.startdate AS startDate "
        "FROM pupilatlesson pal JOIN pupil p ON p.pupilid=pal.pupilid "
        "WHERE pal.lessonid=? AND pal.stopdate > date('now') ORDER BY p.surname,p.forename"), {lessonId});
    for (const auto &row : rows)
        result << row;
    return result;
}

QVariantList AppController::availablePupilsForLesson(int lessonId) const
{
    QVariantList result;
    const auto rows = selectRows(QStringLiteral(
        "SELECT p.pupilid AS id, p.forename AS forename, p.surname AS surname, "
        "TRIM(p.surname || ', ' || p.forename) AS name FROM pupil p "
        "WHERE p.pupilid NOT IN (SELECT pal.pupilid FROM pupilatlesson pal WHERE pal.lessonid=? AND pal.stopdate > date('now')) "
        "ORDER BY p.surname,p.forename"), {lessonId});
    for (const auto &row : rows)
        result << row;
    return result;
}

bool AppController::addPupilToLesson(int lessonId, int pupilId)
{
    const QVariantMap l = lesson(lessonId);
    if (l.isEmpty())
        return false;
    if (l.value(QStringLiteral("type")).toInt() == 1 && !lessonPupils(lessonId).isEmpty()) {
        setError(tr("An individual lesson can only contain one pupil."));
        return false;
    }
    if (selectOne(QStringLiteral(
            "SELECT palid AS id FROM pupilatlesson WHERE lessonid=? AND pupilid=? AND stopdate > date('now')"),
                  {lessonId, pupilId}).contains(QStringLiteral("id")))
        return true;

    if (insert(QStringLiteral(
        "INSERT INTO pupilatlesson (lessonid,pupilid,startdate,stopdate) VALUES (?,?,?,'9999-99-99')"),
        {lessonId, pupilId, isoToday()}) < 0)
        return false;
    updateLessonAutoName(lessonId);
    refreshLessons();
    emit dataChanged();
    return true;
}

bool AppController::removePupilFromLesson(int lessonId, int pupilId)
{
    const QVariantMap membership = selectOne(QStringLiteral(
        "SELECT pal.palid AS palId, pal.startdate AS startDate, COALESCE(l.lessonname,'') AS lessonName "
        "FROM pupilatlesson pal JOIN lesson l ON l.lessonid=pal.lessonid "
        "WHERE pal.lessonid=? AND pal.pupilid=? AND pal.stopdate > date('now') ORDER BY pal.palid DESC LIMIT 1"),
        {lessonId, pupilId});
    if (membership.isEmpty())
        return true;

    const int palId = membership.value(QStringLiteral("palId")).toInt();
    const QDate startDate = QDate::fromString(membership.value(QStringLiteral("startDate")).toString(), Qt::ISODate);
    bool ok = false;
    if (startDate.isValid() && startDate.daysTo(QDate::currentDate()) > 30) {
        const qint64 llnId = insert(QStringLiteral("INSERT INTO lastlessonname (lessonname) VALUES (?)"),
                                    {membership.value(QStringLiteral("lessonName"))});
        ok = llnId >= 0 && execute(QStringLiteral("UPDATE pupilatlesson SET stopdate=?,llnid=? WHERE palid=?"),
                                   {isoToday(), llnId, palId});
    } else {
        // A very short membership was never historically archived. Remove its dependent
        // draft content as well instead of leaving orphan rows behind.
        ok = execute(QStringLiteral("DELETE FROM note WHERE palid=?"), {palId})
             && execute(QStringLiteral("DELETE FROM piece WHERE palid=?"), {palId})
             && execute(QStringLiteral("DELETE FROM pupilatlesson WHERE palid=?"), {palId});
    }
    if (!ok)
        return false;
    updateLessonAutoName(lessonId);
    refreshLessons();
    emit dataChanged();
    return true;
}

bool AppController::deleteLesson(int lessonId)
{
    const QVariantMap l = lesson(lessonId);
    if (l.isEmpty())
        return true;
    const QVariantList members = lessonPupils(lessonId);
    for (const QVariant &item : members) {
        if (!removePupilFromLesson(lessonId, item.toMap().value(QStringLiteral("id")).toInt()))
            return false;
    }
    const int historicalLinks = selectOne(QStringLiteral("SELECT COUNT(*) AS n FROM pupilatlesson WHERE lessonid=?"), {lessonId})
                                    .value(QStringLiteral("n")).toInt();
    const bool ok = historicalLinks > 0
        ? execute(QStringLiteral("UPDATE lesson SET state=0 WHERE lessonid=?"), {lessonId})
        : execute(QStringLiteral("DELETE FROM lesson WHERE lessonid=?"), {lessonId});
    if (ok) {
        refreshLessons();
        emit dataChanged();
    }
    return ok;
}

QVariantMap AppController::reminder(int reminderId) const
{
    return selectOne(QStringLiteral(
        "SELECT reminderid AS id, COALESCE(desc,'') AS description, COALESCE(mode,0) AS mode, "
        "COALESCE(pupilid,-1) AS pupilId, COALESCE(notificationsound,0) AS sound FROM reminder WHERE reminderid=?"),
        {reminderId});
}

QVariantList AppController::startupReminders() const
{
    QVariantList result;
    const auto rows = selectRows(QStringLiteral(
        "SELECT reminderid AS id, COALESCE(desc,'') AS description, 0 AS mode, "
        "COALESCE(pupilid,-1) AS pupilId, COALESCE(notificationsound,0) AS sound, '' AS pupilName "
        "FROM reminder WHERE mode=0 ORDER BY reminderid"));
    for (const auto &row : rows)
        result << row;
    return result;
}

QVariantList AppController::lessonReminders(bool includeCurrentLesson) const
{
    QVariantList result;
    const QDate today = QDate::currentDate();
    const QString now = QTime::currentTime().toString(QStringLiteral("HH:mm"));

    QVariantMap lessonRow;
    if (includeCurrentLesson) {
        lessonRow = selectOne(QStringLiteral(
            "SELECT lessonid AS id FROM lesson WHERE state=1 AND lessonday=? "
            "AND time(lessonstarttime)<=time(?) AND time(lessonstoptime)>time(?) "
            "ORDER BY lessonstarttime DESC LIMIT 1"),
            {today.dayOfWeek() - 1, now, now});
    } else {
        lessonRow = selectOne(QStringLiteral(
            "SELECT lessonid AS id FROM lesson WHERE state=1 AND lessonday=? "
            "AND lessonstarttime=? ORDER BY lessonid LIMIT 1"),
            {today.dayOfWeek() - 1, now});
    }
    if (lessonRow.isEmpty())
        return result;

    const int lessonId = lessonRow.value(QStringLiteral("id")).toInt();
    const auto rows = selectRows(QStringLiteral(
        "SELECT r.reminderid AS id, COALESCE(r.desc,'') AS description, COALESCE(r.mode,0) AS mode, "
        "COALESCE(r.pupilid,-1) AS pupilId, COALESCE(r.notificationsound,0) AS sound, "
        "TRIM(COALESCE(p.forename,'') || ' ' || COALESCE(p.surname,'')) AS pupilName "
        "FROM reminder r LEFT JOIN pupil p ON p.pupilid=r.pupilid "
        "WHERE r.mode=1 OR (r.mode=2 AND EXISTS ("
        "SELECT 1 FROM pupilatlesson pal WHERE pal.lessonid=? AND pal.pupilid=r.pupilid "
        "AND date(COALESCE(NULLIF(pal.stopdate,''),'9999-12-31')) > date('now'))) "
        "ORDER BY r.mode, r.reminderid"), {lessonId});
    for (const auto &row : rows)
        result << row;
    return result;
}

QVariantList AppController::lessonEndWarnings() const
{
    QVariantList result;
    if (!settingValue(QStringLiteral("lessonEndReminder"), true).toBool())
        return result;

    const int minutes = qBound(1, settingValue(QStringLiteral("minutesToLessonEndReminder"), 3).toInt(), 30);
    const QDate today = QDate::currentDate();
    const QTime now = QTime::currentTime();
    const auto rows = selectRows(QStringLiteral(
        "SELECT lessonid AS id, COALESCE(lessonname,'') AS name, lessonstoptime AS stop "
        "FROM lesson WHERE state=1 AND lessonday=? ORDER BY lessonstoptime"), {today.dayOfWeek() - 1});

    for (const auto &row : rows) {
        const QTime stop = QTime::fromString(row.value(QStringLiteral("stop")).toString(), QStringLiteral("HH:mm"));
        if (!stop.isValid())
            continue;
        const int seconds = now.secsTo(stop);
        // lesson times only have minute precision.  Polling once per minute should
        // therefore match the full target minute rather than a fragile 10 s window.
        if (seconds > (minutes - 1) * 60 && seconds <= minutes * 60) {
            QVariantMap warning = row;
            warning.insert(QStringLiteral("minutes"), minutes);
            warning.insert(QStringLiteral("description"),
                           tr("Lesson %1 ends in %n minute(s).", nullptr, minutes)
                               .arg(row.value(QStringLiteral("name")).toString()));
            result << warning;
        }
    }
    return result;
}

int AppController::saveReminder(const QVariantMap &v)
{
    if (v.value(QStringLiteral("description")).toString().trimmed().isEmpty()) {
        setError(tr("Reminder text must not be empty."));
        return -1;
    }
    const int id = v.value(QStringLiteral("id"), -1).toInt();
    const QVariantList binds = {v.value(QStringLiteral("description")).toString().trimmed(),
                                v.value(QStringLiteral("mode"), 0), v.value(QStringLiteral("pupilId"), -1),
                                v.value(QStringLiteral("sound"), false).toBool() ? 1 : 0};
    int resultId = id;
    if (id < 0)
        resultId = int(insert(QStringLiteral("INSERT INTO reminder (desc,mode,pupilid,notificationsound) VALUES (?,?,?,?)"), binds));
    else {
        QVariantList updateBinds = binds;
        updateBinds << id;
        if (!execute(QStringLiteral("UPDATE reminder SET desc=?,mode=?,pupilid=?,notificationsound=? WHERE reminderid=?"), updateBinds))
            return -1;
    }
    refreshReminders();
    emit dataChanged();
    return resultId;
}

bool AppController::deleteReminder(int reminderId)
{
    if (!execute(QStringLiteral("DELETE FROM reminder WHERE reminderid=?"), {reminderId}))
        return false;
    refreshReminders();
    emit dataChanged();
    return true;
}

int AppController::addSheetMusic(const QString &author, const QString &title, const QString &publisher)
{
    if (author.trimmed().isEmpty() || title.trimmed().isEmpty() || publisher.trimmed().isEmpty()) {
        setError(tr("Author, title and publisher are required."));
        return -1;
    }
    const int authorId = ensureLookupId(QStringLiteral("smlauthor"), QStringLiteral("smlauthorid"),
                                        QStringLiteral("author"), author.trimmed());
    const int publisherId = ensureLookupId(QStringLiteral("smlpublisher"), QStringLiteral("smlpublisherid"),
                                           QStringLiteral("publisher"), publisher.trimmed());
    if (authorId < 0 || publisherId < 0)
        return -1;
    const int id = int(insert(QStringLiteral(
        "INSERT INTO sheetmusiclibrary (author,title,publisher,rentpupilid) VALUES (?,?,?,-1)"),
        {authorId, title.trimmed(), publisherId}));
    if (id >= 0) {
        refreshLibrary();
        emit dataChanged();
    }
    return id;
}

bool AppController::deleteSheetMusic(int smlId)
{
    if (!execute(QStringLiteral("DELETE FROM sheetmusiclibrary WHERE smlid=?"), {smlId}))
        return false;
    refreshLibrary();
    emit dataChanged();
    return true;
}

bool AppController::loanSheetMusic(int smlId, int pupilId)
{
    if (!execute(QStringLiteral("UPDATE sheetmusiclibrary SET rentpupilid=?,lastrentdate=? WHERE smlid=?"),
                 {pupilId, isoToday(), smlId}))
        return false;
    refreshLibrary();
    emit dataChanged();
    return true;
}

bool AppController::returnSheetMusic(int smlId)
{
    if (!execute(QStringLiteral("UPDATE sheetmusiclibrary SET rentpupilid=-1 WHERE smlid=?"), {smlId}))
        return false;
    refreshLibrary();
    emit dataChanged();
    return true;
}

QVariantMap AppController::recital(int recitalId) const
{
    return selectOne(QStringLiteral(
        "SELECT recitalid AS id, COALESCE(desc,'') AS description, COALESCE(date,'') AS date, "
        "COALESCE(time,'') AS time, COALESCE(location,'') AS location, COALESCE(organisator,'') AS organizer, "
        "COALESCE(defaultaccompanist,'') AS accompanist, COALESCE(state,0) AS state FROM recital WHERE recitalid=?"),
        {recitalId});
}

int AppController::saveRecital(const QVariantMap &v)
{
    const int id = v.value(QStringLiteral("id"), -1).toInt();
    const QVariantList binds = {v.value(QStringLiteral("description")), v.value(QStringLiteral("date")),
                                v.value(QStringLiteral("time")), v.value(QStringLiteral("location")),
                                v.value(QStringLiteral("organizer")), v.value(QStringLiteral("accompanist")),
                                v.value(QStringLiteral("state"), 0)};
    int resultId = id;
    if (id < 0)
        resultId = int(insert(QStringLiteral(
            "INSERT INTO recital (desc,date,time,location,organisator,defaultaccompanist,state) VALUES (?,?,?,?,?,?,?)"), binds));
    else {
        QVariantList updateBinds = binds;
        updateBinds << id;
        if (!execute(QStringLiteral(
            "UPDATE recital SET desc=?,date=?,time=?,location=?,organisator=?,defaultaccompanist=?,state=? WHERE recitalid=?"),
                     updateBinds))
            return -1;
    }
    refreshRecitals();
    emit dataChanged();
    return resultId;
}

bool AppController::deleteRecital(int recitalId)
{
    QSqlDatabase &db = m_database.database();
    if (!db.transaction()) {
        setError(db.lastError().text());
        return false;
    }
    if (!execute(QStringLiteral("DELETE FROM pieceatrecital WHERE recitalid=?"), {recitalId}) ||
        !execute(QStringLiteral("DELETE FROM recital WHERE recitalid=?"), {recitalId})) {
        db.rollback();
        return false;
    }
    if (!db.commit()) {
        setError(db.lastError().text());
        return false;
    }
    refreshRecitals();
    emit dataChanged();
    return true;
}

QVariantList AppController::recitalPieces(int recitalId) const
{
    QVariantList result;
    auto rows = selectRows(QStringLiteral(
        "SELECT par.parid AS parId, par.pieceid AS pieceId, par.sorting AS sorting, par.ifexternalpiece AS external, "
        "CASE WHEN par.ifexternalpiece=0 THEN COALESCE(pc.composer,'') ELSE COALESCE(ep.composer,'') END AS composer, "
        "CASE WHEN par.ifexternalpiece=0 THEN COALESCE(p.title,'') ELSE COALESCE(ep.title,'') END AS title, "
        "CASE WHEN par.ifexternalpiece=0 THEN COALESCE(p.genre,'') ELSE COALESCE(ep.genre,'') END AS genre, "
        "CASE WHEN par.ifexternalpiece=0 THEN COALESCE(p.duration,0) ELSE COALESCE(ep.duration,0) END AS duration, "
        "CASE WHEN par.ifexternalpiece=1 THEN COALESCE(ep.musician,'') ELSE '' END AS externalMusician "
        "FROM pieceatrecital par LEFT JOIN piece p ON par.ifexternalpiece=0 AND p.pieceid=par.pieceid "
        "LEFT JOIN piececomposer pc ON pc.piececomposerid=p.piececomposerid "
        "LEFT JOIN externalrecitalpiece ep ON par.ifexternalpiece=1 AND ep.erpid=par.pieceid "
        "WHERE par.recitalid=? ORDER BY par.sorting, par.parid"), {recitalId});

    const QDate today = QDate::currentDate();

    for (QVariantMap row : rows) {
        QStringList musicians;

        if (row.value(QStringLiteral("external")).toBool()) {
            const QString musician = row.value(QStringLiteral("externalMusician")).toString().trimmed();
            if (!musician.isEmpty())
                musicians << musician;
        } else {
            // Shared/group pieces have one row per pupil with the same cpieceid.
            // Resolve every performer from that common piece relation so the event
            // overview shows the same people that belong to the performed piece.
            const auto people = selectRows(QStringLiteral(
                "SELECT DISTINCT pu.pupilid AS pupilId, COALESCE(pu.forename,'') AS forename, "
                "COALESCE(pu.surname,'') AS surname, COALESCE(pu.birthday,'') AS birthday, "
                "COALESCE(pu.instrumenttype,'') AS instrument "
                "FROM piece anchor "
                "JOIN piece linked ON (CASE WHEN linked.cpieceid IS NULL OR linked.cpieceid<=0 THEN linked.pieceid ELSE linked.cpieceid END)="
                "(CASE WHEN anchor.cpieceid IS NULL OR anchor.cpieceid<=0 THEN anchor.pieceid ELSE anchor.cpieceid END) "
                "JOIN pupilatlesson pal ON pal.palid=linked.palid "
                "JOIN pupil pu ON pu.pupilid=pal.pupilid "
                "WHERE anchor.pieceid=? "
                "ORDER BY pu.birthday, pu.surname COLLATE NOCASE, pu.forename COLLATE NOCASE"),
                {row.value(QStringLiteral("pieceId"))});

            for (const QVariantMap &person : people) {
                const QString forename = person.value(QStringLiteral("forename")).toString().trimmed();
                const QString surname = person.value(QStringLiteral("surname")).toString().trimmed();
                const QString instrument = person.value(QStringLiteral("instrument")).toString().trimmed();
                const QDate birthday = QDate::fromString(person.value(QStringLiteral("birthday")).toString(), Qt::ISODate);

                QString displayName;
                if (!surname.isEmpty() && !forename.isEmpty())
                    displayName = QStringLiteral("%1, %2").arg(surname, forename);
                else
                    displayName = surname.isEmpty() ? forename : surname;

                if (birthday.isValid()) {
                    int age = today.year() - birthday.year();
                    QDate birthdayThisYear(today.year(), birthday.month(), birthday.day());
                    if (!birthdayThisYear.isValid())
                        birthdayThisYear = QDate(today.year(), 2, 28);
                    if (birthdayThisYear > today)
                        --age;
                    if (age >= 0)
                        displayName += QStringLiteral(" (%1)").arg(age);
                }

                if (!instrument.isEmpty())
                    displayName += QStringLiteral(" - %1").arg(instrument);

                if (!displayName.isEmpty())
                    musicians << displayName;
            }
        }

        row.remove(QStringLiteral("externalMusician"));
        row.insert(QStringLiteral("musicians"), musicians.join(QStringLiteral(" · ")));
        row.insert(QStringLiteral("musicianCount"), musicians.size());
        result << row;
    }
    return result;
}

QVariantList AppController::readyPieces() const
{
    QVariantList result;
    const auto rows = selectRows(QStringLiteral(
        "SELECT MIN(p.pieceid) AS id, p.cpieceid AS commonId, COALESCE(pc.composer,'') AS composer, "
        "COALESCE(p.title,'') AS title, COALESCE(p.genre,'') AS genre, COALESCE(p.duration,0) AS duration, "
        "COALESCE(l.lessonname,'') AS lessonName, COALESCE(GROUP_CONCAT(TRIM(pu.forename || ' ' || pu.surname), ', '),'') AS pupils "
        "FROM piece p JOIN pupilatlesson pal ON pal.palid=p.palid JOIN pupil pu ON pu.pupilid=pal.pupilid "
        "JOIN lesson l ON l.lessonid=pal.lessonid LEFT JOIN piececomposer pc ON pc.piececomposerid=p.piececomposerid "
        "WHERE p.state=3 AND pal.stopdate > date('now') GROUP BY p.cpieceid ORDER BY pu.birthday,p.title"));
    for (const auto &row : rows)
        result << row;
    return result;
}

bool AppController::addPieceToRecital(int recitalId, int pieceId)
{
    const int existing = selectOne(QStringLiteral(
        "SELECT COUNT(*) AS n FROM pieceatrecital WHERE recitalid=? AND pieceid=? AND ifexternalpiece=0"),
        {recitalId, pieceId}).value(QStringLiteral("n")).toInt();
    if (existing > 0)
        return true;
    const int sorting = selectOne(QStringLiteral("SELECT COALESCE(MAX(sorting),-1)+1 AS n FROM pieceatrecital WHERE recitalid=?"),
                                  {recitalId}).value(QStringLiteral("n")).toInt();
    if (insert(QStringLiteral(
        "INSERT INTO pieceatrecital (pieceid,recitalid,sorting,ifexternalpiece) VALUES (?,?,?,0)"),
        {pieceId, recitalId, sorting}) < 0)
        return false;
    emit dataChanged();
    return true;
}

bool AppController::addExternalPieceToRecital(int recitalId, const QString &composer, const QString &title,
                                                    const QString &genre, int duration, const QString &musician)
{
    if (title.trimmed().isEmpty()) {
        setError(tr("Title is required."));
        return false;
    }
    QSqlDatabase &db = m_database.database();
    if (!db.transaction()) {
        setError(db.lastError().text());
        return false;
    }
    const qint64 externalId = insert(QStringLiteral(
        "INSERT INTO externalrecitalpiece (composer,title,genre,duration,musician) VALUES (?,?,?,?,?)"),
        {composer.trimmed(), title.trimmed(), genre, duration, musician});
    const int sorting = selectOne(QStringLiteral("SELECT COALESCE(MAX(sorting),-1)+1 AS n FROM pieceatrecital WHERE recitalid=?"),
                                  {recitalId}).value(QStringLiteral("n")).toInt();
    if (externalId < 0 || insert(QStringLiteral(
            "INSERT INTO pieceatrecital (pieceid,recitalid,sorting,ifexternalpiece) VALUES (?,?,?,1)"),
            {externalId, recitalId, sorting}) < 0) {
        db.rollback();
        return false;
    }
    if (!db.commit()) {
        setError(db.lastError().text());
        return false;
    }
    emit dataChanged();
    return true;
}

bool AppController::removePieceFromRecital(int parId)
{
    const QVariantMap row = selectOne(QStringLiteral(
        "SELECT pieceid AS pieceId, ifexternalpiece AS external FROM pieceatrecital WHERE parid=?"), {parId});
    if (!execute(QStringLiteral("DELETE FROM pieceatrecital WHERE parid=?"), {parId}))
        return false;
    if (row.value(QStringLiteral("external")).toBool())
        execute(QStringLiteral("DELETE FROM externalrecitalpiece WHERE erpid=?"), {row.value(QStringLiteral("pieceId"))});
    emit dataChanged();
    return true;
}

bool AppController::saveRecitalPieceOrder(int recitalId, const QVariantList &parIds)
{
    const auto currentRows = selectRows(QStringLiteral(
        "SELECT parid AS parId FROM pieceatrecital WHERE recitalid=? ORDER BY sorting,parid"),
        {recitalId});

    if (currentRows.size() != parIds.size()) {
        setError(tr("The program changed while its order was being edited."));
        return false;
    }

    QSet<int> expected;
    for (const QVariantMap &row : currentRows)
        expected.insert(row.value(QStringLiteral("parId")).toInt());

    QSet<int> supplied;
    for (const QVariant &value : parIds) {
        const int parId = value.toInt();
        if (!expected.contains(parId) || supplied.contains(parId)) {
            setError(tr("The program order is invalid."));
            return false;
        }
        supplied.insert(parId);
    }

    if (supplied != expected) {
        setError(tr("The program order is incomplete."));
        return false;
    }

    QSqlDatabase &db = m_database.database();
    if (!db.transaction()) {
        setError(db.lastError().text());
        return false;
    }

    for (int sorting = 0; sorting < parIds.size(); ++sorting) {
        if (!execute(QStringLiteral(
                "UPDATE pieceatrecital SET sorting=? WHERE recitalid=? AND parid=?"),
                {sorting, recitalId, parIds.at(sorting).toInt()})) {
            db.rollback();
            return false;
        }
    }

    if (!db.commit()) {
        setError(db.lastError().text());
        return false;
    }

    clearError();
    emit dataChanged();
    return true;
}

bool AppController::finishRecital(int recitalId, bool createActivities, bool finishPieces)
{
    const QVariantMap event = recital(recitalId);
    if (event.isEmpty())
        return false;

    QSqlDatabase &db = m_database.database();
    if (!db.transaction()) {
        setError(db.lastError().text());
        return false;
    }

    const auto linked = selectRows(QStringLiteral(
        "SELECT pieceid AS pieceId FROM pieceatrecital WHERE recitalid=? AND ifexternalpiece=0"), {recitalId});

    if (createActivities) {
        for (const QVariantMap &item : linked) {
            const int pieceId = item.value(QStringLiteral("pieceId")).toInt();
            const QVariantMap pieceInfo = selectOne(QStringLiteral(
                "SELECT COALESCE(pc.composer,'') AS composer, COALESCE(p.title,'') AS title "
                "FROM piece p LEFT JOIN piececomposer pc ON pc.piececomposerid=p.piececomposerid WHERE p.pieceid=?"), {pieceId});
            const auto pupils = selectRows(QStringLiteral(
                "SELECT DISTINCT pal.pupilid AS pupilId, l.type AS lessonType FROM piece p "
                "JOIN pupilatlesson pal ON pal.palid=p.palid JOIN lesson l ON l.lessonid=pal.lessonid "
                "WHERE p.cpieceid=(SELECT cpieceid FROM piece WHERE pieceid=?)"), {pieceId});
            for (const QVariantMap &pupilRow : pupils) {
                const int activityType = pupilRow.value(QStringLiteral("lessonType")).toInt() == 3 ? 1 : 0;
                const QString desc = QStringLiteral("%1, %2: %3 - %4")
                    .arg(event.value(QStringLiteral("description")).toString(),
                         event.value(QStringLiteral("location")).toString(),
                         pieceInfo.value(QStringLiteral("composer")).toString(),
                         pieceInfo.value(QStringLiteral("title")).toString());
                if (insert(QStringLiteral(
                    "INSERT INTO activity (pupilid,ifcontinous,desc,date,noncontinoustype) VALUES (?,0,?,?,?)"),
                    {pupilRow.value(QStringLiteral("pupilId")), desc, event.value(QStringLiteral("date")), activityType}) < 0) {
                    db.rollback();
                    return false;
                }
            }
        }
    }

    if (finishPieces) {
        for (const QVariantMap &item : linked) {
            if (!execute(QStringLiteral(
                "UPDATE piece SET state=4,stopdate=? WHERE cpieceid=(SELECT cpieceid FROM piece WHERE pieceid=?)"),
                {isoToday(), item.value(QStringLiteral("pieceId"))})) {
                db.rollback();
                return false;
            }
        }
    }

    if (!execute(QStringLiteral("UPDATE recital SET state=1 WHERE recitalid=?"), {recitalId})) {
        db.rollback();
        return false;
    }
    if (!db.commit()) {
        setError(db.lastError().text());
        return false;
    }
    refreshAll();
    return true;
}

QString AppController::legacyConfigPath() const
{
#ifdef Q_OS_WIN
    const QString appData = qEnvironmentVariable("APPDATA");
    if (!appData.isEmpty())
        return QDir(appData).filePath(QStringLiteral("qupil/config.xml"));
#endif
    return QDir::home().filePath(QStringLiteral(".qupil/config.xml"));
}

void AppController::importLegacySettings()
{
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    return;
#else
    QSettings settings;
    if (settings.value(QStringLiteral("migration/legacyConfigImported"), false).toBool())
        return;

    const QString path = legacyConfigPath();
    if (!QFileInfo::exists(path))
        return;

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    const QHash<QString, QString> listKeys = {
        {QStringLiteral("PalPiecesGenreList"), QStringLiteral("genres")},
        {QStringLiteral("LessonLocationList"), QStringLiteral("lessonLocations")},
        {QStringLiteral("PupilInstrumentList"), QStringLiteral("instruments")},
        {QStringLiteral("PupilInstrumentSizeList"), QStringLiteral("instrumentSizes")}
    };
    const QHash<QString, QString> valueKeys = {
        {QStringLiteral("BirthdayReminder"), QStringLiteral("birthdayReminder")},
        {QStringLiteral("LessonEndMsg"), QStringLiteral("lessonEndReminder")},
        {QStringLiteral("MinutesToLessonEndForMsg"), QStringLiteral("minutesToLessonEndReminder")},
        {QStringLiteral("RecitalIntervalCheckerOnlySolo"), QStringLiteral("recitalIntervalSoloOnly")},
        {QStringLiteral("SaveNotesPiecesForAllPupil"), QStringLiteral("saveNotesPiecesForAllPupils")},
        {QStringLiteral("LimitLoadLessonNotes"), QStringLiteral("limitLessonNotes")},
        {QStringLiteral("LoadLessonNotesNumber"), QStringLiteral("lessonNotesNumber")},
        {QStringLiteral("LimitLoadMusicPieces"), QStringLiteral("limitMusicPieces")},
        {QStringLiteral("LoadMusicPiecesNumber"), QStringLiteral("musicPiecesNumber")},
        {QStringLiteral("RecitalModerationDuration"), QStringLiteral("recitalModerationDuration")},
        {QStringLiteral("RecitalBetweenPiecesDuration"), QStringLiteral("recitalBetweenPiecesDuration")}
    };

    QXmlStreamReader xml(&file);
    bool importedAnything = false;
    while (!xml.atEnd()) {
        xml.readNext();
        if (!xml.isStartElement())
            continue;

        const QString elementName = xml.name().toString();
        const auto listIt = listKeys.constFind(elementName);
        if (listIt != listKeys.cend()) {
            QStringList values;
            const QString containerName = elementName;
            while (!xml.atEnd()) {
                xml.readNext();
                if (xml.isEndElement() && xml.name().toString() == containerName)
                    break;
                if (xml.isStartElement()) {
                    const QString value = xml.attributes().value(QStringLiteral("value")).toString();
                    if (!value.isEmpty())
                        values.push_back(value);
                }
            }
            if (!values.isEmpty()) {
                settings.setValue(QStringLiteral("lists/") + listIt.value(), values);
                importedAnything = true;
            }
            continue;
        }

        const auto valueIt = valueKeys.constFind(elementName);
        if (valueIt != valueKeys.cend()) {
            const QString value = xml.attributes().value(QStringLiteral("value")).toString();
            bool ok = false;
            const int integerValue = value.toInt(&ok);
            settings.setValue(QStringLiteral("settings/") + valueIt.value(), ok ? QVariant(integerValue) : QVariant(value));
            importedAnything = true;
        }
    }

    if (!xml.hasError()) {
        settings.setValue(QStringLiteral("migration/legacyConfigImported"), true);
        settings.setValue(QStringLiteral("migration/legacyConfigPath"), path);
        settings.setValue(QStringLiteral("migration/legacyConfigHadValues"), importedAnything);
    }
#endif
}

QStringList AppController::settingList(const QString &key) const
{
    QSettings settings;
    const QVariant value = settings.value(QStringLiteral("lists/") + key);
    if (value.isValid())
        return value.toStringList();

    if (key == QStringLiteral("lessonLocations"))
        return {tr("Music school"), tr("Home")};
    if (key == QStringLiteral("genres"))
        return {tr("Tune"), tr("Etude"), tr("Sonata"), tr("Concerto"), tr("Other")};
    if (key == QStringLiteral("instruments"))
        return {tr("Violin"), tr("Viola"), tr("Cello"), tr("Double bass"), tr("Piano")};
    if (key == QStringLiteral("instrumentSizes"))
        return {QStringLiteral("4/4"), QStringLiteral("3/4"), QStringLiteral("1/2"),
                QStringLiteral("1/4"), QStringLiteral("1/8"), QStringLiteral("1/16")};
    return {};
}

void AppController::setSettingList(const QString &key, const QStringList &values)
{
    QSettings settings;
    settings.setValue(QStringLiteral("lists/") + key, values);
}

QVariant AppController::settingValue(const QString &key, const QVariant &fallback) const
{
    QSettings settings;
    return settings.value(QStringLiteral("settings/") + key, fallback);
}

void AppController::setSettingValue(const QString &key, const QVariant &value)
{
    QSettings settings;
    settings.setValue(QStringLiteral("settings/") + key, value);
}

// SPDX-License-Identifier: GPL-2.0-or-later
#include "databasemanager.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QDateTime>
#include <QUuid>

DatabaseManager::DatabaseManager()
    : m_connectionName(QStringLiteral("qupil-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces)))
{
}

DatabaseManager::~DatabaseManager()
{
    if (m_db.isValid()) {
        m_db.close();
        m_db = {};
    }
    QSqlDatabase::removeDatabase(m_connectionName);
}

void DatabaseManager::setError(const QString &message)
{
    m_lastError = message;
}

QString DatabaseManager::legacyDatabasePath() const
{
#ifdef Q_OS_WIN
    const QString appData = qEnvironmentVariable("APPDATA");
    if (!appData.isEmpty())
        return QDir(appData).filePath(QStringLiteral("qupil/db/qupil.db"));
#endif
    return QDir::home().filePath(QStringLiteral(".qupil/db/qupil.db"));
}

bool DatabaseManager::prepareStorage()
{
    const QString overrideDir = qEnvironmentVariable("QUPIL_DATA_DIR");
    QString dataRoot = overrideDir;
    if (dataRoot.isEmpty())
        dataRoot = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (dataRoot.isEmpty()) {
        setError(QStringLiteral("No writable application data directory is available."));
        return false;
    }

    const QString dbDir = QDir(dataRoot).filePath(QStringLiteral("db"));
    if (!QDir().mkpath(dbDir)) {
        setError(QStringLiteral("Could not create database directory: %1").arg(dbDir));
        return false;
    }

    m_databasePath = QDir(dbDir).filePath(QStringLiteral("qupil.db"));

#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS)
    // Never modify the historical ~/.qupil database merely by launching the
    // new application. Copy it once into the new platform-standard location.
    const QString legacy = legacyDatabasePath();
    if (!QFileInfo::exists(m_databasePath) && QFileInfo::exists(legacy)) {
        if (!QFile::copy(legacy, m_databasePath)) {
            setError(QStringLiteral("Could not copy legacy database from %1 to %2")
                         .arg(legacy, m_databasePath));
            return false;
        }
        m_importedLegacyDatabase = true;
    }
#endif
    return true;
}

bool DatabaseManager::open()
{
    if (!prepareStorage())
        return false;

    if (!QSqlDatabase::isDriverAvailable(QStringLiteral("QSQLITE"))) {
        setError(QStringLiteral("The Qt QSQLITE driver is not available in this application package."));
        return false;
    }

    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connectionName);
    m_db.setDatabaseName(m_databasePath);
    if (!m_db.open()) {
        setError(m_db.lastError().text());
        return false;
    }

    QSqlQuery pragma(m_db);
    pragma.exec(QStringLiteral("PRAGMA foreign_keys = OFF")); // legacy schema has no FK constraints
    pragma.exec(QStringLiteral("PRAGMA journal_mode = WAL"));
    pragma.exec(QStringLiteral("PRAGMA busy_timeout = 5000"));

    return ensureSchema();
}

bool DatabaseManager::checkpoint()
{
    if (!m_db.isOpen())
        return false;
    QSqlQuery query(m_db);
    if (!query.exec(QStringLiteral("PRAGMA wal_checkpoint(FULL)"))) {
        setError(query.lastError().text());
        return false;
    }
    return true;
}

bool DatabaseManager::restoreFrom(const QString &sourcePath)
{
    if (sourcePath.isEmpty() || !QFileInfo::exists(sourcePath)) {
        setError(QStringLiteral("The selected backup does not exist."));
        return false;
    }

    const QString validationConnection = QStringLiteral("qupil-restore-check-%1")
                                             .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    bool valid = false;
    QString validationError;
    {
        QSqlDatabase sourceDb = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), validationConnection);
        sourceDb.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
        sourceDb.setDatabaseName(sourcePath);
        if (!sourceDb.open()) {
            validationError = sourceDb.lastError().text();
        } else {
            const QStringList tables = sourceDb.tables();
            valid = tables.contains(QStringLiteral("pupil"), Qt::CaseInsensitive)
                 && tables.contains(QStringLiteral("lesson"), Qt::CaseInsensitive)
                 && tables.contains(QStringLiteral("piece"), Qt::CaseInsensitive);
            if (valid && tables.contains(QStringLiteral("dbinfos"), Qt::CaseInsensitive)) {
                QSqlQuery revisionQuery(sourceDb);
                if (revisionQuery.exec(QStringLiteral("SELECT data_structure_rev FROM dbinfos WHERE id=0"))
                    && revisionQuery.next() && revisionQuery.value(0).toInt() > 4) {
                    valid = false;
                    validationError = QStringLiteral("The backup uses a newer database schema revision.");
                }
            }
            if (!valid && validationError.isEmpty())
                validationError = QStringLiteral("The selected file is not a recognized Qupil database.");
            sourceDb.close();
        }
    }
    QSqlDatabase::removeDatabase(validationConnection);
    if (!valid) {
        setError(validationError);
        return false;
    }

    checkpoint();
    m_db.close();

    const QString staging = m_databasePath + QStringLiteral(".restore-new");
    QFile::remove(staging);
    if (!QFile::copy(sourcePath, staging)) {
        setError(QStringLiteral("Could not stage the selected backup."));
        m_db.open();
        return false;
    }

    const QString safety = m_databasePath + QStringLiteral(".before-restore-")
                         + QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-hhmmss"))
                         + QStringLiteral(".db");
    QFile::remove(m_databasePath + QStringLiteral("-wal"));
    QFile::remove(m_databasePath + QStringLiteral("-shm"));

    if (QFileInfo::exists(m_databasePath) && !QFile::rename(m_databasePath, safety)) {
        QFile::remove(staging);
        setError(QStringLiteral("Could not create the pre-restore safety copy."));
        m_db.open();
        return false;
    }
    if (!QFile::rename(staging, m_databasePath)) {
        if (QFileInfo::exists(safety))
            QFile::rename(safety, m_databasePath);
        setError(QStringLiteral("Could not replace the active database."));
        m_db.open();
        return false;
    }

    if (!m_db.open() || !ensureSchema()) {
        const QString failedError = m_db.isOpen() ? m_lastError : m_db.lastError().text();
        m_db.close();
        QFile::remove(m_databasePath);
        if (QFileInfo::exists(safety))
            QFile::rename(safety, m_databasePath);
        if (m_db.open()) {
            QSqlQuery pragma(m_db);
            pragma.exec(QStringLiteral("PRAGMA foreign_keys = OFF"));
            pragma.exec(QStringLiteral("PRAGMA journal_mode = WAL"));
            pragma.exec(QStringLiteral("PRAGMA busy_timeout = 5000"));
        }
        setError(QStringLiteral("Restore failed; the previous database was put back. %1").arg(failedError));
        return false;
    }

    QSqlQuery pragma(m_db);
    pragma.exec(QStringLiteral("PRAGMA foreign_keys = OFF"));
    pragma.exec(QStringLiteral("PRAGMA journal_mode = WAL"));
    pragma.exec(QStringLiteral("PRAGMA busy_timeout = 5000"));
    return true;
}

bool DatabaseManager::tableExists(const QString &table) const
{
    return m_db.tables().contains(table, Qt::CaseInsensitive);
}

bool DatabaseManager::columnExists(const QString &table, const QString &column) const
{
    QSqlQuery query(m_db);
    if (!query.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table)))
        return false;
    while (query.next()) {
        if (query.value(1).toString().compare(column, Qt::CaseInsensitive) == 0)
            return true;
    }
    return false;
}

bool DatabaseManager::exec(const QString &sql)
{
    QSqlQuery query(m_db);
    if (!query.exec(sql)) {
        setError(QStringLiteral("%1\nSQL: %2").arg(query.lastError().text(), sql));
        return false;
    }
    return true;
}

bool DatabaseManager::ensureColumn(const QString &table, const QString &column, const QString &definition)
{
    if (columnExists(table, column))
        return true;
    return exec(QStringLiteral("ALTER TABLE %1 ADD COLUMN %2 %3").arg(table, column, definition));
}

bool DatabaseManager::ensureSchema()
{
    if (!m_db.transaction()) {
        setError(m_db.lastError().text());
        return false;
    }

    const QStringList createStatements = {
        QStringLiteral("CREATE TABLE IF NOT EXISTS pupil (pupilid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, surname TEXT, forename TEXT, address TEXT, email TEXT, telefon TEXT, handy TEXT, birthday TEXT, notes TEXT, fathername TEXT, fatherjob TEXT, fathertelefon TEXT, mothername TEXT, motherjob TEXT, mothertelefon TEXT, firstlessondate TEXT, instrumenttype TEXT, instrumentsize TEXT, ifinstrumentnextsize INTEGER DEFAULT 0, ifrentinstrument INTEGER DEFAULT 0, rentinstrumentdesc TEXT, rentinstrumentstartdate TEXT, recitalinterval INTEGER NOT NULL DEFAULT 5, ensembleactivityrequested INTEGER NOT NULL DEFAULT 1)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS pupilarchive (pupilid INTEGER NOT NULL PRIMARY KEY, surname TEXT, forename TEXT, data TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS lesson (lessonid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, state INTEGER DEFAULT 1, type INTEGER DEFAULT 1, autolessonname INTEGER DEFAULT 1, lessonname TEXT, unsteadylesson INTEGER DEFAULT 1, lessonday INTEGER, lessonstarttime TEXT, lessonstoptime TEXT, lessonlocation TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS lastlessonname (llnid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, lessonname TEXT, namekind INTEGER NOT NULL DEFAULT 0, lessontype INTEGER, durationminutes INTEGER, locationtoken TEXT, pupiltoken TEXT, formatrev INTEGER NOT NULL DEFAULT 1)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS pupilatlesson (palid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, lessonid INTEGER NOT NULL, pupilid INTEGER NOT NULL, llnid INTEGER, startdate TEXT, stopdate TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS piececomposer (piececomposerid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, composer TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS piece (pieceid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, cpieceid INTEGER, palid INTEGER, title TEXT, genre TEXT, duration INTEGER, startdate TEXT, stopdate TEXT, state INTEGER, piececomposerid INTEGER DEFAULT 1)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS note (noteid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, cnoteid INTEGER, palid INTEGER, date TEXT, content TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS activity (activityid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, pupilid INTEGER, ifcontinous INTEGER, desc TEXT, continousday INTEGER, continoustime TEXT, date TEXT, continousstopdate TEXT, noncontinoustype INTEGER NOT NULL DEFAULT 0, continoustype INTEGER NOT NULL DEFAULT 0)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS sheetmusiclibrary (smlid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, author INTEGER, title TEXT, publisher INTEGER, rentpupilid INTEGER DEFAULT -1, lastrentdate TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS smlauthor (smlauthorid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, author TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS smlpublisher (smlpublisherid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, publisher TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS recital (recitalid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, desc TEXT, date TEXT, time TEXT, location TEXT, organisator TEXT, defaultaccompanist TEXT, state INTEGER DEFAULT 0)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS recitalarchive (recitalid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, desc TEXT, data TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS pieceatrecital (parid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, pieceid INTEGER NOT NULL, recitalid INTEGER NOT NULL, sorting INTEGER DEFAULT 0, ifexternalpiece INTEGER DEFAULT 0)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS externalrecitalpiece (erpid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, composer TEXT, title TEXT, genre TEXT, duration INTEGER, musician TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS reminder (reminderid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, desc TEXT, mode INTEGER DEFAULT 0, pupilid INTEGER, notificationsound INTEGER DEFAULT 0)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS dbinfos (id INTEGER PRIMARY KEY NOT NULL, data_structure_rev INTEGER NOT NULL)")
    };

    for (const QString &sql : createStatements) {
        if (!exec(sql)) {
            m_db.rollback();
            return false;
        }
    }

    // Idempotently lift legacy databases to the current revision-4 schema.
    if (!ensureColumn(QStringLiteral("pupil"), QStringLiteral("recitalinterval"), QStringLiteral("INTEGER NOT NULL DEFAULT 5")) ||
        !ensureColumn(QStringLiteral("pupil"), QStringLiteral("ensembleactivityrequested"), QStringLiteral("INTEGER NOT NULL DEFAULT 1")) ||
        !ensureColumn(QStringLiteral("piece"), QStringLiteral("piececomposerid"), QStringLiteral("INTEGER DEFAULT 1")) ||
        !ensureColumn(QStringLiteral("activity"), QStringLiteral("noncontinoustype"), QStringLiteral("INTEGER NOT NULL DEFAULT 0")) ||
        !ensureColumn(QStringLiteral("activity"), QStringLiteral("continoustype"), QStringLiteral("INTEGER NOT NULL DEFAULT 0")) ||
        !ensureColumn(QStringLiteral("lastlessonname"), QStringLiteral("namekind"), QStringLiteral("INTEGER NOT NULL DEFAULT 0")) ||
        !ensureColumn(QStringLiteral("lastlessonname"), QStringLiteral("lessontype"), QStringLiteral("INTEGER")) ||
        !ensureColumn(QStringLiteral("lastlessonname"), QStringLiteral("durationminutes"), QStringLiteral("INTEGER")) ||
        !ensureColumn(QStringLiteral("lastlessonname"), QStringLiteral("locationtoken"), QStringLiteral("TEXT")) ||
        !ensureColumn(QStringLiteral("lastlessonname"), QStringLiteral("pupiltoken"), QStringLiteral("TEXT")) ||
        !ensureColumn(QStringLiteral("lastlessonname"), QStringLiteral("formatrev"), QStringLiteral("INTEGER NOT NULL DEFAULT 1"))) {
        m_db.rollback();
        return false;
    }

    if (!exec(QStringLiteral("UPDATE activity SET continousstopdate='9999-99-99' WHERE continousstopdate IS NULL")) ||
        !exec(QStringLiteral("INSERT OR IGNORE INTO piececomposer (piececomposerid, composer) VALUES (1, '')")) ||
        !exec(QStringLiteral("INSERT OR IGNORE INTO smlauthor (smlauthorid, author) VALUES (1, '')")) ||
        !exec(QStringLiteral("INSERT OR IGNORE INTO smlpublisher (smlpublisherid, publisher) VALUES (1, '')")) ||
        !exec(QStringLiteral("REPLACE INTO dbinfos (id, data_structure_rev) VALUES (0, 4)"))) {
        m_db.rollback();
        return false;
    }

    if (!m_db.commit()) {
        setError(m_db.lastError().text());
        return false;
    }
    return true;
}

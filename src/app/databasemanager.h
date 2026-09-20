// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QSqlDatabase>
#include <QString>

class DatabaseManager
{
public:
    DatabaseManager();
    ~DatabaseManager();

    bool open();
    bool checkpoint();
    bool restoreFrom(const QString &sourcePath);
    QSqlDatabase &database() { return m_db; }
    const QSqlDatabase &database() const { return m_db; }

    QString databasePath() const { return m_databasePath; }
    QString lastError() const { return m_lastError; }
    bool importedLegacyDatabase() const { return m_importedLegacyDatabase; }

private:
    bool ensureSchema();
    bool ensureColumn(const QString &table, const QString &column, const QString &definition);
    bool exec(const QString &sql);
    bool tableExists(const QString &table) const;
    bool columnExists(const QString &table, const QString &column) const;
    bool prepareStorage();
    QString legacyDatabasePath() const;
    void setError(const QString &message);

    QString m_connectionName;
    QSqlDatabase m_db;
    QString m_databasePath;
    QString m_lastError;
    bool m_importedLegacyDatabase = false;
};

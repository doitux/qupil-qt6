/***************************************************************************
 *   Copyright (C) 2026 Qupil contributors                                *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 ***************************************************************************/
#include "csvtablemodel.h"

#include <QFile>
#include <QIODevice>

CsvTableModel::CsvTableModel(QObject *parent)
    : QAbstractTableModel(parent)
{
}

int CsvTableModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

int CsvTableModel::columnCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_columnCount;
}

QVariant CsvTableModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size()
            || index.column() < 0 || index.column() >= m_columnCount)
        return QVariant();

    if (role != Qt::DisplayRole && role != Qt::EditRole && role != Qt::UserRole)
        return QVariant();

    const QStringList &row = m_rows.at(index.row());
    return index.column() < row.size() ? row.at(index.column()) : QString();
}

QVariant CsvTableModel::headerData(int section, Qt::Orientation orientation, int role) const
{
    if (orientation == Qt::Horizontal
            && (role == Qt::DisplayRole || role == Qt::EditRole || role == Qt::UserRole)
            && section >= 0 && section < m_header.size())
        return m_header.at(section);

    return QAbstractTableModel::headerData(section, orientation, role);
}

bool CsvTableModel::setSource(const QString &fileName, bool withHeader, QChar separator)
{
    QFile file(fileName);
    return setSource(&file, withHeader, separator);
}

bool CsvTableModel::setSource(QIODevice *device, bool withHeader, QChar separator)
{
    if (!device)
        return false;

    const bool openedHere = !device->isOpen();
    if (openedHere && !device->open(QIODevice::ReadOnly))
        return false;

    beginResetModel();
    m_rows.clear();
    m_header.clear();
    m_columnCount = 0;

    bool firstRow = true;
    while (!device->atEnd()) {
        QByteArray raw = device->readLine();
        while (raw.endsWith('\n') || raw.endsWith('\r'))
            raw.chop(1);

        // The legacy importer expects the model to expose a byte-preserving
        // Latin-1 view and performs its existing UTF-8/Latin-1 conversion
        // afterwards. Keeping this behaviour avoids changing old imports.
        const QStringList fields = parseLine(QString::fromLatin1(raw), separator);
        m_columnCount = qMax(m_columnCount, fields.size());

        if (withHeader && firstRow)
            m_header = fields;
        else
            m_rows.append(fields);

        firstRow = false;
    }

    m_columnCount = qMax(m_columnCount, m_header.size());
    endResetModel();

    if (openedHere)
        device->close();
    return true;
}

QStringList CsvTableModel::parseLine(const QString &line, QChar separator)
{
    QStringList fields;
    QString field;
    bool quoted = false;

    for (int i = 0; i < line.size(); ++i) {
        const QChar ch = line.at(i);
        if (ch == QLatin1Char('"')) {
            if (quoted && i + 1 < line.size() && line.at(i + 1) == QLatin1Char('"')) {
                field += QLatin1Char('"');
                ++i;
            } else {
                quoted = !quoted;
            }
        } else if (ch == separator && !quoted) {
            fields.append(field);
            field.clear();
        } else {
            field += ch;
        }
    }
    fields.append(field);
    return fields;
}

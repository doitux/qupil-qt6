/***************************************************************************
 *   Copyright (C) 2026 Qupil contributors                                *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 ***************************************************************************/
#ifndef CSVTABLEMODEL_H
#define CSVTABLEMODEL_H

#include <QAbstractTableModel>
#include <QStringList>
#include <QVector>

class QIODevice;

class CsvTableModel : public QAbstractTableModel
{
    Q_OBJECT
public:
    explicit CsvTableModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation,
                        int role = Qt::DisplayRole) const override;

    bool setSource(const QString &fileName, bool withHeader = false,
                   QChar separator = QLatin1Char(','));
    bool setSource(QIODevice *device, bool withHeader = false,
                   QChar separator = QLatin1Char(','));

private:
    static QStringList parseLine(const QString &line, QChar separator);

    QVector<QStringList> m_rows;
    QStringList m_header;
    int m_columnCount = 0;
};

#endif

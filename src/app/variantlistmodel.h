// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QAbstractListModel>
#include <QVariantMap>
#include <QVector>

class VariantListModel final : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    explicit VariantListModel(const QStringList &roles, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE QVariantMap get(int row) const;
    void setRows(QVector<QVariantMap> rows);
    void clear();

signals:
    void countChanged();

private:
    QVector<QVariantMap> m_rows;
    QHash<int, QByteArray> m_roles;
};

// SPDX-License-Identifier: GPL-2.0-or-later
#include "variantlistmodel.h"

#include <utility>

VariantListModel::VariantListModel(const QStringList &roles, QObject *parent)
    : QAbstractListModel(parent)
{
    int role = Qt::UserRole + 1;
    for (const QString &name : roles)
        m_roles.insert(role++, name.toUtf8());
}

int VariantListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant VariantListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};
    const auto it = m_roles.constFind(role);
    if (it == m_roles.cend())
        return {};
    return m_rows.at(index.row()).value(QString::fromUtf8(it.value()));
}

QHash<int, QByteArray> VariantListModel::roleNames() const
{
    return m_roles;
}

QVariantMap VariantListModel::get(int row) const
{
    if (row < 0 || row >= m_rows.size())
        return {};
    return m_rows.at(row);
}

void VariantListModel::setRows(QVector<QVariantMap> rows)
{
    beginResetModel();
    m_rows = std::move(rows);
    endResetModel();
    emit countChanged();
}

void VariantListModel::clear()
{
    setRows({});
}

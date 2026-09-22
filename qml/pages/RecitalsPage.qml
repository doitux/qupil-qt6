// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Page {
    id: root
    signal editRecital(int recordId)

    Action { id: editAction; onTriggered: source => root.editRecital(source.recordId) }
    Action { id: addAction; onTriggered: root.editRecital(-1) }

    RecitalsPageForm {
        anchors.fill: parent
        recitalsModel: App.recitals
        editRecitalAction: editAction
        addRecitalAction: addAction
    }
}

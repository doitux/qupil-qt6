// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import "../components"

Page {
    id: root
    property int selectedId: -1
    property string archiveHtml: ""

    Action {
        id: selectAction
        onTriggered: source => {
            root.selectedId = source.recordId
            root.archiveHtml = App.pupilArchiveHtml(source.recordId)
        }
    }
    Action { id: backAction; onTriggered: { root.selectedId = -1; root.archiveHtml = "" } }
    Action { id: openDeleteAction; onTriggered: form.deleteDialog.open() }

    ArchivePageForm {
        id: form
        anchors.fill: parent
        archiveModel: App.archive
        selectedId: root.selectedId
        archiveHtml: root.archiveHtml
        paletteMid: root.palette.mid
        paletteText: root.palette.text
        selectAction: selectAction
        backAction: backAction
        openDeleteAction: openDeleteAction

        deleteDialog.onAccepted: {
            if (App.deleteArchiveEntry(root.selectedId)) {
                root.selectedId = -1
                root.archiveHtml = ""
            }
        }
    }

    DocumentActions {
        parent: form.documentActionsHost
        anchors.fill: parent
        visible: root.selectedId >= 0
        documentTitle: qsTr("Pupil archive")
        suggestedFileName: ""
        landscape: false
        createDocument: function() { return root.archiveHtml }
    }
}

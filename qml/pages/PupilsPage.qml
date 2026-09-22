// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Page {
    id: root
    signal editPupil(int recordId)

    Action {
        id: editPupilAction
        onTriggered: source => root.editPupil(source.recordId)
    }
    Action {
        id: addPupilAction
        onTriggered: root.editPupil(-1)
    }

    PupilsPageForm {
        id: form
        anchors.fill: parent
        pupilsModel: App.pupils
        pupilFilter: App.pupilFilter
        editPupilAction: editPupilAction
        addPupilAction: addPupilAction

        searchField.onTextChanged: App.pupilFilter = searchField.text
    }
}

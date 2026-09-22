// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Page {
    id: root
    signal editLesson(int recordId)

    Action {
        id: editLessonAction
        onTriggered: source => root.editLesson(source.recordId)
    }
    Action {
        id: addLessonAction
        onTriggered: root.editLesson(-1)
    }

    LessonsPageForm {
        anchors.fill: parent
        lessonsModel: App.lessons
        editLessonAction: editLessonAction
        addLessonAction: addLessonAction
    }
}

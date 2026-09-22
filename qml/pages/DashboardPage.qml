// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Page {
    id: root
    signal openPupils()
    signal openLesson(int recordId)

    property var stats: App.dashboardStats()
    property var today: App.todayLessons()

    function reload() {
        stats = App.dashboardStats()
        today = App.todayLessons()
    }

    Action {
        id: openPupilsAction
        onTriggered: root.openPupils()
    }

    Action {
        id: openLessonAction
        onTriggered: source => root.openLesson(source.recordId)
    }

    Connections {
        target: App
        function onDataChanged() { root.reload() }
    }

    DashboardPageForm {
        anchors.fill: parent
        stats: root.stats
        today: root.today
        openPupilsAction: openPupilsAction
        openLessonAction: openLessonAction
    }
}

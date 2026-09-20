// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

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

    Connections { target: App; function onDataChanged() { root.reload() } }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: root.width
            spacing: 16
            anchors.margins: 16

            GridLayout {
                columns: root.width >= 900 ? 2 : 1
                rowSpacing: 14
                columnSpacing: 14
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 18

                Pane {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    padding: 16
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12
                        Label {
                            text: qsTr("Today")
                            font.pixelSize: 24
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        GridLayout {
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 10
                            Layout.fillWidth: true
                            Repeater {
                                model: [
                                    [qsTr("Pupils"), root.stats.todayPupils || 0],
                                    [qsTr("Lessons"), root.stats.todayLessons || 0]
                                ]
                                delegate: Pane {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 92
                                    ColumnLayout {
                                        anchors.fill: parent
                                        Label { text: modelData[1]; font.pixelSize: 28; font.bold: true }
                                        Label { text: modelData[0]; opacity: 0.7; Layout.fillWidth: true; elide: Text.ElideRight }
                                    }
                                }
                            }
                        }
                    }
                }

                Pane {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    padding: 16
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12
                        Label {
                            text: qsTr("Total")
                            font.pixelSize: 24
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        GridLayout {
                            columns: root.width >= 1180 ? 3 : (root.width >= 520 ? 2 : 1)
                            columnSpacing: 10
                            rowSpacing: 10
                            Layout.fillWidth: true
                            Repeater {
                                model: [
                                    [qsTr("Pupils"), root.stats.pupils || 0],
                                    [qsTr("Lessons"), root.stats.lessons || 0],
                                    [qsTr("Reminders"), root.stats.reminders || 0],
                                    [qsTr("Loaned scores"), root.stats.loanedMusic || 0],
                                    [qsTr("Events"), root.stats.recitals || 0]
                                ]
                                delegate: Pane {
                                    required property int index
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 92
                                    ColumnLayout {
                                        anchors.fill: parent
                                        Label { text: modelData[1]; font.pixelSize: 28; font.bold: true }
                                        Label { text: modelData[0]; opacity: 0.7; Layout.fillWidth: true; elide: Text.ElideRight }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (index === 0) root.openPupils()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Label {
                text: qsTr("Today's lessons")
                font.pixelSize: 22
                font.bold: true
                Layout.leftMargin: 16
                Layout.topMargin: 8
            }

            Label {
                visible: root.today.length === 0
                text: qsTr("No regular lessons are scheduled for today.")
                opacity: 0.65
                Layout.leftMargin: 16
            }

            Repeater {
                model: root.today
                delegate: ItemDelegate {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    contentItem: Column {
                        spacing: 3
                        Label { text: (modelData.start || "") + "–" + (modelData.stop || "") + "  " + (modelData.name || ""); font.bold: true }
                        Label { text: [modelData.pupils || "", modelData.location || ""].filter(x => x.length).join(" · "); opacity: 0.7 }
                    }
                    onClicked: root.openLesson(modelData.id)
                }
            }
            Item { Layout.preferredHeight: 16 }
        }
    }
}

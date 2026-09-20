// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qupil

Page {
    id: root

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: Math.min(scroll.availableWidth, 720)
            x: Math.max(0, (scroll.availableWidth - width) / 2)
            spacing: 18

            Label {
                text: qsTr("Metronome")
                font.pixelSize: 30
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 18
            }

            Label {
                text: Metronome.bpm + " bpm"
                font.pixelSize: 44
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Slider {
                from: 30
                to: 240
                stepSize: 1
                value: Metronome.bpm
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                onMoved: Metronome.bpm = Math.round(value)
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Button { text: "−"; onClicked: Metronome.bpm -= 1 }
                SpinBox { from: 30; to: 240; value: Metronome.bpm; editable: true; onValueModified: Metronome.bpm = value }
                Button { text: "+"; onClicked: Metronome.bpm += 1 }
                Button { text: qsTr("Tap tempo"); onClicked: Metronome.tapTempo() }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Label { text: qsTr("Beats per bar") }
                SpinBox { from: 1; to: 16; value: Metronome.beats; editable: true; onValueModified: Metronome.beats = value }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Repeater {
                    model: Metronome.beats
                    delegate: Rectangle {
                        required property int index
                        width: 24; height: 24; radius: 12
                        border.width: 1
                        border.color: root.palette.mid
                        color: Metronome.currentBeat === index ? root.palette.highlight : "transparent"
                    }
                }
            }

            Button {
                text: Metronome.running ? qsTr("Stop") : qsTr("Start")
                font.pixelSize: 20
                Layout.preferredWidth: 180
                Layout.preferredHeight: 56
                Layout.alignment: Qt.AlignHCenter
                onClicked: Metronome.toggle()
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.palette.mid; Layout.margins: 16 }

            Label {
                text: qsTr("Reference tone")
                font.pixelSize: 24
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                ComboBox { id: tuningNote; model: ["A", "B"]; Layout.preferredWidth: 90 }
                SpinBox { id: tuningPitch; from: 438; to: 445; value: 440; editable: true }
                Label { text: qsTr("Hz") }
                Button { text: qsTr("Play tone"); onClicked: Metronome.playTuningTone(tuningNote.currentText, tuningPitch.value) }
            }

            Label {
                text: qsTr("The Qt 6 port replaces the legacy SDL audio backend with Qt Multimedia while retaining Qupil's reference-tone range of 438–445 Hz.")
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.6
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.bottomMargin: 24
            }
        }
    }
}

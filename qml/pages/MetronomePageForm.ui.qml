// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    width: 1100
    height: 760

    property int bpm: 120
    property int beats: 4
    property int currentBeat: -1
    property bool running: false
    property color paletteMid: "#808080"
    property color paletteHighlight: "#4080c0"

    property var decrementAction: null
    property var incrementAction: null
    property var tapAction: null
    property var toggleAction: null
    property var playToneAction: null

    property alias bpmSlider: bpmSlider
    property alias bpmSpin: bpmSpin
    property alias beatsSpin: beatsSpin
    property alias tuningNote: tuningNote
    property alias tuningPitch: tuningPitch

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
                text: root.bpm + " bpm"
                font.pixelSize: 44
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Slider {
                id: bpmSlider
                from: 30
                to: 240
                stepSize: 1
                value: root.bpm
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Button { text: "−"; action: root.decrementAction }
                SpinBox { id: bpmSpin; from: 30; to: 240; value: root.bpm; editable: true }
                Button { text: "+"; action: root.incrementAction }
                Button { text: qsTr("Tap tempo"); action: root.tapAction }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Label { text: qsTr("Beats per bar") }
                SpinBox { id: beatsSpin; from: 1; to: 16; value: root.beats; editable: true }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Repeater {
                    model: root.beats
                    delegate: Rectangle {
                        required property int index
                        width: 24
                        height: 24
                        radius: 12
                        border.width: 1
                        border.color: root.paletteMid
                        color: root.currentBeat === index ? root.paletteHighlight : "transparent"
                    }
                }
            }

            Button {
                text: root.running ? qsTr("Stop") : qsTr("Start")
                font.pixelSize: 20
                Layout.preferredWidth: 180
                Layout.preferredHeight: 56
                Layout.alignment: Qt.AlignHCenter
                action: root.toggleAction
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.paletteMid; Layout.margins: 16 }

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
                Button { text: qsTr("Play tone"); action: root.playToneAction }
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

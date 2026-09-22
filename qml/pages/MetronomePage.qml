// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Page {
    id: root

    Action { id: decrementAction; onTriggered: Metronome.bpm -= 1 }
    Action { id: incrementAction; onTriggered: Metronome.bpm += 1 }
    Action { id: tapAction; onTriggered: Metronome.tapTempo() }
    Action { id: toggleAction; onTriggered: Metronome.toggle() }
    Action { id: playToneAction; onTriggered: Metronome.playTuningTone(form.tuningNote.currentText, form.tuningPitch.value) }

    MetronomePageForm {
        id: form
        anchors.fill: parent
        bpm: Metronome.bpm
        beats: Metronome.beats
        currentBeat: Metronome.currentBeat
        running: Metronome.running
        paletteMid: root.palette.mid
        paletteHighlight: root.palette.highlight
        decrementAction: decrementAction
        incrementAction: incrementAction
        tapAction: tapAction
        toggleAction: toggleAction
        playToneAction: playToneAction

        bpmSlider.onMoved: Metronome.bpm = Math.round(bpmSlider.value)
        bpmSpin.onValueModified: Metronome.bpm = bpmSpin.value
        beatsSpin.onValueModified: Metronome.beats = beatsSpin.value
    }
}

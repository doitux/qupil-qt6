// SPDX-License-Identifier: GPL-2.0-or-later
#include "metronomecontroller.h"

#include <QUrl>
#include <QtGlobal>

MetronomeController::MetronomeController(QObject *parent)
    : QObject(parent)
{
    m_regular.setSource(QUrl(QStringLiteral("qrc:/qt/qml/Qupil/data/sounds/s2.wav")));
    m_accent.setSource(QUrl(QStringLiteral("qrc:/qt/qml/Qupil/data/sounds/s1.wav")));
    m_regular.setVolume(0.75f);
    m_accent.setVolume(0.9f);
    m_tuning.setVolume(0.9f);
    m_notification.setSource(QUrl(QStringLiteral("qrc:/qt/qml/Qupil/data/sounds/reminder.wav")));
    m_notification.setVolume(0.8f);
    m_lessonEnd.setSource(QUrl(QStringLiteral("qrc:/qt/qml/Qupil/data/sounds/lesson-end.wav")));
    m_lessonEnd.setVolume(0.8f);
    m_timer.setTimerType(Qt::PreciseTimer);
    connect(&m_timer, &QTimer::timeout, this, &MetronomeController::tick);
}

void MetronomeController::setBpm(int value)
{
    value = qBound(30, value, 240);
    if (m_bpm == value)
        return;
    m_bpm = value;
    emit bpmChanged();
    if (running())
        schedule();
}

void MetronomeController::setBeats(int value)
{
    value = qBound(1, value, 16);
    if (m_beats == value)
        return;
    m_beats = value;
    emit beatsChanged();
    m_currentBeat = -1;
    emit currentBeatChanged();
}

void MetronomeController::schedule()
{
    m_timer.setInterval(qMax(1, qRound(60000.0 / double(m_bpm))));
}

void MetronomeController::start()
{
    if (running())
        return;
    m_currentBeat = -1;
    schedule();
    tick();
    m_timer.start();
    emit runningChanged();
}

void MetronomeController::stop()
{
    if (!running())
        return;
    m_timer.stop();
    m_currentBeat = -1;
    emit currentBeatChanged();
    emit runningChanged();
}

void MetronomeController::toggle()
{
    running() ? stop() : start();
}

void MetronomeController::tapTempo()
{
    if (m_tapTimer.isValid()) {
        const qint64 elapsed = m_tapTimer.restart();
        if (elapsed >= 250 && elapsed <= 2000)
            setBpm(qRound(60000.0 / double(elapsed)));
    } else {
        m_tapTimer.start();
    }
}

void MetronomeController::playNotificationSound()
{
    m_notification.stop();
    m_notification.play();
}

void MetronomeController::playLessonEndSound()
{
    m_lessonEnd.stop();
    m_lessonEnd.play();
}

void MetronomeController::playTuningTone(const QString &tone, int pitch)
{
    const QString normalizedTone = tone.trimmed().toLower();
    if (normalizedTone != QStringLiteral("a") && normalizedTone != QStringLiteral("b"))
        return;
    pitch = qBound(438, pitch, 445);
    m_tuning.stop();
    m_tuning.setSource(QUrl(QStringLiteral("qrc:/qt/qml/Qupil/data/sounds/tuning/%1%2.wav")
                                .arg(normalizedTone).arg(pitch)));
    m_tuning.play();
}

void MetronomeController::tick()
{
    m_currentBeat = (m_currentBeat + 1) % m_beats;
    emit currentBeatChanged();
    if (m_currentBeat == 0)
        m_accent.play();
    else
        m_regular.play();
}

// SPDX-License-Identifier: GPL-2.0-or-later
#include "metronomecontroller.h"

#include <QFileInfo>
#include <QSettings>
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
    m_notification.setVolume(0.7f);
    m_notification.setLoopCount(1);
    m_notificationCustom.setAudioOutput(&m_notificationOutput);
    m_notificationOutput.setVolume(0.7f);
    m_lessonEnd.setSource(QUrl(QStringLiteral("qrc:/qt/qml/Qupil/data/sounds/lesson-end.wav")));
    m_lessonEnd.setVolume(0.7f);
    m_lessonEnd.setLoopCount(1);
    m_lessonEndCustom.setAudioOutput(&m_lessonEndOutput);
    m_lessonEndOutput.setVolume(0.7f);
    m_preview.setAudioOutput(&m_previewOutput);
    m_previewOutput.setVolume(0.7f);
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

namespace {
QString reminderSoundPath(const QString &settingKey)
{
    const QString path = QSettings().value(QStringLiteral("settings/") + settingKey).toString();
    return !path.isEmpty() && QFileInfo::exists(path) ? path : QString{};
}

float reminderSoundVolume(const QString &settingKey)
{
    return float(qBound(0, QSettings().value(QStringLiteral("settings/") + settingKey, 7).toInt(), 10)) / 10.0f;
}

void playCustom(QMediaPlayer &player, QAudioOutput &output, const QString &path, float volume)
{
    const QUrl source = QUrl::fromLocalFile(path);
    player.stop();
    if (player.source() != source)
        player.setSource(source);
    output.setVolume(volume);
    player.setPosition(0);
    player.play();
}

void playConfigured(QSoundEffect &fallback, QMediaPlayer &custom, QAudioOutput &output,
                    const QString &path, float volume)
{
    if (!path.isEmpty()) {
        fallback.stop();
        playCustom(custom, output, path, volume);
        return;
    }
    custom.stop();
    fallback.stop();
    fallback.setVolume(volume);
    fallback.play();
}
}

void MetronomeController::playNotificationSound()
{
    playConfigured(m_notification, m_notificationCustom, m_notificationOutput,
                   reminderSoundPath(QStringLiteral("reminderSoundPath")),
                   reminderSoundVolume(QStringLiteral("reminderSoundVolume")));
}

void MetronomeController::playLessonEndSound()
{
    playConfigured(m_lessonEnd, m_lessonEndCustom, m_lessonEndOutput,
                   reminderSoundPath(QStringLiteral("lessonEndSoundPath")),
                   reminderSoundVolume(QStringLiteral("lessonEndSoundVolume")));
}

void MetronomeController::previewReminderSound(const QString &profile, const QString &path, int volume)
{
    const float gain = float(qBound(0, volume, 10)) / 10.0f;
    if (!path.isEmpty() && QFileInfo::exists(path)) {
        m_notification.stop();
        m_lessonEnd.stop();
        playCustom(m_preview, m_previewOutput, path, gain);
        return;
    }
    m_preview.stop();
    QSoundEffect &fallback = profile == QStringLiteral("lessonEnd") ? m_lessonEnd : m_notification;
    fallback.stop();
    fallback.setVolume(gain);
    fallback.play();
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

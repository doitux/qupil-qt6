// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QAudioOutput>
#include <QElapsedTimer>
#include <QMediaPlayer>
#include <QSoundEffect>
#include <QTimer>

class MetronomeController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int bpm READ bpm WRITE setBpm NOTIFY bpmChanged)
    Q_PROPERTY(int beats READ beats WRITE setBeats NOTIFY beatsChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(int currentBeat READ currentBeat NOTIFY currentBeatChanged)

public:
    explicit MetronomeController(QObject *parent = nullptr);

    int bpm() const { return m_bpm; }
    void setBpm(int value);
    int beats() const { return m_beats; }
    void setBeats(int value);
    bool running() const { return m_timer.isActive(); }
    int currentBeat() const { return m_currentBeat; }

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void toggle();
    Q_INVOKABLE void tapTempo();
    Q_INVOKABLE void playNotificationSound();
    Q_INVOKABLE void playLessonEndSound();
    Q_INVOKABLE void previewReminderSound(const QString &profile, const QString &path, int volume);
    Q_INVOKABLE void playTuningTone(const QString &tone, int pitch);

signals:
    void bpmChanged();
    void beatsChanged();
    void runningChanged();
    void currentBeatChanged();

private:
    void schedule();
    void tick();

    int m_bpm = 100;
    int m_beats = 4;
    int m_currentBeat = -1;
    QTimer m_timer;
    QSoundEffect m_regular;
    QSoundEffect m_accent;
    QSoundEffect m_tuning;
    QSoundEffect m_notification;
    QMediaPlayer m_notificationCustom;
    QAudioOutput m_notificationOutput;
    QSoundEffect m_lessonEnd;
    QMediaPlayer m_lessonEndCustom;
    QAudioOutput m_lessonEndOutput;
    QMediaPlayer m_preview;
    QAudioOutput m_previewOutput;
    QElapsedTimer m_tapTimer;
};

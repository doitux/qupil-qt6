#include "metronomplayer.h"

#include <QFileInfo>
#include <QUrl>
#include <QtGlobal>

MetronomPlayer::MetronomPlayer(QObject *parent)
    : QObject(parent)
{
    for (bool &isAccent : accent)
        isAccent = false;

    timer.setTimerType(Qt::PreciseTimer);
    connect(&timer, &QTimer::timeout, this, &MetronomPlayer::playNextBeat);
    updateTimerInterval();
}

bool MetronomPlayer::loadSounds(const QString &firstBeatFile,
                                const QString &regularBeatFile,
                                const QString &accentBeatFile)
{
    if (!QFileInfo::exists(firstBeatFile)
        || !QFileInfo::exists(regularBeatFile)
        || !QFileInfo::exists(accentBeatFile)) {
        return false;
    }

    clickOne.setSource(QUrl::fromLocalFile(firstBeatFile));
    click.setSource(QUrl::fromLocalFile(regularBeatFile));
    clickAccent.setSource(QUrl::fromLocalFile(accentBeatFile));
    clickOne.setVolume(0.9);
    click.setVolume(0.75);
    clickAccent.setVolume(0.9);
    return true;
}

void MetronomPlayer::changePlayState(bool on)
{
    if (on == playing)
        return;

    if (on) {
        initAudio();
        playing = true;
        currentBeat = -1;
        updateTimerInterval();
        playNextBeat();
        timer.start();
    } else {
        timer.stop();
        click.stop();
        clickOne.stop();
        clickAccent.stop();
        currentBeat = -1;
        playing = false;
        releaseAudio();
    }
}

void MetronomPlayer::setNumBeats(int n)
{
    numBeats = qBound(1, n, 32);
    currentBeat = -1;
}

void MetronomPlayer::setAccent(bool yes, int beat)
{
    if (beat < 0 || beat >= 32)
        return;
    accent[beat] = yes;
}

void MetronomPlayer::setBPM(int aBpm)
{
    bpm = qBound(1, aBpm, 999);
    updateTimerInterval();
}

void MetronomPlayer::updateTimerInterval()
{
    timer.setInterval(qMax(1, qRound(60000.0 / double(bpm))));
}

void MetronomPlayer::initAudio()
{
    // QSoundEffect/Qt Multimedia opens and releases the platform audio output.
}

void MetronomPlayer::releaseAudio()
{
    // Nothing to release manually; Qt Multimedia owns the audio backend.
}

void MetronomPlayer::playNextBeat()
{
    if (!playing || numBeats <= 0)
        return;

    currentBeat = (currentBeat + 1) % numBeats;
    QSoundEffect *effect = &click;
    if (currentBeat == 0)
        effect = &clickOne;
    else if (accent[currentBeat])
        effect = &clickAccent;

    effect->stop();
    effect->play();
    emit tick(currentBeat);
}

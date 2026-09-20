#ifndef __PLAYER_H__
#define __PLAYER_H__

#include <QObject>
#include <QSoundEffect>
#include <QTimer>

class MetronomPlayer : public QObject
{
    Q_OBJECT

public:
    explicit MetronomPlayer(QObject *parent = nullptr);

    bool loadSounds(const QString &firstBeatFile,
                    const QString &regularBeatFile,
                    const QString &accentBeatFile);

    int getBPM() const { return bpm; }
    int getNumBeats() const { return numBeats; }
    bool isPlaying() const { return playing; }

signals:
    void tick(int);
    void AudioInitFail();

public slots:
    void changePlayState(bool on);
    void setNumBeats(int n);
    void setAccent(bool yes, int beat);
    void setBPM(int aBpm);
    void initAudio();
    void releaseAudio();

private slots:
    void playNextBeat();

private:
    void updateTimerInterval();

    bool playing = false;
    QTimer timer;
    int bpm = 100;
    int currentBeat = -1;
    int numBeats = 4;
    bool accent[32];
    QSoundEffect click;
    QSoundEffect clickOne;
    QSoundEffect clickAccent;
};

#endif

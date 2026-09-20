/***************************************************************************
 * Qt-native replacement for the historical external audio wrapper.
 *
 * Copyright: See COPYING file that comes with this distribution
 ***************************************************************************/
#ifndef QTAUDIOPLAYER_H
#define QTAUDIOPLAYER_H

#include <QObject>
#include <QSoundEffect>
#include <QtGlobal>

#include "configfile.h"

class QMediaPlayer;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
class QAudioOutput;
#endif

class QtAudioPlayer : public QObject
{
    Q_OBJECT

public:
    explicit QtAudioPlayer(ConfigFile *config, QObject *parent = nullptr);
    ~QtAudioPlayer() override;

    bool initAudio();
    void playSound(const QString &audioString, int volume, bool fullpath = false);
    void audioDone();
    void closeAudio();
    void loadMetronomTicks(const QString &audioString1,
                           const QString &audioString2,
                           const QString &audioString3);
    void playMetronomTick(int tick);

    bool getAudioEnabled() const { return m_audioEnabled; }

private:
    QString soundPath(const QString &audioString, bool fullpath) const;
    static qreal effectVolume(int volume);

    bool m_audioEnabled = false;
    ConfigFile *m_config = nullptr;
    QString m_appDataPath;
    QMediaPlayer *m_player = nullptr;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    QAudioOutput *m_audioOutput = nullptr;
#endif
    QSoundEffect m_tick1;
    QSoundEffect m_tick2;
    QSoundEffect m_tick3;
};

#endif

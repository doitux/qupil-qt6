/***************************************************************************
 * Qt-native replacement for the historical external audio wrapper.
 *
 * Copyright: See COPYING file that comes with this distribution
 ***************************************************************************/
#include "qtaudioplayer.h"

#include <QDir>
#include <QFileInfo>
#include <QMediaPlayer>
#include <QUrl>
#include <QtGlobal>

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
#include <QAudioOutput>
#else
#include <QMediaContent>
#endif

QtAudioPlayer::QtAudioPlayer(ConfigFile *config, QObject *parent)
    : QObject(parent),
      m_config(config),
      m_appDataPath(QString::fromUtf8(config->readConfigString("AppDataDir").c_str())),
      m_player(new QMediaPlayer(this))
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    m_audioOutput = new QAudioOutput(this);
    m_player->setAudioOutput(m_audioOutput);
#endif
}

QtAudioPlayer::~QtAudioPlayer()
{
    closeAudio();
}

bool QtAudioPlayer::initAudio()
{
    // Qt Multimedia owns the platform audio device lifecycle. There is no
    // separate device initialization step required by the historical backend.
    m_audioEnabled = true;
    return true;
}

QString QtAudioPlayer::soundPath(const QString &audioString, bool fullpath) const
{
    if (fullpath)
        return audioString;
    return QDir(m_appDataPath).filePath(QStringLiteral("sounds/%1").arg(audioString));
}

qreal QtAudioPlayer::effectVolume(int volume)
{
    // Historical Qupil volume values are 0..10.
    return qBound<qreal>(0.0, qreal(volume) / 10.0, 1.0);
}

void QtAudioPlayer::playSound(const QString &audioString, int volume, bool fullpath)
{
    if (!initAudio())
        return;

    const QString fileName = soundPath(audioString, fullpath);
    if (!QFileInfo::exists(fileName)) {
        qWarning() << "Audio file does not exist:" << fileName;
        return;
    }

    m_player->stop();
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    m_audioOutput->setVolume(effectVolume(volume));
    m_player->setSource(QUrl::fromLocalFile(fileName));
#else
    m_player->setVolume(qBound(0, volume * 10, 100));
    m_player->setMedia(QMediaContent(QUrl::fromLocalFile(fileName)));
#endif
    m_player->play();
}

void QtAudioPlayer::audioDone()
{
    if (m_player)
        m_player->stop();
}

void QtAudioPlayer::closeAudio()
{
    audioDone();
    m_tick1.stop();
    m_tick2.stop();
    m_tick3.stop();
    m_audioEnabled = false;
}

void QtAudioPlayer::loadMetronomTicks(const QString &audioString1,
                                      const QString &audioString2,
                                      const QString &audioString3)
{
    const QString base = QDir(m_appDataPath).filePath(QStringLiteral("sounds"));
    m_tick1.setSource(QUrl::fromLocalFile(QDir(base).filePath(audioString1 + QStringLiteral(".wav"))));
    m_tick2.setSource(QUrl::fromLocalFile(QDir(base).filePath(audioString2 + QStringLiteral(".wav"))));
    m_tick3.setSource(QUrl::fromLocalFile(QDir(base).filePath(audioString3 + QStringLiteral(".wav"))));
    m_tick1.setVolume(0.8);
    m_tick2.setVolume(0.8);
    m_tick3.setVolume(0.9);
}

void QtAudioPlayer::playMetronomTick(int tick)
{
    QSoundEffect *effect = &m_tick2;
    if (tick == 0)
        effect = &m_tick1;
    else if (tick == 2)
        effect = &m_tick3;

    if (effect->source().isEmpty())
        return;
    effect->stop();
    effect->play();
}

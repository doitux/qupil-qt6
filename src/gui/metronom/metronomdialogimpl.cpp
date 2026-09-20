/***************************************************************************
 *   Copyright (C) 2006 by FThauer FHammer   *
 *   f.thauer@web.de   *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/
#include "metronomdialogimpl.h"

#include <QtCore>
#include <QtGui>
#include <QtSql>

#include "configfile.h"
#include "mainwindowimpl.h"
#include "qtaudioplayer.h"
#include "metronomplayer.h"

MetronomDialogImpl::MetronomDialogImpl(ConfigFile *c, mainWindowImpl *w, QtAudioPlayer *p, MetronomPlayer *m)
    : myConfig(c), myW(w), myQtAudioPlayer(p), myMetronomPlayer(m), startCheckTimer(false), checkTimerCounter(0)
{
    setupUi(this);

    initsuccess = true;

    spinBox_bpm->setMyPlayButton(pushButton_play);
    spinBox_beat->setMyPlayButton(pushButton_play);
    spinBox_tunePitch->setMyPlayButton(pushButton_play);

    myMetronomPlayer->setBPM(spinBox_bpm->value());

// 	myQtAudioPlayer->loadMetronomTicks("s01","s02","s03");

    checkLastTime = new QTime();
    timer = new QTimer();
// 	metronomTimer = new QTimer();

    connect( pushButton_play, SIGNAL( toggled(bool) ), myMetronomPlayer, SLOT( changePlayState(bool) ) );
    connect( pushButton_playTune, SIGNAL( clicked(bool) ), this, SLOT( playTune() ) );
    connect( pushButton_checkTempo, SIGNAL( clicked(bool) ), this, SLOT( checkTempo() ) );
    connect( spinBox_bpm, SIGNAL (valueChanged(int) ), this, SLOT (changeTempo(int) ) );
    connect( spinBox_beat, SIGNAL (valueChanged(int) ), this, SLOT (changeBeats(int) ) );
    connect( checkBox_beat, SIGNAL (toggled(bool) ), this, SLOT(beatOnOff(bool) ) );
    connect( myMetronomPlayer,SIGNAL (AudioInitFail()),this, SLOT(audioInitFail()));
    connect( timer, SIGNAL (timeout()), this, SLOT ( checkResetTempoChecker() ) );
// 	connect( metronomTimer, SIGNAL (timeout()), this, SLOT ( playMetronomTick() ) );

}

MetronomDialogImpl::~MetronomDialogImpl() {}

void MetronomDialogImpl::show()
{
    retranslateUi(this);
    timer->start(1000);
    QDialog::show();
    pushButton_play->setDefault(true);
    pushButton_play->setShortcut(QKeySequence(Qt::Key_Space));

//    this->
}

void MetronomDialogImpl::changeTempo(int t)
{
// 	metronomTimer->setInterval(60000/spinBox_bpm->value());
    myMetronomPlayer->setBPM(t);
}

void MetronomDialogImpl::audioInitFail()
{
    QMessageBox::critical(this,"Qupil", tr("Could not initialize the sound card."));
}

void MetronomDialogImpl::checkTempo()
{
    if(!startCheckTimer) {
        checkLastTime->setHMS(QTime::currentTime().hour(), QTime::currentTime().minute(), QTime::currentTime().second(), QTime::currentTime().msec());
        //start the real timer
        realTimer.start();

        startCheckTimer = true;
    } else {
        const qint64 elapsedMs = realTimer.restart();
        if (elapsedMs > 0)
            spinBox_bpm->setValue(static_cast<int>(60000 / elapsedMs));
    }
}

void MetronomDialogImpl::checkResetTempoChecker()
{
    if(checkLastTime->msecsTo(QTime::currentTime()) > 1700) startCheckTimer = false;
}

void MetronomDialogImpl::changeBeats(int b)
{
    myMetronomPlayer->setNumBeats(b);
}

void MetronomDialogImpl::beatOnOff(bool b)
{
    if(b) {
        if(!myMetronomPlayer->loadSounds(QString::fromUtf8(myConfig->readConfigString("AppDataDir").c_str())+"sounds/s1.wav", QString::fromUtf8(myConfig->readConfigString("AppDataDir").c_str())+"sounds/s2.wav",QString::fromUtf8(myConfig->readConfigString("AppDataDir").c_str())+"sounds/s3.wav")) {
            initsuccess = false;
            return;
        }
        myMetronomPlayer->setNumBeats(spinBox_beat->value());

    } else {
        if(!myMetronomPlayer->loadSounds(QString::fromUtf8(myConfig->readConfigString("AppDataDir").c_str())+"sounds/s2.wav", QString::fromUtf8(myConfig->readConfigString("AppDataDir").c_str())+"sounds/s2.wav",QString::fromUtf8(myConfig->readConfigString("AppDataDir").c_str())+"sounds/s3.wav")) {
            initsuccess = false;
            return;
        }
    }
}

void MetronomDialogImpl::playTune()
{
    if(comboBox_tuneTone->currentIndex() == 0) {	//A
        switch(spinBox_tunePitch->value()) {
        case 438:
            myQtAudioPlayer->playSound(QString("tuning/a438.wav"),10);
            break;
        case 439:
            myQtAudioPlayer->playSound(QString("tuning/a439.wav"),10);
            break;
        case 440:
            myQtAudioPlayer->playSound(QString("tuning/a440.wav"),10);
            break;
        case 441:
            myQtAudioPlayer->playSound(QString("tuning/a441.wav"),10);
            break;
        case 442:
            myQtAudioPlayer->playSound(QString("tuning/a442.wav"),10);
            break;
        case 443:
            myQtAudioPlayer->playSound(QString("tuning/a443.wav"),10);
            break;
        case 444:
            myQtAudioPlayer->playSound(QString("tuning/a444.wav"),10);
            break;
        case 445:
            myQtAudioPlayer->playSound(QString("tuning/a445.wav"),10);
            break;
        }
    } else { //B
        switch(spinBox_tunePitch->value()) {
        case 438:
            myQtAudioPlayer->playSound(QString("tuning/b438.wav"),10);
            break;
        case 439:
            myQtAudioPlayer->playSound(QString("tuning/b439.wav"),10);
            break;
        case 440:
            myQtAudioPlayer->playSound(QString("tuning/b440.wav"),10);
            break;
        case 441:
            myQtAudioPlayer->playSound(QString("tuning/b441.wav"),10);
            break;
        case 442:
            myQtAudioPlayer->playSound(QString("tuning/b442.wav"),10);
            break;
        case 443:
            myQtAudioPlayer->playSound(QString("tuning/b443.wav"),10);
            break;
        case 444:
            myQtAudioPlayer->playSound(QString("tuning/b444.wav"),10);
            break;
        case 445:
            myQtAudioPlayer->playSound(QString("tuning/b445.wav"),10);
            break;
        }
    }
}

void MetronomDialogImpl::changePlayState(bool b)
{
    if(b) {
        metronomTimer->start(60000/spinBox_bpm->value());
        playMetronomTick();
    } else metronomTimer->stop();
}

void MetronomDialogImpl::playMetronomTick()
{
    myQtAudioPlayer->playMetronomTick(0);
}

void MetronomDialogImpl::reject()
{
    pushButton_play->setChecked(false);
    myQtAudioPlayer->closeAudio();
    QDialog::reject();
}


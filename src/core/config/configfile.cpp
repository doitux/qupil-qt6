/***************************************************************************
 *   Copyright (C) 2006 by Felix Hammer   *
 *   f.hammer@web.de   *
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
#include "configfile.h"
#include <iostream>
#include <sstream>
#include <cstdlib>
#include <QApplication>
#include <QtCore>
#include <QObject>

using namespace std;


namespace {
struct XmlConfigEntry
{
    QString value;
    QString type;
    QStringList listValues;
};

using XmlConfigMap = QMap<QString, XmlConfigEntry>;

bool loadConfigXml(const std::string &fileName, XmlConfigMap *entries)
{
    if (!entries)
        return false;

    entries->clear();
    QFile file(QString::fromUtf8(fileName.c_str()));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;

    QXmlStreamReader xml(&file);
    bool foundConfiguration = false;

    while (!xml.atEnd()) {
        xml.readNext();
        if (!xml.isStartElement() || xml.name() != QLatin1String("Configuration"))
            continue;

        foundConfiguration = true;
        while (xml.readNextStartElement()) {
            const QString key = xml.name().toString();
            XmlConfigEntry entry;
            entry.value = xml.attributes().value(QLatin1String("value")).toString();
            entry.type = xml.attributes().value(QLatin1String("type")).toString();

            while (xml.readNextStartElement()) {
                entry.listValues.append(xml.attributes().value(QLatin1String("value")).toString());
                xml.skipCurrentElement();
            }
            entries->insert(key, entry);
        }
        break;
    }

    return foundConfiguration && !xml.hasError();
}
}


ConfigFile::ConfigFile(char *argv0, bool readonly)
: QObject(), noWriteAccess(readonly)
{
    myArgv0 = argv0;

    // !!!! Revisionsnummer der Configdefaults !!!!!
    configRev = 32;
    // !!!! Revision of data structure !!!!!
    string dataStructureRev = "2";

    // Keep the historic config locations, but use Qt for all filesystem work.
#ifdef _WIN32
    QString configRoot = qEnvironmentVariable("APPDATA");
    if (configRoot.isEmpty())
        configRoot = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    const QString configDir = QDir(configRoot).filePath(QStringLiteral("qupil"));
#else
    const QString configDir = QDir::home().filePath(QStringLiteral(".qupil"));
#endif
    const QString dbDir = QDir(configDir).filePath(QStringLiteral("db"));
    QDir().mkpath(configDir);
    QDir().mkpath(dbDir);
    configFileName = (QDir::cleanPath(configDir) + QLatin1Char('/')).toUtf8().constData();
    dataDir = (QDir::cleanPath(dbDir) + QLatin1Char('/')).toUtf8().constData();

    string userDir = configFileName.c_str();

    ostringstream tempIntToString;
    tempIntToString << configRev;

    configList.push_back(ConfigInfo("ConfigRevision", CONFIG_TYPE_INT, tempIntToString.str()));
    configList.push_back(ConfigInfo("AppDataDir", CONFIG_TYPE_STRING, getDataPathStdString(myArgv0)));
    configList.push_back(ConfigInfo("UserDir", CONFIG_TYPE_STRING, userDir));
    configList.push_back(ConfigInfo("Language", CONFIG_TYPE_STRING, getDefaultLanguage()));
    configList.push_back(ConfigInfo("CurrentDataStructureRevision", CONFIG_TYPE_INT, "0"));
    configList.push_back(ConfigInfo("ThisVersionDataStructureRevision", CONFIG_TYPE_INT, dataStructureRev));
    configList.push_back(ConfigInfo("ReleaseString", CONFIG_TYPE_STRING, "1.1"));
    configList.push_back(ConfigInfo("CopyrightTimeString", CONFIG_TYPE_STRING, "2006-2010"));

    list<string> genreList;
    genreList.push_back(QString(tr("Tune")).toUtf8().constData());
    genreList.push_back(QString(tr("Baroque")).toUtf8().constData());
    genreList.push_back(QString(tr("Classical")).toUtf8().constData());
    genreList.push_back(QString(tr("Romantic")).toUtf8().constData());
    genreList.push_back(QString(tr("Modernism")).toUtf8().constData());
    genreList.push_back(QString(tr("New music")).toUtf8().constData());
    genreList.push_back(QString(tr("Musical")).toUtf8().constData());
    genreList.push_back(QString(tr("Jazz")).toUtf8().constData());
    genreList.push_back(QString(tr("Rock")).toUtf8().constData());
    genreList.push_back(QString(tr("Pop")).toUtf8().constData());
    genreList.push_back(QString(tr("Irish Folk")).toUtf8().constData());
    configList.push_back(ConfigInfo("PalPiecesGenreList", CONFIG_TYPE_STRING_LIST, "PiecesGenre", genreList));

    list<string> locationList;
    locationList.push_back(QString(tr("Room 20")).toUtf8().constData());
    locationList.push_back(QString(tr("Room 16")).toUtf8().constData());
    locationList.push_back(QString(tr("Auditorium")).toUtf8().constData());
    configList.push_back(ConfigInfo("LessonLocationList", CONFIG_TYPE_STRING_LIST, "LessonLocation", locationList));

    list<string> instrumentList;
    instrumentList.push_back(QString(tr("Violin")).toUtf8().constData());
    instrumentList.push_back(QString(tr("Viola")).toUtf8().constData());
    instrumentList.push_back(QString(tr("Cello")).toUtf8().constData());
    instrumentList.push_back(QString(tr("Double Bass")).toUtf8().constData());
    configList.push_back(ConfigInfo("PupilInstrumentList", CONFIG_TYPE_STRING_LIST, "Instrument", instrumentList));

    list<string> instrumentSizeList;
    instrumentSizeList.push_back("4/4");
    instrumentSizeList.push_back("3/4");
    instrumentSizeList.push_back("1/2");
    instrumentSizeList.push_back("1/4");
    instrumentSizeList.push_back("1/8");
    instrumentSizeList.push_back("1/16");
    configList.push_back(ConfigInfo("PupilInstrumentSizeList", CONFIG_TYPE_STRING_LIST, "InstrumentSize", instrumentSizeList));

    configList.push_back(ConfigInfo("BirthdayReminder", CONFIG_TYPE_INT, "1"));
    configList.push_back(ConfigInfo("LessonEndMsg", CONFIG_TYPE_INT, "1"));
    configList.push_back(ConfigInfo("LessonEndMsgSoundVolume", CONFIG_TYPE_INT, "7"));
    configList.push_back(ConfigInfo("MinutesToLessonEndForMsg", CONFIG_TYPE_INT, "3"));
    configList.push_back(ConfigInfo("MsgSoundFilePath", CONFIG_TYPE_STRING, getDataPathStdString(myArgv0)+"/sounds/lesson-end.wav"));
    configList.push_back(ConfigInfo("RemSoundFilePath", CONFIG_TYPE_STRING, getDataPathStdString(myArgv0)+"/sounds/reminder.wav"));
    configList.push_back(ConfigInfo("RemSoundVolume", CONFIG_TYPE_INT, "7"));

    configList.push_back(ConfigInfo("TimeTableDayBColor", CONFIG_TYPE_STRING, "110,60,90"));
    configList.push_back(ConfigInfo("TimeTableDayTColor", CONFIG_TYPE_STRING, "255,255,255"));
    configList.push_back(ConfigInfo("TimeTableLessonBColor", CONFIG_TYPE_STRING, "194,255,76"));
    configList.push_back(ConfigInfo("TimeTableLessonTColor", CONFIG_TYPE_STRING, "0,0,0"));
    configList.push_back(ConfigInfo("TimeTablePupilBColor", CONFIG_TYPE_STRING, "255,255,255"));
    configList.push_back(ConfigInfo("TimeTablePupilTColor", CONFIG_TYPE_STRING, "0,0,0"));
    configList.push_back(ConfigInfo("RecitalIntervalCheckerOnlySolo", CONFIG_TYPE_INT, "1"));
    configList.push_back(ConfigInfo("SaveNotesPiecesForAllPupil", CONFIG_TYPE_INT, "1"));
    configList.push_back(ConfigInfo("LimitLoadLessonNotes", CONFIG_TYPE_INT, "0"));
    configList.push_back(ConfigInfo("LoadLessonNotesNumber", CONFIG_TYPE_INT, "30"));
    configList.push_back(ConfigInfo("LimitLoadMusicPieces", CONFIG_TYPE_INT, "0"));
    configList.push_back(ConfigInfo("LoadMusicPiecesNumber", CONFIG_TYPE_INT, "20"));

    configList.push_back(ConfigInfo("RecitalModerationDuration", CONFIG_TYPE_INT, "4"));
    configList.push_back(ConfigInfo("RecitalBetweenPiecesDuration", CONFIG_TYPE_INT, "2"));

    configList.push_back(ConfigInfo("WindowFullScreenSave", CONFIG_TYPE_INT, "0"));
    configList.push_back(ConfigInfo("WindowHeightSave", CONFIG_TYPE_INT, "637"));
    configList.push_back(ConfigInfo("WindowWidthSave", CONFIG_TYPE_INT, "1000"));

    //fill tempList firstTime
    configBufferList = configList;

    if(!noWriteAccess) {
        configFileName += "config.xml";

        XmlConfigMap entries;
        if(!loadConfigXml(configFileName, &entries)) {
            myConfigState = NONEXISTING;
            updateConfig(myConfigState);
        } else {
            const int tempRevision = entries.value(QStringLiteral("ConfigRevision")).value.toInt();
            if (tempRevision < configRev) {
                myConfigState = OLD;
                updateConfig(myConfigState);
            }
        }

        fillBuffer();

        // Preserve old configuration files but keep the runtime data path current.
        const string currentDataPath = getDataPathStdString(myArgv0);
        if (readConfigString("AppDataDir") != currentDataPath) {
            writeConfigString("AppDataDir", currentDataPath);
            writeBuffer();
        }
    }
}


ConfigFile::~ConfigFile()
{
}


void ConfigFile::fillBuffer()
{
    XmlConfigMap entries;
    if (!loadConfigXml(configFileName, &entries))
        return;

    for (size_t i = 0; i < configBufferList.size(); ++i) {
        const QString key = QString::fromStdString(configBufferList[i].name);
        const XmlConfigMap::const_iterator it = entries.constFind(key);
        if (it == entries.constEnd()) {
            qWarning() << "Could not find config entry" << key;
            continue;
        }

        configBufferList[i].defaultValue = it->value.toUtf8().constData();
        if (configBufferList[i].type == CONFIG_TYPE_INT_LIST
                || configBufferList[i].type == CONFIG_TYPE_STRING_LIST) {
            configBufferList[i].defaultListValue.clear();
            for (const QString &value : it->listValues)
                configBufferList[i].defaultListValue.push_back(value.toUtf8().constData());
        }
    }
}

void ConfigFile::writeBuffer() const
{
    if (noWriteAccess)
        return;

    QSaveFile file(QString::fromUtf8(configFileName.c_str()));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Cannot write configuration:" << file.errorString();
        return;
    }

    QXmlStreamWriter xml(&file);
    xml.setAutoFormatting(true);
    xml.writeStartDocument(QStringLiteral("1.0"));
    xml.writeStartElement(QStringLiteral("Qupil"));
    xml.writeStartElement(QStringLiteral("Configuration"));

    for (size_t i = 0; i < configBufferList.size(); ++i) {
        const ConfigInfo &info = configBufferList[i];
        xml.writeStartElement(QString::fromStdString(info.name));
        xml.writeAttribute(QStringLiteral("value"), QString::fromUtf8(info.defaultValue.c_str()));

        if (info.type == CONFIG_TYPE_INT_LIST || info.type == CONFIG_TYPE_STRING_LIST) {
            xml.writeAttribute(QStringLiteral("type"), QStringLiteral("list"));
            const QString childName = QString::fromUtf8(info.defaultValue.c_str());
            for (const string &value : info.defaultListValue) {
                xml.writeStartElement(childName);
                xml.writeAttribute(QStringLiteral("value"), QString::fromUtf8(value.c_str()));
                xml.writeEndElement();
            }
        }
        xml.writeEndElement();
    }

    xml.writeEndElement(); // Configuration
    xml.writeEndElement(); // Qupil
    xml.writeEndDocument();

    if (!file.commit())
        qWarning() << "Cannot commit configuration:" << file.errorString();
}

void ConfigFile::updateConfig(ConfigState state)
{
    if (state == NONEXISTING) {
        configBufferList = configList;
        writeBuffer();
        return;
    }

    if (state != OLD)
        return;

    XmlConfigMap oldEntries;
    if (!loadConfigXml(configFileName, &oldEntries)) {
        qWarning("Cannot update config file: Unable to load configuration.");
        return;
    }

    configBufferList = configList;
    for (size_t i = 0; i < configBufferList.size(); ++i) {
        ConfigInfo &info = configBufferList[i];

        // These values intentionally follow the defaults of the new version.
        if (info.name == "ConfigRevision" || info.name == "AppDataDir"
                || info.name == "ThisVersionDataStructureRevision"
                || info.name == "ReleaseString" || info.name == "CopyrightTimeString")
            continue;

        const XmlConfigMap::const_iterator it = oldEntries.constFind(QString::fromStdString(info.name));
        if (it == oldEntries.constEnd())
            continue;

        info.defaultValue = it->value.toUtf8().constData();
        if (info.type == CONFIG_TYPE_INT_LIST || info.type == CONFIG_TYPE_STRING_LIST) {
            info.defaultListValue.clear();
            for (const QString &value : it->listValues)
                info.defaultListValue.push_back(value.toUtf8().constData());
        }
    }

    writeBuffer();
}

string ConfigFile::readConfigString(string varName) const
{

    size_t i;
    string tempString("");

    for (i=0; i<configBufferList.size(); i++) {

        if (configBufferList[i].name == varName) {
            tempString = configBufferList[i].defaultValue;
        }
    }

    return tempString;
}

int ConfigFile::readConfigInt(string varName) const
{

    size_t i;
    string tempString("");
    int tempInt=0;

    for (i=0; i<configBufferList.size(); i++) {

        if (configBufferList[i].name == varName) {
            tempString = configBufferList[i].defaultValue;
        }
    }

    istringstream isst;
    isst.str (tempString);
    isst >> tempInt;

    return tempInt;
}

list<string> ConfigFile::readConfigStringList(string varName) const
{

    size_t i;
    list<string> tempStringList;

    for (i=0; i<configBufferList.size(); i++) {

        if (configBufferList[i].name == varName) {
            tempStringList = configBufferList[i].defaultListValue;
        }
    }

    return tempStringList;
}


list<int> ConfigFile::readConfigIntList(string varName) const
{

    size_t i;
    list<string> tempStringList;
    list<int> tempIntList;

    for (i=0; i<configBufferList.size(); i++) {

        if (configBufferList[i].name == varName) {
            tempStringList = configBufferList[i].defaultListValue;
        }
    }

    istringstream isst;
    string tempString;
    int tempInt;
    list<string>::iterator it;
    for(it = tempStringList.begin(); it != tempStringList.end(); it++) {

        isst.str(*it);
        isst >> tempInt;
        tempIntList.push_back(tempInt);
        isst.str("");
        isst.clear();
    }

    return tempIntList;
}


void ConfigFile::writeConfigInt(string varName, int varCont)
{

    size_t i;
    string tempString;
    ostringstream intToString;

    for (i=0; i<configBufferList.size(); i++) {

        if (configBufferList[i].name == varName) {
            intToString << varCont;
            configBufferList[i].defaultValue = intToString.str();
        }
    }
}


void ConfigFile::writeConfigIntList(string varName, list<int> varCont)
{

    size_t i;
    ostringstream intToString;
    list<string> stringList;

    for (i=0; i<configBufferList.size(); i++) {

        if (configBufferList[i].name == varName) {
            string tempString;
            list<int>::iterator it;
            for(it = varCont.begin(); it != varCont.end(); it++) {

                intToString << (*it);
                stringList.push_back(intToString.str());
                intToString.str("");
                intToString.clear();
            }

            configBufferList[i].defaultListValue = stringList;
        }
    }
}

void ConfigFile::writeConfigStringList(string varName, list<string> varCont)
{

    size_t i;
    list<string> stringList;

    for (i=0; i<configBufferList.size(); i++) {

        if (configBufferList[i].name == varName) {

            configBufferList[i].defaultListValue = varCont;
        }
    }
}

void ConfigFile::writeConfigString(string varName, string varCont)
{

    size_t i;
    for (i=0; i<configBufferList.size(); i++) {
        if (configBufferList[i].name == varName) {
            configBufferList[i].defaultValue = varCont;
        }
    }

}

std::string ConfigFile::getDataPathStdString(const char * /*argv0*/)
{
    QString path(QCoreApplication::instance()->applicationDirPath());

#ifdef _WIN32
    path += "/data/";
#else
#ifdef __APPLE__
    if (QRegExp("Contents/MacOS/?$").indexIn(path) != -1) {
        // pointing into an macosx application bundle
        path += "/../Resources/data/";
    } else {
        path += "/data/";
    }
#else //Unix
    if (QRegExp("pokerth/?$").indexIn(path) != -1) {
        // there is an own application directory
        path += "/data/";
    } else if (QRegExp("usr/games/bin/?$").indexIn(path) != -1) {
        // we are in /usr/games/bin (like gentoo linux does)
        path += "/../../share/games/pokerth/data/";
    } else if (QRegExp("usr/games/?$").indexIn(path) != -1) {
        // we are in /usr/games (like Debian linux does)
        path += "/../share/games/pokerth/";
    } else if (QRegExp("bin/?$").indexIn(path) != -1) {
        // we are in a bin directory. e.g. /usr/bin
        path += "/../share/pokerth/data/";

    } else {
        path += "/data/";
    }
#endif
#endif
    return (QDir::cleanPath(path) + "/").toUtf8().constData();
}

std::string ConfigFile::stringToUtf8(const std::string &myString)
{

    QString tmpString = QString::fromStdString(myString);
    std::string myUtf8String = tmpString.toUtf8().constData();

    return myUtf8String;
}

std::string ConfigFile::stringFromUtf8(const std::string &myString)
{
    QString tmpString = QString::fromUtf8(myString.c_str());

    return tmpString.toStdString();
}

std::string ConfigFile::getDefaultLanguage()
{
    return QLocale::system().name().toStdString();
}

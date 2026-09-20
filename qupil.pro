isEmpty( PREFIX ):PREFIX = /usr
TEMPLATE = app
CODECFORSRC = UTF-8
CONFIG += qt \
    thread \
    warn_on \
    c++11 \
#     release

QT += svg sql uitools widgets printsupport multimedia
UI_DIR = uics
MOC_DIR = mocs
OBJECTS_DIR = obj
DEFINES += PREFIX=\"$${PREFIX}\"
TARGET = qupil
RESOURCES = src/gui/resources/qupil.qrc
TRANSLATIONS = ts/qupil_de.ts
INCLUDEPATH += . \
    src \
    src/core \
    src/core/config \
    src/core/db \
    src/core/sound \
    src/gui \
    src/gui/mainwindow \
    src/gui/mainwindow/models \
    src/gui/mainwindow/delegates \
    src/gui/settings \
    src/gui/concertmanager \
    src/gui/instrumentmanager \
    src/gui/aboutqupil \
    src/gui/csvimportfields \
    src/gui/docviewer \
    src/gui/metronom \
    src/gui/sheetmusiclibrary \
    src/gui/sheetmusiclibrary/models \
    src/gui/sheetmusiclibrary/delegates \
    src/gui/birthdays \
    src/gui/buildtimetabledoc \
    src/gui/reminder
DEPENDPATH += . \
    src \
    src/core \
    src/core/config \
    src/core/db \
    src/core/sound \
    src/gui \
    src/gui/mainwindow \
    src/gui/mainwindow/models \
    src/gui/mainwindow/delegates \
    src/gui/settings \
    src/gui/concertmanager \
    src/gui/instrumentmanager \
    src/gui/aboutqupil \
    src/gui/csvimportfields \
    src/gui/docviewer \
    src/gui/metronom \
    src/gui/sheetmusiclibrary \
    src/gui/sheetmusiclibrary/models \
    src/gui/sheetmusiclibrary/delegates \
    src/gui/birthdays \
    src/gui/buildtimetabledoc \
    src/gui/reminder
FORMS += src/gui/mainwindow/mainwindow.ui \
    src/gui/settings/settings.ui \
    src/gui/birthdays/birthdays.ui \
    src/gui/concertmanager/concertmanager.ui \
    src/gui/instrumentmanager/instrumentmanager.ui \
    src/gui/docviewer/docviewer.ui \
    src/gui/metronom/metronom.ui \
    src/gui/sheetmusiclibrary/sheetmusiclibrary.ui \
    src/gui/aboutqupil/aboutqupil.ui \
    src/gui/csvimportfields/csvimportfields.ui \
    src/gui/concertmanager/addrecitaldialog.ui \
    src/gui/concertmanager/recitaltabs.ui \
    src/gui/concertmanager/selectpiecesdialog.ui \
    src/gui/concertmanager/finishrecitaldialog.ui \
    src/gui/concertmanager/addexternalrecitalpiecedialog.ui \
    src/gui/pupilslastrecital/pupilslastrecitalviewdialog.ui \
    src/gui/reminder/reminderdialog.ui \
    src/gui/reminder/remindereditdialog.ui \
    src/gui/builddayviewdoc/builddayviewdialog.ui \
    src/gui/pupilsnotinensemble/pupilsnotinensembledialog.ui \
    src/gui/mymessagedialog/mymessagedialog.ui
SOURCES += src/qupil.cpp \
    src/core/config/configfile.cpp \
    src/core/db/mydbhandler.cpp \
    src/core/db/obsoletepersonaldataconverter.cpp \
    src/gui/mainwindow/mainwindowimpl.cpp \
    src/gui/mainwindow/lessontabwidget.cpp \
    src/gui/mainwindow/timetabletreewidget.cpp \
    src/gui/mainwindow/models/palnotesmodel.cpp \
    src/gui/mainwindow/models/palpiecesmodel.cpp \
    src/gui/mainwindow/delegates/palpiecesdelegate.cpp \
    src/gui/mainwindow/pupiltabwidget.cpp \
    src/gui/metronom/mymetronomespinbox.cpp \
    src/gui/settings/settingsdialogimpl.cpp \
    src/gui/birthdays/birthdaysdialogimpl.cpp \
    src/gui/mainwindow/pupillisttreewidget.cpp \
    src/core/sound/qtaudioplayer.cpp \
    src/gui/mainwindow/pupilarchivetextbrowser.cpp \
    src/gui/mainwindow/pupilarchivelisttreewidget.cpp \
    src/gui/mainwindow/delegates/palnotesdelegate.cpp \
    src/gui/concertmanager/concertmanagerdialogimpl.cpp \
    src/gui/instrumentmanager/instrumentmanagerdialogimpl.cpp \
    src/gui/docviewer/docviewerdialogimpl.cpp \
    src/gui/mainwindow/models/pupilcontactivitymodel.cpp \
    src/gui/mainwindow/models/pupilsingularactivitymodel.cpp \
    src/gui/mainwindow/delegates/pupilcontactivitydelegate.cpp \
    src/gui/mainwindow/delegates/pupilsingularactivitydelegate.cpp \
    src/gui/metronom/metronomdialogimpl.cpp \
    src/core/sound/metronomplayer.cpp \
    src/gui/sheetmusiclibrary/sheetmusiclibrarydialogimpl.cpp \
    src/gui/sheetmusiclibrary/delegates/smlalldelegate.cpp \
    src/gui/sheetmusiclibrary/models/smlallmodel.cpp \
    src/gui/mainwindow/models/csvtablemodel.cpp \
    src/gui/aboutqupil/aboutqupildialogimpl.cpp \
    src/gui/csvimportfields/csvimportfieldsdialogimpl.cpp \
    src/gui/buildtimetabledoc/buildtimetabledoc.cpp \
    src/core/db/dbupdater.cpp \
    src/gui/concertmanager/addrecitaldialogimpl.cpp \
    src/gui/concertmanager/recitaltabs.cpp \
    src/gui/concertmanager/selectpiecesdialog.cpp \
    src/gui/concertmanager/finishrecitaldialog.cpp \
    src/gui/concertmanager/addexternalrecitalpiecedialog.cpp \
    src/gui/pupilslastrecital/pupilslastrecitalviewdialog.cpp \
    src/gui/mainwindow/delegates/delegatetextedit.cpp \
    src/gui/reminder/reminderdialog.cpp \
    src/gui/reminder/remindereditdialog.cpp \
    src/gui/builddayviewdoc/builddayviewdialog.cpp \
    src/gui/pupilsnotinensemble/pupilsnotinensembledialog.cpp \
    src/gui/mymessagedialog/mymessagedialogimpl.cpp
HEADERS += src/core/config/configfile.h \
    src/core/db/mydbhandler.h \
    src/core/db/obsoletepersonaldataconverter.cpp \
    src/gui/mainwindow/mainwindowimpl.h \
    src/gui/mainwindow/lessontabwidget.h \
    src/gui/mainwindow/timetabletreewidget.h \
    src/gui/mainwindow/models/palnotesmodel.h \
    src/gui/mainwindow/models/palpiecesmodel.h \
    src/gui/mainwindow/delegates/palpiecesdelegate.h \
    src/gui/mainwindow/pupiltabwidget.h \
    src/gui/metronom/mymetronomespinbox.h \
    src/gui/settings/settingsdialogimpl.h \
    src/gui/birthdays/birthdaysdialogimpl.h \
    src/gui/mainwindow/pupillisttreewidget.h \
    src/core/sound/qtaudioplayer.h \
    src/gui/mainwindow/pupilarchivetextbrowser.h \
    src/gui/mainwindow/pupilarchivelisttreewidget.h \
    src/gui/mainwindow/delegates/palnotesdelegate.h \
    src/gui/concertmanager/concertmanagerdialogimpl.h \
    src/gui/instrumentmanager/instrumentmanagerdialogimpl.h \
    src/gui/docviewer/docviewerdialogimpl.h \
    src/gui/mainwindow/models/pupilcontactivitymodel.h \
    src/gui/mainwindow/models/pupilsingularactivitymodel.h \
    src/gui/mainwindow/delegates/pupilcontactivitydelegate.h \
    src/gui/mainwindow/delegates/pupilsingularactivitydelegate.h \
    src/gui/metronom/metronomdialogimpl.h \
    src/core/sound/metronomplayer.h \
    src/gui/sheetmusiclibrary/sheetmusiclibrarydialogimpl.h \
    src/gui/sheetmusiclibrary/delegates/smlalldelegate.h \
    src/gui/sheetmusiclibrary/models/smlallmodel.h \
    src/gui/mainwindow/models/csvtablemodel.h \
    src/gui/aboutqupil/aboutqupildialogimpl.h \
    src/gui/csvimportfields/csvimportfieldsdialogimpl.h \
    src/gui/buildtimetabledoc/buildtimetabledoc.h \
    src/core/db/dbupdater.h \
    src/gui/concertmanager/addrecitaldialogimpl.h \
    src/gui/concertmanager/recitaltabs.h \
    src/gui/concertmanager/selectpiecesdialog.h \
    src/gui/concertmanager/finishrecitaldialog.h \
    src/gui/concertmanager/addexternalrecitalpiecedialog.h \
    src/gui/pupilslastrecital/pupilslastrecitalviewdialog.h \
    src/gui/mainwindow/delegates/delegatetextedit.h \
    src/gui/reminder/reminderdialog.h \
    src/qupil_defs.h \
    src/gui/reminder/remindereditdialog.h \
    src/gui/builddayviewdoc/builddayviewdialog.h \
    src/gui/pupilsnotinensemble/pupilsnotinensembledialog.h \
    src/gui/mymessagedialog/mymessagedialogimpl.h
win32 {
    RC_FILE = qupil.rc
}
unix:!mac { 
    # #### My release static build options
    QMAKE_CXXFLAGS += -ffunction-sections \
        -fdata-sections
    QMAKE_LFLAGS += -Wl,--gc-sections
    LIB_DIRS = $${PREFIX}/lib \
        $${PREFIX}/lib64
    # ### INSTALL ####
    binary.path += $${PREFIX}/bin/
    binary.files += qupil
    data.path += $${PREFIX}/share/qupil/data/
    data.files += data/*
    INSTALLS += binary \
        data
}
mac {
    CONFIG += x86_64
    CONFIG -= x86
    QMAKE_MACOSX_DEPLOYMENT_TARGET = 10.7
    RC_FILE = qupil.icns
}

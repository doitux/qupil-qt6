# Qupil developer tree

Dieser Ordner ist ein dauerhafter Entwicklungs-Quellbaum und wird von den alten Overlay-Buildskripten nicht verändert.

Snapshot-Quelle:

    /home/doitux/Projekte/qt-c++/Qupil-Mobile/qupil-build-env/source/qupil-mobile-ci-ready

Erkannte Programmversion:

    1.5.28

## Qt Creator

Projekt öffnen:

    /home/doitux/Projekte/qt-c++/Qupil-Mobile/qupil-dev/CMakeLists.txt

Kit:

    Qupil Desktop Qt 6.11.2

Empfohlenes Qt-Creator-Buildverzeichnis (Debug):

    /home/doitux/Projekte/qt-c++/Qupil-Mobile/qupil-build-env/build/creator-linux-debug

Empfohlenes Qt-Creator-Buildverzeichnis (Release):

    /home/doitux/Projekte/qt-c++/Qupil-Mobile/qupil-build-env/build/creator-linux-release

Generator: Ninja

Für Debug sollte  gesetzt sein.

## Sichere Testdaten

Für manuelle Testläufe wird empfohlen, nicht die normale Qupil-Datenbank zu verwenden.
 setzt deshalb automatisch:

    QUPIL_DATA_DIR=/home/doitux/Projekte/qt-c++/Qupil-Mobile/qupil-build-env/dev-runtime/data

und eigene XDG-Konfigurations-/Cache-Verzeichnisse.

In Qt Creator kannst du dieselben Variablen unter **Projekte -> Ausführen -> Umgebung** setzen:

    QUPIL_DATA_DIR=/home/doitux/Projekte/qt-c++/Qupil-Mobile/qupil-build-env/dev-runtime/data
    XDG_CONFIG_HOME=/home/doitux/Projekte/qt-c++/Qupil-Mobile/qupil-build-env/dev-runtime/config
    XDG_CACHE_HOME=/home/doitux/Projekte/qt-c++/Qupil-Mobile/qupil-build-env/dev-runtime/cache

## Terminal-Builds

Linux Debug:

    ./dev-tools/build-linux.sh debug
    ./dev-tools/run-linux.sh debug

Linux Release:

    ./dev-tools/build-linux.sh release

Android APK:

    ./dev-tools/build-android.sh apk

Android APK + AAB:

    ./dev-tools/build-android.sh all

Die Build-Ausgaben liegen weiterhin außerhalb des Git-Repositories unter .

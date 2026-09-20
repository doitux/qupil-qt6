# Mobile Builds: Android und iOS

## Gemeinsame Voraussetzung

Installiert sein muss ein Qt-6-Kit mit QML/Quick, Quick Controls 2, SQL und
Multimedia. Der Build importiert explizit Qt's `QSQLiteDriverPlugin`; ein
separates sqlite3-SDK oder eine direkte sqlite3-Verlinkung ist für Qupil nicht
erforderlich. Audio wird ausschließlich über Qt Multimedia bereitgestellt; SDL
und SDL_mixer werden nicht mehr benötigt. Auch Boost, TinyXML und LibQxt sind
aus dem Anwendungsquellcode entfernt; Qupil benötigt für den eigentlichen App-Build
keine zusätzliche Drittanbieterbibliothek außerhalb des gewählten Qt-Kits. Für neue Store-Builds wird Qt 6.8 oder
neuer empfohlen, weil dann der Android-Paketname direkt über die
CMake-Zieleigenschaft gesetzt wird. Der Quellcode selbst unterstützt Qt 6.5+.

## Android

Zusätzlich werden Android SDK, NDK und Java/JDK benötigt.  Das Android-Qt-Kit
liefert ein eigenes `qt-cmake`.

Beispiel (Pfade an die lokale Installation anpassen):

```sh
/path/to/Qt/6.x.x/android_arm64_v8a/bin/qt-cmake \
  -S . -B build/android-arm64 \
  -DANDROID_SDK_ROOT=/path/to/Android/Sdk \
  -DANDROID_NDK_ROOT=/path/to/Android/Sdk/ndk/<version> \
  -DBUILD_TESTING=OFF

cmake --build build/android-arm64 --parallel
cmake --build build/android-arm64 --target apk
```

Für eine Play-Store-Auslieferung wird ein signiertes AAB benötigt.  Bei einer
Qt-Version, die das Ziel anbietet:

```sh
cmake --build build/android-arm64 --target aab
```

Keystore, Alias und Zugangsdaten gehören **nicht** ins Repository.  Sie werden
über die lokale/CI-Signing-Konfiguration eingespeist.

`QT_ANDROID_MIN_SDK_VERSION` ist derzeit auf 26 gesetzt.  Ziel-SDK und
Toolchain-Version sollten bei der Release-Erstellung gegen die dann aktuellen
Play-Store-Anforderungen geprüft werden.

## iOS

Ein iOS-Build benötigt macOS, Xcode, ein passendes Qt-iOS-Kit und für Geräte/
Distribution eine Apple-Signing-Identity bzw. ein Provisioning-Profil.

```sh
/path/to/Qt/6.x.x/ios/bin/qt-cmake \
  -S . -B build/ios -G Xcode \
  -DBUILD_TESTING=OFF

cmake --build build/ios --config Debug
```

Für Signing, Team-Zuordnung, Gerätetest und Archivierung wird anschließend das
generierte Xcode-Projekt verwendet.  Die Bundle-ID ist im Projekt auf
`org.qupil.app` gesetzt.

## Release-Checkliste

Vor einer Veröffentlichung mindestens prüfen:

- Migration einer anonymisierten Kopie einer realen Qupil-Datenbank.
- Backup → Neuinstallation → Restore auf Android und iOS.
- CSV-Import aus lokalem Speicher und Cloud-/Document-Provider.
- Metronom/Referenztöne mit Lautlosmodus, Bluetooth und Audio-Unterbrechung.
- kleine/große Displays, Rotation, Safe Areas und Bildschirmtastatur.
- lange Schüler-/Stücklisten sowie Daten mit Umlauten/Unicode.
- Store-Signing und Upgrade-Test von einer früher installierten Testversion.

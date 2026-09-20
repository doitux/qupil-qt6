# Qupil: Stand der Qt-6-/QML-Migration

## Zielarchitektur

Der neue Pfad besteht aus drei Schichten:

1. **Qt Quick/QML** für adaptive Desktop-, Tablet- und Smartphone-Oberflächen.
2. **C++-Controller und `QAbstractListModel`** als einzige Schnittstelle der
   Oberfläche zur Fachlogik.
3. **Qt SQL / QSQLITE** mit vorbereiteten Abfragen und dem bestehenden
   Qupil-Schema (Revision 3). Qupil bindet keine `sqlite3`-API direkt ein; der
   von Qt mitgelieferte SQLite-Treiber wird beim Packaging explizit ausgewählt.

Die alte qmake/Qt-Widgets-Anwendung bleibt als Referenz im Quellbaum, wurde aber
bei den Infrastruktur-Abhängigkeiten modernisiert: SDL/SDL_mixer, Boost, TinyXML
und die eingebetteten LibQxt-CSV-Klassen sind entfernt. Fachlogik und UI des
Referenzpfads bleiben ansonsten als Vergleichsbasis erhalten.

## Bereits umgesetzt

### Plattform und Build

- CMake statt qmake für den neuen Anwendungspfad.
- Qt 6.5+ mit Core, Gui, QML, Quick, Quick Controls 2, SQL und Multimedia.
- Keine Abhängigkeit von `QtWidgets`/`QWidget` unter `src/app`.
- Audio läuft vollständig über Qt Multimedia. Auch der historische Widgets-
  Referenzpfad wurde von SDL/SDL_mixer auf `QMediaPlayer`, `QAudioOutput` und
  `QSoundEffect` umgestellt; die alten SDL-Link-/Release-Regeln sind entfernt.
- Datenbankzugriff läuft ausschließlich über Qt SQL (`QSQLITE`); CMake paketiert
  explizit `Qt6::QSQLiteDriverPlugin`, ohne direkte `sqlite3`-Verlinkung.
- Boost ist vollständig entfernt; das alte Tap-Tempo verwendet `QElapsedTimer`.
- TinyXML ist vollständig entfernt; die historische `config.xml` wird formatkompatibel
  mit `QXmlStreamReader`/`QXmlStreamWriter` aus Qt Core gelesen und geschrieben.
- Die eingebetteten LibQxt-Dateien für CSV sind entfernt und durch ein kleines
  `QAbstractTableModel` auf Qt-Basis ersetzt.
- Historische direkte Link-/Suchpfade für libidn, libntlm, zlib, MySQL und Carbon
  sind aus `qupil.pro` entfernt.
- Die alten BitRock/InstallBuilder-, SVN-/SCP- und manuellen Library-Copy-
  Release-Skripte sind entfernt. Desktop-Pakete laufen über Qt-Deployment und
  das mit CMake gelieferte CPack.
- macOS/iOS Bundle-ID `org.qupil.app`; Android erhält ab Qt 6.8 denselben
  Paketnamen über `QT_ANDROID_PACKAGE_NAME`.
- Android-Versioncode/-name und Mindest-SDK sind im CMake-Ziel hinterlegt.

### Daten und Kompatibilität

- Vollständige Anlage/Ergänzung des bekannten Schemas Revision 3.
- Existiert eine alte Desktop-Datenbank, wird sie beim ersten Start in das neue
  App-Datenverzeichnis **kopiert**.  Das Original wird nicht in-place geändert.
- Ältere Schema-Stände werden idempotent auf die benötigten Spalten ergänzt.
- Die wichtigsten bisherigen XML-Einstellungen werden einmalig in `QSettings`
  übernommen.
- Backup/Restore validiert die Quelldatenbank und legt vor einem Restore eine
  lokale Sicherheitskopie an.

### Arbeitsabläufe

- Schüler anlegen/bearbeiten/löschen/archivieren und Archiv ansehen.
- Unterricht anlegen/bearbeiten/löschen sowie Schüler zuordnen/entfernen.
- Historische Unterrichtszuordnungen behalten bei längerer Laufzeit den alten
  `lastlessonname`-Mechanismus.
- Wochen-Stundenplan als zentraler Einstieg.
- Notizen, Stücke, Aktivitäten und ausgeliehene Noten pro Schüler.
- Bei Gruppenunterricht werden Notizen und Stücke entsprechend der alten Option
  über `cnoteid`/`cpieceid` gemeinsam geführt.
- Erinnerungen und Notenbibliothek inklusive Ausleihe/Rückgabe. Start-, Unterrichtsbeginn- und schülerbezogene Erinnerungen werden im laufenden Programm ausgelöst; der Unterrichtsende-Hinweis ist ebenfalls portiert.
- Vorspiele/Events mit internen und externen Stücken. Beim Abschluss können wie
  bisher Aktivitäten erzeugt und aufgeführte Stücke beendet werden.
- Geburtstag-, Instrument-, Vorspielintervall- und Ensemble-Prüfungen.
- CSV-Import mit Komma/Semikolon, UTF-8/Latin-1 und frei wählbarer Feldzuordnung.
- Metronom, Tap-Tempo und A/B-Referenztöne 438–445 Hz über Qt Multimedia.

## Bewusste Korrekturen gegenüber dem Altcode

Die neue Vorspielintervall-Prüfung ignoriert einen Schüler nur dann, wenn er
bereits in einem **geplanten** Vorspiel steht.  Ein längst abgeschlossenes
Vorspiel unterdrückt die Prüfung nicht dauerhaft.  Das ist eine gezielte
Korrektur des beobachteten Altverhaltens.

## Noch nicht als fertig abgenommen

Folgende Punkte sind entweder noch nicht portiert oder benötigen reale
Plattformtests:

- PDF-/Druckdokumente und alle historischen Druckvorlagen.
- Hintergrundbenachrichtigungen unter iOS/Android. In-App-Erinnerungen funktionieren,
  native OS-Scheduling-/Permission-Logik für eine geschlossene/pausierte App ist noch offen.
- Vollständige Übernahme der bisherigen Übersetzungsdateien in den neuen QML-
  Stringbestand.
- Store-Icons, Launch/Splash Assets, Datenschutz-/Store-Metadaten und Signing.
- Reale Android-/iOS-Gerätetests: Dateiauswahl, `content://`/Document Provider,
  Audio-Unterbrechungen, Rotation, Safe Areas, Tastatur und App-Lifecycle.
- Cloud-Synchronisation. Der aktuelle Stand ist wie Qupil bisher lokal und darf
  dieselbe SQLite-Datei nicht parallel von mehreren Geräten öffnen.

## Tests im Repository

`tests/sql_static_smoke.py` baut das neue Schema in SQLite auf und lässt die
konstanten SQL-Anweisungen statisch parsen. `tests/source_sanity.py` prüft u.a.,
dass alle QML-Dateien ins Modul aufgenommen sind und im Anwendungsquellcode keine
SDL-, direkte sqlite3-, Boost-, TinyXML- oder LibQxt-Abhängigkeit mehr vorhanden
ist. Python 3 ist dabei nur eine **optionale Test-/Entwicklungsabhängigkeit** und
wird weder zum Bauen noch zur Auslieferung der App benötigt.

Diese Tests ersetzen **keinen** echten Qt-Build.  Vor einem Merge in eine
Release-Linie müssen mindestens Desktop-Builds aller drei Systeme sowie Android-
und iOS-Builds und Gerätetests grün sein.

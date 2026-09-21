# Qupil – Project State

Stand: 2026-09-21

## Aktueller Entwicklungsstand

- Aktuelle Programmversion: **Qupil 1.5.28**
- Aktuelle neue Codebasis: **Qt 6 / QML**
- Source of Truth: `qupil-dev/`
- Historische Originalversion: Qupil 1.4.x im alten Repository `doitux/qupil`
- Das alte Repository soll **nicht** als Arbeitsrepository für die neue Qt-6-Version verwendet oder überschrieben werden.

## Empfohlene Repository-Struktur

```text
Qupil-Mobile/
├── qupil-dev/                  # aktueller Quellcode / Git-Repository
├── qupil-build-env/            # Qt, Android SDK/NDK, Build-Verzeichnisse
├── qupil-ios-build-env/        # iOS CI / Artefakte
└── build-qupil-ios-from-dev.sh # iOS-Build aus qupil-dev
```

`qupil-dev/` ist ab jetzt die einzige Codebasis, an der manuell weiterentwickelt werden soll.

## Git-Workflow

Vor gemeinsamen Änderungen immer einen sauberen Stand herstellen:

```bash
cd ~/Projekte/qt-c++/Qupil-Mobile/qupil-dev
git status
git add -A
git commit -m "Beschreibung der Änderung"
git log -1 --oneline
```

Neue Änderungen sollen auf einem eindeutig benannten Commit oder Branch aufbauen.

## Qt / Toolchain

- Qt: **6.11.2**
- Desktop Qt: `qupil-build-env/Qt/6.11.2/gcc_64/`
- Android Qt: `qupil-build-env/Qt/6.11.2/android_arm64_v8a/`
- Android API: **36**
- Android Build Tools: **36.0.0**
- Android NDK: **27.2.12479018**
- Build-System: CMake + Ninja
- Qt Creator wird mit eigenem Kit gegen die vorhandene Qt-Installation verwendet.

Empfohlenes Qt-Creator-Debug-Buildverzeichnis:

```text
qupil-build-env/build/creator-linux-debug
```

Release:

```text
qupil-build-env/build/creator-linux-release
```

## Plattformen

### Linux

Lokaler Desktop-Build über Qt Creator oder `dev-tools/build-linux.sh`.

### Android

Build über vorhandene Android-Toolchain in `qupil-build-env`.

### iOS

Lokaler iOS-Build auf Linux ist nicht möglich. Der aktuelle Workflow ist:

```text
qupil-dev Git-Commit
    -> build-qupil-ios-from-dev.sh
    -> do itux/qupil-ios-build
    -> GitHub Actions macOS Runner
    -> unsigned IPA
    -> SideStore
```

Der iOS-Launcher soll nur den **committeten Stand aus `qupil-dev`** verwenden und den Quellbaum nicht verändern.

## Architektur

Neue Anwendung:

- Qt Quick / QML
- `QGuiApplication`
- `QQmlApplicationEngine`
- Qt SQL / SQLite
- Qt Multimedia
- keine Qt-Widgets-Abhängigkeit im normalen mobilen UI
- keine SDL-/Boost-/Qxt-/TinyXML-Laufzeitabhängigkeiten im neuen Pfad

## Wichtige Datenbanklogik

### Schüler-Unterricht-Zuordnung

Unterrichtsnotizen und Werke gehören nicht direkt nur zu einem Schüler oder Unterricht, sondern zu einer `palid` aus `pupilatlesson`.

```text
pupil <-> pupilatlesson (palid) <-> lesson
```

### Gruppenunterricht / gemeinsame Notizen

Die Einstellung `saveNotesPiecesForAllPupils` bestimmt beim **Anlegen neuer** Notizen/Werke, ob nur die gewählte `palid` oder alle aktiven Schüler des Unterrichts beschrieben werden.

Gemeinsame Notizen verwenden mehrere `note`-Zeilen mit gemeinsamer `cnoteid`.
Gemeinsame Werke verwenden mehrere `piece`-Zeilen mit gemeinsamer `cpieceid`.

Beim Löschen vorhandener gemeinsamer Einträge soll die tatsächliche `cnoteid`/`cpieceid`-Verknüpfung ausgewertet werden, nicht nur die aktuelle Einstellung.

## Stundenplan-Workflow

Der aktuelle Workflow orientiert sich wieder stärker an der alten Qupil-Version:

- Unterricht ist die obere Ebene.
- Darunter werden die aktiven Schüler einzeln angezeigt.
- Klick auf einen Schüler öffnet direkt den Arbeitsbereich für **Schüler + Unterricht (`palid`)**.
- Dort stehen Unterrichtsnotizen und Werke im Vordergrund.
- Unterrichtsdetails sind eine sekundäre Aktion.
- In Gruppenunterricht bleibt die gemeinsame/individuelle Notizlogik erhalten.

## Unterrichtsnotizen

- Bestehende Notiz antippen -> Text wird als Vorlage in das Eingabefeld kopiert.
- Datum und `palid` bleiben unverändert.
- Rich-Text-Altbestand wird beim Kopieren als sichtbarer Klartext übernommen.
- Mehrzeilige Eingabefelder besitzen vertikale Scrollbars und Cursor-Nachführung.

Ein Performance-Umbau auf virtuelle `ListView`-Notizlisten wurde in v27-r4/r5 getestet und wieder verworfen, weil er Regressionen verursachte. Der stabile Aufbau wurde mit v27-r6 wiederhergestellt.

## UI / Layout

Bereits umgesetzt bzw. angepasst:

- linke Navigation mit ausgerichteten Icons/Texten und klarer aktiver Markierung
- Tagesübersicht getrennt in `Heute` und `Gesamt`
- Stundenplan-Tagbuttons vergrößert und vollständig lesbar
- Einstellungsseite aufgeräumt
- Schülerdetail: persönliches Vorspielintervall als eigener Bereich
- Instrument und Leihinstrument logisch gruppiert
- leere Zustände umbrechen innerhalb ihrer Spalten
- Restore-Dialog ohne QML-Binding-Loop
- Versionshinweis unten links

Aktuell gewünschter sichtbarer App-Name: **Qupil**

## App-Icons

Das historische Qupil-Icon wurde wieder integriert für:

- Linux/Desktop
- Android
- iOS/iPadOS

Es gibt eine zentrale Master-Icon-Quelle sowie plattformspezifische Packaging-Ressourcen.
Der sichtbare App-Name soll überall **Qupil** lauten.

## PDF / Drucken

Die Druck-/PDF-Funktionalität wird anhand des originalen Qupil-1.4.1-Verhaltens rekonstruiert.

Wichtig: Inhalte und Positionen der Funktionen sollen sich **exakt am Original** orientieren; nur die Darstellung darf moderner sein.

Originale Dokumentstellen:

- `Dokument -> Tagesübersicht ...`
- `Dokument -> Stundenplan-Dokument ...`
- Leihinstrumente-Inventarliste im Instrumentenmanager
- Veranstaltungs-/Vorspielprogramm beim aktiven Event
- Schülerarchiv: Drucken / PDF
- Veranstaltungsarchiv: Drucken / PDF (noch nicht wiederhergestellt, weil die neue Veranstaltungsarchiv-Ansicht selbst noch fehlt)

Wichtige Originaldetails:

- Stundenplan-Dokument: Hochformat
- Tagesübersicht: Hochformat, Auswahl Wochentag/Datum, standardmäßig 3 letzte Unterrichtsnotizen und 2 cm Freiraum
- Leihinstrument-Inventarliste: Hochformat
- Veranstaltungsprogramm: Querformat
- automatischer PDF-Dateiname im Original nur beim aktiven Veranstaltungsprogramm:

```text
Beschreibung_Ort_YYYY-MM-DD.pdf
```

## Noch bekannte funktionale Lücken gegenüber Qupil 1.4.x

Unter anderem noch nicht vollständig wiederhergestellt:

- umfassende Bearbeitung bestehender Unterrichtsnotizen/Details
- Rich-Text-Bearbeitung wie früher
- vollständige Schülerarchiv- und Archiv-ohne-Löschen-Logik
- vollständiger Veranstaltungsmanager inkl. Reihenfolge, Archiv und Zusatzdaten
- Veranstaltungsarchiv
- einige Einstellungsoptionen und alte Komfortfunktionen
- einige alte Kontextmenüs / Long-Press-Aktionen
- weitere Detailfunktionen der Notenbibliothek

## Aktueller Fehler / nächster Debug-Schritt

Beim aktuellen Qt-Creator-Debuglauf tritt auf:

```text
qrc:/qt/qml/Qupil/qml/Main.qml:296: TypeError: Cannot read property 'lastError' of null
qrc:/qt/qml/Qupil/qml/Main.qml:282: TypeError: Cannot read property 'lastError' of null
qrc:/qt/qml/Qupil/qml/Main.qml:239: TypeError: Cannot read property 'databasePath' of null
qrc:/qt/qml/Qupil/qml/components/DocumentActions.qml:61: TypeError: Cannot call method 'availablePrinters' of null
qrc:/qt/qml/Qupil/qml/pages/RecitalDetailPage.qml:173: TypeError: Cannot call method 'recital' of null
```

Interpretation:

Das globale QML-Objekt **`App` ist im Qt-Creator-Debuglauf offenbar `null`**. Da mehrere unabhängige Seiten gleichzeitig ausfallen, liegt sehr wahrscheinlich ein gemeinsames Initialisierungs-/Registrierungsproblem vor und nicht ein einzelner Fehler in den betroffenen Seiten.

Nächster technischer Schritt:

1. `src/app/main.cpp` prüfen
2. Registrierung/Instanziierung des `AppController` prüfen
3. vergleichen, ob der Qt-Creator-Debug-Build andere CMake-Definitionen oder Startparameter verwendet als der bisherige Script-Build
4. kontrollieren, ob QML-Singleton/Context-Property/Singleton-Instance korrekt vor dem Laden von `Main.qml` gesetzt wird

## Regel für weitere gemeinsame Entwicklung

Wenn der Benutzer selbst Code geändert hat und ChatGPT weiterarbeiten soll:

1. Änderungen committen.
2. Commit-ID nennen oder aktuellen Quellstand bereitstellen.
3. Änderungen immer auf diesem Stand aufbauen.
4. Keine alten Overlay-Skripte mehr als Source-of-Truth verwenden.

Beispiel:

```bash
git status
git add -A
git commit -m "Meine Änderung"
git log -1 --oneline
```

Danach kann jede weitere Änderung eindeutig auf diesem Commit aufsetzen.

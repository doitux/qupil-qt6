# Qupil – Project State

Stand: **2026-09-23**

> Handoff-Datei für einen neuen Chat.  
> Diese Datei ersetzt den Stand vom 2026-09-21 und enthält die seitdem erfolgten Umbauten, Fixes, offenen Tests und den zuletzt entdeckten Fehler.

## Sofort wichtig für den nächsten Chat

### 1. Aktuell nächster funktionaler Bug: automatische Unterrichtsnamen

Der Benutzer hat gerade folgenden Regressionsfehler gemeldet:

```text
früher / erwartet auf Deutsch:
EU-25-Lin-OleBor

aktuell:
IL-25-Lin-OleBor
```

`EU` steht für **Einzelunterricht**. Aktuell wird offenbar die englische Basis **Individual Lesson -> IL** verwendet.

In einem vorhandenen Source-Snapshot wurde in

```text
src/app/appcontroller.cpp
AppController::updateLessonAutoName(int lessonId)
```

folgende harte Zuordnung gefunden:

```cpp
switch (l.value(QStringLiteral("type")).toInt()) {
case 1: name = QStringLiteral("IL-"); break;
case 2: name = QStringLiteral("GL-"); break;
case 3: name = QStringLiteral("EnsL-"); break;
default: name = QStringLiteral("L-"); break;
}
```

Das passt exakt zum gemeldeten `IL-`-Verhalten.

**Wichtig:** Der Snapshot ist nicht garantiert der allerneueste Quellstand. Im neuen Chat zuerst den **aktuellen** `src/app/appcontroller.cpp` prüfen, bevor gepatcht wird.

Für Typ 1 ist durch den Benutzer bestätigt:

```text
Deutsch / Legacy-Verhalten: EU-
```

Für Typ 2/3 wurde die historische gewünschte Abkürzung noch **nicht sicher bestätigt**. Vor einem Fix am besten das alte Qupil 1.4.x prüfen, statt `GU-`/`EnsU-` zu raten.

Nicht blind aus übersetzten Anzeigenamen ableiten, bevor klar ist, ob automatische Namen:
- sprachabhängig sein sollen, oder
- aus Kompatibilitätsgründen dauerhaft die alten deutschen Qupil-Abkürzungen verwenden sollen.

---

### 2. Deutsche Übersetzungen nach dem QML-UI-Split

Beim Split der Seiten in

```text
*Page.qml
*PageForm.ui.qml
```

gingen viele deutsche Laufzeitübersetzungen scheinbar verloren.

Root Cause:

Qt verwendet den QML-Dateinamen als Übersetzungskontext. Beispiel:

```text
vorher: SettingsPage
nachher: SettingsPageForm.ui
```

Die Übersetzungen waren großteils noch im alten `qupil_de.ts`, passten aber nicht mehr zum neuen Kontext.

#### Bisherige Analyse

Ein `lupdate`-Test auf dem aktuellen Stand meldete:

```text
Found 523 source text(s)
314 new
209 already existing
Removed 289 obsolete entries
Same-text heuristic provided 282 translation(s)
```

Die Rekonstruktion ergab:

```text
mapped_exact: 282
manual: 32
```

Also:
- **282** Übersetzungen lassen sich sauber vom alten Page-Kontext in den neuen `PageForm.ui`-Kontext übernehmen.
- **32** Texte sind tatsächlich neu bzw. nicht aus dem alten Kontext rekonstruierbar und wurden für Deutsch explizit ergänzt.

Die 32 neuen Texte umfassen insbesondere:
- native Desktop-/Portal-Druckfehler aus `AppController`
- Validierungsfehler der Vorspiel-/Programmreihenfolge
- einige neue UI-/Report-Texte

#### Übersetzungs-Script-Status

Erstellt wurde zuletzt:

```text
restore-qupil-ui-german-translations-v3.sh
```

V1/V2 wurden **nicht dauerhaft angewendet**; bei Fehlern erfolgte Rollback.

V2 scheiterte im Dry-Run nur an einem Fehler **im Prüfcode**, nicht an der Übersetzung:

```text
AppController :: Lesson %1 ends in %n minute(s).
placeholder mismatch
```

Ursache: Deutsche Qt-Numerus-Übersetzungen enthalten mehrere `<numerusform>`-Formen. V2 hatte alle Pluralformen zusammengezählt und dadurch `%1` und `%n` doppelt gesehen.

V3 prüft die Platzhalter nun **pro Pluralform**.

**Letzter Stand:** V3 wurde erstellt und syntaxgeprüft, aber der Benutzer hat noch nicht bestätigt, dass V3 erfolgreich als Dry-Run und anschließend real angewendet wurde.

Nächster Schritt:

```bash
chmod +x ~/Downloads/restore-qupil-ui-german-translations-v3.sh
~/Downloads/restore-qupil-ui-german-translations-v3.sh --dry-run
```

Erwartetes Ende:

```text
[OK] ZERO unfinished translations
[OK] ZERO obsolete/vanished translations
[OK] Translation placeholders are intact
[DRY-RUN OK] Full German catalogue restoration validated.
```

Danach:

```bash
~/Downloads/restore-qupil-ui-german-translations-v3.sh
```

und anschließend UI auf Deutsch prüfen.

---

### 3. iOS-Build

Der Benutzer baut iOS inzwischen auch direkt über das **GitHub-Webinterface**.

Der iOS-Workflow scheiterte zunächst an veralteten statischen Tests, nicht am eigentlichen iOS-Compiler.

#### Fix 1: Qt Widgets Sanity Test

Alter Test:

```python
assert "Qt6::Widgets" not in cmake
```

war nach Einführung nativer Windows/macOS-Druckdialoge falsch.

`Qt6::Widgets` wird nur Desktop-seitig auf Windows/macOS eingebunden, nicht auf iOS/Android.

Der Test wurde entsprechend angepasst.

Danach lief:

```text
source_sanity.py -> PASS
sql_static_smoke.py -> PASS
```

#### Fix 2: AppController-Lifetime / i18n-Test

`AppController` wurde früher als Stack-Objekt konstruiert:

```cpp
AppController controller;
```

und später absichtlich auf app-owned Heap-Lifetime geändert:

```cpp
auto *controller = new AppController(&app);
```

Der alte i18n-Test suchte nur nach der alten Zeichenkette und meldete deshalb fälschlich:

```text
LanguageController must be constructed before AppController
```

Der Test wurde so angepasst, dass weiterhin die echte Invariante geprüft wird:

```text
LanguageController muss vor AppController konstruiert werden.
```

Dieser Fix ist bereits erfolgt.

#### Aktueller iOS-Blocker

Vor dem nächsten produktiven iOS-Build sollte zuerst die oben beschriebene vollständige deutsche Übersetzungsreparatur V3 abgeschlossen werden, weil `i18n_catalog_smoke.py` vollständige/aktive Übersetzungen verlangt.

---

## Aktueller Entwicklungsstand

- Programmversion: **Qupil 1.5.28**
- Neue Codebasis: **Qt 6 / QML**
- Source of Truth: `qupil-dev`
- Historische Qupil-1.4.x-Codebasis nur als Funktions-/Layoutreferenz benutzen
- Nicht wieder im alten Qt5-Repository entwickeln

### Aktueller Arbeitsbaum

```text
~/Projekte/qt-c++/qupil-qt6/
├── qupil-dev/              # Source of Truth / Git
├── qupil-build-env/        # Qt + lokale Builds
└── backups/                # Patch-Backups außerhalb des Repos
```

Die ältere PROJECT-STATE-Datei enthielt noch Pfade unter `Qupil-Mobile/`. Der aktuelle tatsächlich verwendete Hauptpfad ist:

```text
~/Projekte/qt-c++/qupil-qt6/qupil-dev/
```

### Letzter beobachteter Git-Stand

Beim letzten Translation-Dry-Run:

```text
Branch: main
Commit: 7553286e4590
```

Das Script akzeptierte den Stand als sauber.

**Im neuen Chat trotzdem immer zuerst prüfen:**

```bash
cd ~/Projekte/qt-c++/qupil-qt6/qupil-dev
git status
git branch --show-current
git log -1 --oneline
```

---

## Git-Historie / wichtige Falle

Es gab einmal versehentlich einen Detached-HEAD-Zustand, ausgelöst durch:

```text
checkout: moving from main to origin/main
```

Dabei wurden zwei Commits detached erstellt. Das wurde über einen Rescue-Branch sauber wieder auf `main` gebracht.

Regel:

```bash
git switch main
```

und **nicht** direkt auf `origin/main` arbeiten.

Vor gemeinsamen Änderungen:
- Arbeitsbaum sauber machen
- bestehenden Stand committen
- Änderungen gezielt committen
- keine alten Overlay-Skripte als Source of Truth behandeln

---

## Qt / Toolchain

- Qt: **6.11.2**
- Qt Desktop Linux:
  ```text
  ~/Projekte/qt-c++/qupil-qt6/qupil-build-env/Qt/6.11.2/gcc_64/
  ```
- Qt Android:
  ```text
  ~/Projekte/qt-c++/qupil-qt6/qupil-build-env/Qt/6.11.2/android_arm64_v8a/
  ```
- Qt Creator: **20.0.1**
- Qt Design Studio: **4.8.3**
- Android API: **36**
- Android Build Tools: **36.0.0**
- Android NDK: **27.2.12479018**
- Build-System: CMake/Ninja bzw. plattformspezifische CMake-Generatoren

Bekanntes lokales Qt-Creator-Buildverzeichnis:

```text
~/Projekte/qt-c++/qupil-qt6/build-qupil-Desktop-debug/
```

Fallback/älteres Buildverzeichnis:

```text
~/Projekte/qt-c++/qupil-qt6/qupil-build-env/build/creator-linux-debug
```

---

## Architektur

Normaler Qupil-Pfad:

- Qt Quick / QML
- `QQmlApplicationEngine`
- Qt SQL / SQLite
- Qt Multimedia
- keine Qt Widgets im normalen mobilen UI

### AppController Lifetime

Der Lifetime-Fix ist wichtig:

```cpp
auto *controller = new AppController(&app);
```

Damit lebt `AppController` beim Shutdown lange genug relativ zur QML-Engine.

Nicht wieder auf ein lokales Stack-Objekt zurückbauen.

### Native Desktop-Printing Sonderfall

Für Windows/macOS wird wegen `QPrintDialog` zusätzlich Qt Widgets / PrintSupport verwendet.

Deshalb gilt heute:

- Linux/mobile: grundsätzlich `QGuiApplication`
- Windows/macOS Desktop mit nativer Print-Unterstützung: `QApplication`

Diese Widgets-Abhängigkeit ist bewusst **plattformbedingt** und darf nicht durch alte Tests pauschal verboten werden.

---

## Qt Design Studio / QML-Split

Die Seiten wurden aufgeteilt in:

```text
Page.qml             # Logik / Signale / App-Aufrufe
PageForm.ui.qml      # visuelle Struktur / Design
```

Die Design-Formen sollen möglichst Qt-Design-Studio-kompatibel bleiben.

Ein separater Fix beseitigte mehrdeutige IDs; danach funktionierte Qt Design Studio.

### Wichtige Regel

Reine Design-/Layoutänderungen möglichst in:

```text
*PageForm.ui.qml
```

und nicht zurück in die Wrapperlogik packen.

### Dashboard

Beim Split bekamen die Tiles im Bereich `Total` dunkle implizite Delegate-Hintergründe.

Der Benutzer hat den Fix selbst erfolgreich umgesetzt:

```qml
background: null
```

im entsprechenden Delegate des zweiten `Repeater` in:

```text
qml/pages/DashboardPageForm.ui.qml
```

Der Dashboard-Fix funktioniert.

---

## Datenbanklogik

### Schüler-Unterricht-Zuordnung

```text
pupil <-> pupilatlesson (palid) <-> lesson
```

Notizen und Werke gehören zu `palid`.

### Gemeinsame Notizen/Werke

- gemeinsame Notizen: gleiche `cnoteid`
- gemeinsame Werke: gleiche `cpieceid`

Beim Löschen muss die tatsächliche gemeinsame ID-Verknüpfung ausgewertet werden, nicht nur die aktuelle UI-Einstellung.

---

## Stundenplan / Unterricht

- Unterricht ist die obere Ebene.
- Darunter aktive Schüler.
- Klick auf Schüler öffnet den Arbeitsbereich Schüler + Unterricht (`palid`).
- Notizen/Werke stehen dort im Vordergrund.
- Unterrichtsdetails sekundär.
- gemeinsame/individuelle Notizlogik bleibt erhalten.

### Automatische Unterrichtsnamen

Aktueller bekannter Aufbau:

```text
<Typpräfix>-<Dauer>-<Ort3>-<Schülerkennung>
```

Beispiel erwartet:

```text
EU-25-Lin-OleBor
```

Die Schülerkennung beim Einzelunterricht setzt sich aus den ersten drei Zeichen von Vor- und Nachname zusammen.

Bei Nicht-Einzelunterricht werden aktuell offenbar die Initialen der beteiligten Schüler angehängt.

**Offener Bug:** Typpräfixe sind derzeit vermutlich englisch hartkodiert (`IL-`, `GL-`, `EnsL-`).

---

## Veranstaltungs-/Vorspielprogramm

Bereits wiederhergestellt:

- Musiker + Alter + Instrument
- Programmreihenfolge
- manuelles Hoch/Runter
- persistente `pieceatrecital.sorting`
- `saveRecitalPieceOrder`
- Reihenfolge vor Add/Remove/weiteren Änderungen sichern

Keine neue DB-Spalte notwendig.

---

## Veranstaltungsdokument / PDF-Layout

Referenz war Qupil 1.4.1.

Ziel/umgesetzt:

- A4 Querformat
- zentrierter Titel
- kompakte Metadatenzeile
- breitere Programmtabelle
- Zusammenfassung unten
- Footer

### Kritischer alter Fehler

Bei früheren Patches wurde versehentlich HTML wie

```text
100%%
20%%
```

erzeugt.

Bei `QString::arg()` muss ein normales Prozentzeichen nicht verdoppelt werden.

Korrekt:

```text
100%
20%
```

### Manuelle Änderungen des Benutzers

Der Benutzer hat danach selbst in:

```text
src/app/appcontroller.cpp
QString AppController::recitalDocumentHtml(...)
```

Layoutwerte angepasst:
- Abstand zwischen Titel und Metadaten vergrößert
- graue Tabellenhintergründe auf weiß geändert

Die **exakten finalen Werte sind nicht dokumentiert**.

Deshalb:

**Künftige Patches an `appcontroller.cpp` dürfen den Dokument-HTML-/CSS-Block nicht blind überschreiben.**

---

## PDF-Speichern / nativer Dateidialog

Der Benutzer wollte den eigenen QML-Dateidialog nicht mehr.

Aktuell:

- Desktop: `QtQuick.Dialogs FileDialog`
- KDE/Linux: Qt wird prozesslokal auf `xdgdesktopportal` für native FileChooser-Nutzung gelenkt
- KDE Portal liefert nativen KDE-Dateidialog
- Android/iOS behalten den Share-/Mobile-Workflow

Ein früheres:

```qml
options: 0
```

war unter Qt 6.11 fehlerhaft und wurde entfernt.

Der native Speichern-Dialog funktioniert auf KDE laut Benutzer.

---

## Native Druckdialoge

### Linux / KDE

Qt Quick Dialogs allein löste das Print-Problem nicht.

Deshalb gibt es expliziten XDG-Desktop-Portal-Druck über DBus:

```text
PreparePrint()
 -> KDE-Systemdruckdialog
 -> Token/Settings
 -> Print(PDF, token)
```

Wichtig: Ein direkter `Print()`-Aufruf ohne vorheriges `PreparePrint()` zeigte keinen Dialog und war falsch.

Es gab außerdem einen Qt-6.11-Compilefix:

```cpp
QDBusConnection bus = QDBusConnection::sessionBus();
```

statt `const QDBusConnection`, weil Connect/Disconnect nicht auf dem const-Objekt aufrufbar waren.

### Windows / macOS

Der Desktop-Patch wurde angewendet, committed und gepusht.

Architektur:

- Windows/macOS: `QPrintDialog`
- nutzt Qt PrintSupport + Widgets
- `QApplication` nur auf diesen Desktop-Plattformen
- Android/iOS unverändert
- Linux bleibt beim Portalpfad

Wichtiges Verhalten:

Wenn der native Windows/macOS-Druckdialog abgebrochen wird, gilt das als **behandelt**; danach darf nicht zusätzlich der alte QML-Fallbackdialog erscheinen.

---

## Windows CI / Wine

Windows-CI wurde erfolgreich bis zum Artefakt gebaut.

Beim Test des Windows-Artefakts unter:

```text
Wine 10.0 (Ubuntu 10.0~repack-12ubuntu1)
```

scheiterte der Start an ICU:

```text
icuuc.dll -> forward to icu.dll
module not found
```

Das Artefakt enthielt:

```text
icuuc.dll
36K
```

Ohne diese Datei meldete `Qt6Core.dll`, dass `icuuc.dll` fehlt.

Dieser Wine-Test ist **nicht die Hauptzielplattform**.

Nächster sinnvoller Realitätscheck:
- Windows 10 22H2 oder Windows 11 in VirtualBox / echter Windows-Installation
- unverändertes CI-Artefakt starten
- App-Start
- nativer Dateidialog
- nativer Druckdialog
- Microsoft Print to PDF

Nicht wegen Wine 10 vorschnell Anwendungs-/Qt-Code umbauen.

Später trotzdem den Windows-Packaging-Schritt prüfen, um zu verstehen, woher die kleine `icuuc.dll` kommt.

---

## CI

Es gibt u.a.:

```text
.github/workflows/qupil-build-on-demand.yml
.github/workflows/mobile-build.yml
```

`qupil-build-on-demand.yml` ist der relevante Desktop-Windows/macOS-Workflow und verwendet `workflow_dispatch`.

`mobile-build.yml` kann einen macOS-Runner benutzen, ist deshalb aber **nicht automatisch ein macOS-Desktop-Build**.

Ein eigener CI-Checker wurde erstellt:

```text
check-qupil-windows-macos-ci.py
```

Er prüft Git/Remote/Workflow/Jobs und wertet Windows/macOS-Builds aus.

Beim ersten Lauf gab es keinen Actions-Lauf für den Commit, weil der Desktop-Workflow manuell gestartet werden muss.

---

## i18n / Übersetzungsarchitektur

`LanguageController` muss vor `AppController` konstruiert werden, weil der AppController bereits in seinem Konstruktor übersetzte Model-Rollen erzeugt.

Bei Sprachwechsel:

- QML: `QQmlEngine::retranslate()`
- C++-Modelle: `AppController::refreshAll()`

Statische Tests:

```text
tests/source_sanity.py
tests/sql_static_smoke.py
tests/i18n_static_smoke.py
tests/i18n_catalog_smoke.py
```

Diese Tests sind wichtig, mussten aber nach Architekturänderungen ebenfalls gepflegt werden.

---

## Bekannte noch offene Runtime-Warnungen

Unabhängig von Print/Save wurden bereits beobachtet:

```text
DocumentPreviewDialog.qml: Binding loop detected for property "width"
ScrollView: Binding loop detected for property "contentWidth"
```

sowie beim Shutdown:

```text
qt.sql.qsqldatabase: QSqlDatabase requires a QCoreApplication
```

Noch nicht bereinigt.

Nicht mit dem nativen Print-/Save-Code verwechseln.

---

## Historische Referenz

Altes Qt5-Projekt:

```text
~/Projekte/qt-c++/qupil-qt5/
```

Qupil 1.4.x dient als:
- Verhaltensreferenz
- Layoutreferenz
- Quelle zum Nachschlagen historischer Funktionsdetails

Aber:

**Nie alte Dateien blind in `qupil-dev` zurückkopieren.**

---

## Benutzerpräferenzen für weitere gemeinsame Entwicklung

- Sprache: Deutsch
- knapp, technisch, praktisch
- lieber ein robuster One-Shot-Fix als viele kleine manuelle Patchschritte
- Patchscripts sollen möglichst:
  - Preflight haben
  - aktuelle Struktur verifizieren
  - Backups **außerhalb des Repos** erzeugen
  - deterministic patchen
  - `git diff --check` ausführen
  - Tests/Build ausführen
  - bei Fehlern rollbacken
- keine blinden String-Ersetzungen in unbekanntem Source-Stand
- wenn eine Änderung rein visuell ist: möglichst in `.ui.qml` / Qt Design Studio

---

## Empfohlener Start im nächsten Chat

Zuerst:

```bash
cd ~/Projekte/qt-c++/qupil-qt6/qupil-dev
git status
git branch --show-current
git log -1 --oneline
```

Dann je nach tatsächlichem Stand:

1. Falls Translation V3 noch nicht angewendet wurde:
   - V3 Dry-Run
   - V3 anwenden
   - deutsche UI prüfen
   - commit/push
2. Danach den **Auto-Unterrichtsnamen-Bug** beheben:
   - aktuellen `updateLessonAutoName()`-Code lesen
   - altes Qupil 1.4.x für Typpräfixe vergleichen
   - `EU-` für Einzelunterricht wiederherstellen
   - Typ 2/3 nicht raten
   - Regressionstest für automatische Unterrichtsnamen ergänzen
3. Danach iOS-Workflow über GitHub Webinterface erneut starten.

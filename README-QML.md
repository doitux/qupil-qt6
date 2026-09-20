# Qupil – Qt 6 / QML mobile migration

This branch contains an **additive Qt 6 / Qt Quick implementation** next to the
qmake/Qt Widgets reference application. The database format and reference
workflows are retained, while obsolete infrastructure dependencies in the legacy
path have been replaced with Qt equivalents.

## What is already migrated

- Qt 6 + CMake application entry point, with no Qt Widgets dependency in the
  new application layer and no SDL dependency anywhere in the application sources.
- Adaptive Qt Quick Controls UI for desktop, tablet and phone layouts.
- Existing Qupil schema revision 3, including pupils, lessons, notes, pieces,
  activities, reminders, sheet-music lending, events and archive data.
- Legacy desktop database discovery.  On first start it is copied into the new
  application data location; the old database is not edited in place.
- Pupil and lesson editing, weekly timetable, group lesson semantics for shared
  notes/pieces, event management, reminders, music library, reports/checks,
  archive and CSV pupil import.
- Metronome, tap-tempo and the original A/B 438–445 Hz reference tones via
  `Qt6::Multimedia`; the legacy Widgets audio wrapper/metronome now use Qt
  Multimedia as well.
- Database access is through `Qt6::Sql` + `QSQLITE`; the build explicitly packages
  Qt's `QSQLiteDriverPlugin` and never calls or links the sqlite3 C API directly.
- The repository no longer carries or links Boost, TinyXML, LibQxt, SDL, libidn,
  libntlm, zlib or MySQL as application dependencies. The legacy config XML uses
  Qt Core XML streams, CSV uses `QAbstractTableModel`, and tap-tempo uses
  `QElapsedTimer`.
- Backup and restore through QML file dialogs, including a local safety copy
  before replacing the active database.
- CMake settings for Windows, macOS, Linux, Android and iOS. Desktop packaging
  uses Qt deployment + CPack instead of the old BitRock/InstallBuilder scripts.

The detailed status and intentional compatibility decisions are documented in
[`docs/MIGRATION_STATUS.de.md`](docs/MIGRATION_STATUS.de.md).

## Desktop build

A Qt 6.5+ development kit with Core, Gui, Qml, Quick, Quick Controls, SQL and
Multimedia is required.

```sh
qt-cmake -S . -B build/desktop -DBUILD_TESTING=ON
cmake --build build/desktop --parallel
ctest --test-dir build/desktop --output-on-failure
```

Run the executable from the generated build directory.  For isolated testing,
set `QUPIL_DATA_DIR` to a temporary directory before starting Qupil so no real
user data is touched.

## Mobile builds

See [`docs/BUILD_MOBILE.de.md`](docs/BUILD_MOBILE.de.md) for Android and iOS.
Both platforms require their vendor toolchains in addition to Qt.  A signed App
Store / Play Store package cannot be produced without the corresponding Apple or
Android SDKs, signing identities and device testing.

## Data safety

Do not use a single database file concurrently from multiple devices.  This
migration currently provides local storage and manual backup/restore; it does
not implement cloud synchronization or conflict resolution.

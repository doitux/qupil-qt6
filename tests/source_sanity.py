#!/usr/bin/env python3
"""Lightweight source checks that do not require a Qt installation."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
cmake = (ROOT / "CMakeLists.txt").read_text(encoding="utf-8")

qml_files = sorted((ROOT / "qml").rglob("*.qml"))
for path in qml_files:
    rel = path.relative_to(ROOT).as_posix()
    assert rel in cmake, f"QML file missing from qt_add_qml_module: {rel}"

cpp_text = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "src/app").glob("*.[ch]*"))
assert "QtWidgets" not in cpp_text, "new application layer must not depend on Qt Widgets"
assert "QWidget" not in cpp_text, "new application layer must not depend on QWidget"
assert not re.search(r"\bSDL(?:_|\b)", cpp_text), "new application layer must not depend on SDL"

assert "find_package(Qt6 6.5 REQUIRED" in cmake
assert "Qt6::Quick" in cmake and "Qt6::QuickControls2" in cmake
assert "Qt6::Sql" in cmake and "Qt6::Multimedia" in cmake
assert "Qt6::QSQLiteDriverPlugin" in cmake, "QSQLITE plugin must be explicitly packaged"
assert "INCLUDE_BY_TYPE sqldrivers" in cmake
# QUPIL_SOURCE_SANITY_DESKTOP_WIDGETS_V1
# Qt Widgets is intentional for native desktop printing on Windows/macOS.
# The CMake block must stay outside Android/iOS builds.
widgets_marker = cmake.index("QUPIL_NATIVE_PRINT_DIALOG_DESKTOP_V3")
desktop_guard = cmake.rfind("if(NOT ANDROID AND NOT IOS)", 0, widgets_marker)
winmac_guard = cmake.index("if(WIN32 OR APPLE)", widgets_marker)
widgets_link = cmake.index("target_link_libraries(qupil PRIVATE Qt6::Widgets)", winmac_guard)
assert desktop_guard >= 0
assert desktop_guard < widgets_marker < winmac_guard < widgets_link
assert "QUPIL_NATIVE_WIDGET_PRINTING=1" in cmake[winmac_guard:widgets_link + 500]
assert "Qt6::PrintSupport" in cmake, "desktop printing must use Qt PrintSupport without Qt Widgets"
assert "Qt6::PrintSupport" in cmake, "desktop printing must use Qt PrintSupport without Qt Widgets"

# The application may use Qt SQL's QSQLITE driver, but must not use/link the
# sqlite3 C API directly. Audio must be Qt Multimedia only, with no SDL build
# dependency left in either the migrated or reference application sources.
source_files = list((ROOT / "src").rglob("*.cpp")) + list((ROOT / "src").rglob("*.h"))
all_source = "\n".join(p.read_text(encoding="utf-8", errors="ignore") for p in source_files)
assert "sqlite3.h" not in all_source and not re.search(r"\bsqlite3_", all_source)
assert not re.search(r"\bSDL(?:_mixer|_|\b)", all_source), "SDL remains in application source"
legacy_build = "\n".join((ROOT / rel).read_text(encoding="utf-8") for rel in [
    "qupil.pro", "INSTALL"
])
assert not re.search(r"\bSDL(?:_mixer|_|\b)|sdl-config", legacy_build), "SDL remains in build/release files"
assert "multimedia" in (ROOT / "qupil.pro").read_text(encoding="utf-8")

# No application/build dependency should remain on the legacy third-party
# libraries. C++ standard-library and OS runtime dependencies are intentionally
# not treated as third-party packages here.
for forbidden in (r"<boost/", r"\bboost::", r"\bTiXml", r"\bQxt"):
    assert not re.search(forbidden, all_source), f"legacy third-party code remains: {forbidden}"
assert not (ROOT / "src/core/third_party").exists(), "vendored third-party source directory remains"
qmake = (ROOT / "qupil.pro").read_text(encoding="utf-8")
assert not re.search(r"(?:^|\s)(?:LIBS|LIBPATH)\s*\+=", qmake), "legacy explicit linker dependencies remain"
assert not re.search(r"(?:boost|tinyxml|qxt|libidn|libntlm|zlib|mysql|Carbon)", qmake, re.IGNORECASE)

resource_paths = []
in_resources = False
for line in cmake.splitlines():
    stripped = line.strip()
    if stripped == "RESOURCES":
        in_resources = True
        continue
    if in_resources and stripped == ")":
        break
    if in_resources and stripped and not stripped.startswith("#"):
        resource_paths.append(stripped)
for rel in resource_paths:
    assert (ROOT / rel).exists(), f"QML resource missing from source tree: {rel}"

# Document preview geometry must remain one-way: the viewport controls the
# paper width, never the content width feeding back through availableWidth.
preview_qml = (ROOT / "qml/components/DocumentPreviewDialog.qml").read_text(encoding="utf-8")
assert "contentWidth: width" in preview_qml
assert "ScrollBar.horizontal.policy: ScrollBar.AlwaysOff" in preview_qml
assert "width: previewScroll.width" in preview_qml
assert "width: Math.max(300, previewScroll.width - 48)" in preview_qml
assert "contentWidth: Math.max(availableWidth, paper.width + 32)" not in preview_qml
assert "width: previewScroll.contentWidth" not in preview_qml
assert "width: Math.max(300, previewScroll.availableWidth - 48)" not in preview_qml

# Build identity must be generated from the source revision at build time, not
# maintained as a manual UI revision such as "v28-r2".
main_qml = (ROOT / "qml/Main.qml").read_text(encoding="utf-8")
main_cpp = (ROOT / "src/app/main.cpp").read_text(encoding="utf-8")
build_info_script = (ROOT / "cmake/GenerateBuildInfo.cmake").read_text(encoding="utf-8")
assert "v28-r2" not in main_qml
assert "Qt.application.version" in main_qml
assert "QupilBuildCommit" in main_qml and "QupilBuildTimestamp" in main_qml
assert '#include "qupil_build_info.h"' in main_cpp
assert "QUPIL_BUILD version=%1 commit=%2 timestamp=%3" in main_cpp
assert "QupilBuildCommit" in main_cpp and "QupilBuildTimestamp" in main_cpp
assert "add_custom_target(qupil_build_info ALL" in cmake
assert "GenerateBuildInfo.cmake" in cmake
assert "add_dependencies(qupil qupil_build_info)" in cmake
assert "rev-parse --short=7 HEAD" in build_info_script
assert '":(exclude)PROJECT-STATE.md"' in build_info_script
assert 'string(TIMESTAMP _timestamp "%Y-%m-%dT%H:%M:%SZ" UTC)' in build_info_script
assert "-dirty" in build_info_script

# Unsupported in Qt 6.5 TextField; SearchField only arrived later.
for path in qml_files:
    text = path.read_text(encoding="utf-8")
    assert "clearButtonEnabled" not in text, f"Qt 6.5 incompatible property in {path}"
    assert not re.search(r"(?:required\s+)?property\s+\w+\s+id\b", text), \
        f"QML id is a language attribute and must not be redeclared as a property: {path}"

# Obsolete external packaging toolchains must not return.
for obsolete in (
    "linux_create_release.sh", "win_create_release.sh", "mac_post_make.sh",
    "qupil_bitrock_linux.xml", "qupil_bitrock_windows.xml", "qupil.sh"
):
    assert not (ROOT / obsolete).exists(), f"obsolete packaging artifact remains: {obsolete}"
assert "include(CPack)" in cmake and "qt_generate_deploy_qml_app_script" in cmake

# Mobile reminders must be scheduled by the operating system. QML polling is
# desktop-only because iOS suspends background apps and Android may throttle
# their event loop.
main_qml = (ROOT / "qml/Main.qml").read_text(encoding="utf-8")
app_cpp = (ROOT / "src/app/appcontroller.cpp").read_text(encoding="utf-8")
settings_qml = (ROOT / "qml/pages/SettingsPage.qml").read_text(encoding="utf-8")
settings_form = (ROOT / "qml/pages/SettingsPageForm.ui.qml").read_text(encoding="utf-8")
manifest = (ROOT / "android/AndroidManifest.xml").read_text(encoding="utf-8")
android_scheduler = (ROOT / "android/src/org/qupil/app/QupilReminderScheduler.java").read_text(encoding="utf-8")
android_receiver = (ROOT / "android/src/org/qupil/app/QupilReminderReceiver.java").read_text(encoding="utf-8")
ios_scheduler = (ROOT / "src/app/native_reminders_ios.mm").read_text(encoding="utf-8")
assert ios_scheduler.index("@interface QupilNotificationDelegate") < ios_scheduler.index("namespace {")
assert ios_scheduler.index("@implementation QupilNotificationDelegate") < ios_scheduler.index("namespace {")
assert "UNNotificationPresentationOptionAlert" not in ios_scheduler
assert 'nativeMobileReminders: Qt.platform.os === "android" || Qt.platform.os === "ios"' in main_qml
assert "running: !root.nativeMobileReminders || Qt.application.state === Qt.ApplicationActive" in main_qml
assert "enqueueNotifications(App.lessonReminders(includeCurrentLesson))" in main_qml
assert "if (nativeMobileReminders)" in main_qml
assert "nativeReminderSchedule() const" in app_cpp
assert "syncNativeReminders()" in app_cpp
assert 'QStringLiteral("lessonEndSoundPath")' in app_cpp
assert 'QStringLiteral("reminderSoundPath")' in app_cpp
assert 'QStringLiteral("lessonEndSoundVolume")' in app_cpp
assert 'QStringLiteral("reminderSoundVolume")' in app_cpp
assert 'App.importReminderSound("lessonEnd"' in settings_qml
assert 'App.importReminderSound("reminder"' in settings_qml
assert 'Metronome.previewReminderSound("lessonEnd"' in settings_qml
assert 'Metronome.previewReminderSound("reminder"' in settings_qml
assert 'id: lessonEndVolume' in settings_form and 'id: reminderVolume' in settings_form
for permission in ("POST_NOTIFICATIONS", "SCHEDULE_EXACT_ALARM", "RECEIVE_BOOT_COMPLETED", "WAKE_LOCK"):
    assert permission in manifest
assert "QupilReminderReceiver" in manifest and "QupilReminderBootReceiver" in manifest
assert "setExactAndAllowWhileIdle" in android_scheduler
assert "setAndAllowWhileIdle" in android_scheduler
assert "canScheduleExactAlarms" in android_scheduler
assert "MediaPlayer" in android_receiver and "PREF_LESSON_VOLUME" in android_receiver
assert ".setSound(null)" not in android_receiver
assert "createNotificationChannel(context)" in android_receiver
assert "isAppForeground" in android_receiver and "inAppReminder" in android_receiver
assert "UNUserNotificationCenter" in ios_scheduler
assert "UNCalendarNotificationTrigger" in ios_scheduler
assert 'LibraryDirectory' in ios_scheduler and 'soundNamed:' in ios_scheduler
assert 'UIApplicationStateActive' in ios_scheduler
assert 'lesson-end.wav' in cmake and 'reminder.wav' in cmake
metronome_h = (ROOT / "src/app/metronomecontroller.h").read_text(encoding="utf-8")
assert "QMediaPlayer m_notificationCustom" in metronome_h and "QMediaPlayer m_lessonEndCustom" in metronome_h
assert "QSoundEffect m_notification" in metronome_h and "QSoundEffect m_lessonEnd" in metronome_h
for legacy_key, current_key in (
    ("MsgSoundFilePath", "lessonEndSoundPath"),
    ("LessonEndMsgSoundVolume", "lessonEndSoundVolume"),
    ("RemSoundFilePath", "reminderSoundPath"),
    ("RemSoundVolume", "reminderSoundVolume"),
):
    assert legacy_key in app_cpp and current_key in app_cpp
assert "removeAllPendingNotificationRequests" not in ios_scheduler
assert (ROOT / "android/res/raw/lesson_end.wav").exists()
assert (ROOT / "android/res/raw/reminder.wav").exists()

print(f"PASS: {len(qml_files)} QML files listed; desktop polling + native mobile reminder scheduling and configurable sounds are guarded")

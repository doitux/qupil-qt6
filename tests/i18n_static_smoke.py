#!/usr/bin/env python3
"""Static guards for Qupil's runtime EN/DE translation architecture."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "src/app/main.cpp").read_text(encoding="utf-8")
app = (ROOT / "src/app/appcontroller.cpp").read_text(encoding="utf-8")
schedule = (ROOT / "qml/pages/SchedulePage.qml").read_text(encoding="utf-8")
settings = (ROOT / "qml/pages/SettingsPage.qml").read_text(encoding="utf-8")
ts_path = ROOT / "i18n/qupil_de.ts"

# Translator must be installed before AppController populates translated roles.
lang_pos = main.find("LanguageController languageController")
# QUPIL_I18N_STATIC_HEAP_CONTROLLER_V1
# AppController used to be a stack object. It is now parented to the
# application so it outlives the QML engine during shutdown. Accept both
# shapes here; the ordering assertion below remains the actual invariant.
app_positions = [
    main.find("AppController controller"),
    main.find("new AppController(&app)"),
]
app_pos = min((pos for pos in app_positions if pos >= 0), default=-1)
assert lang_pos >= 0 and app_pos >= 0 and lang_pos < app_pos, \
    "LanguageController must be constructed before AppController"
assert "&LanguageController::effectiveLanguageChanged" in main
assert "&AppController::refreshAll" in main

# Never cache tr() results in dayName(), otherwise a live language switch keeps
# the language that was active on first call.
day_match = re.search(r"QString AppController::dayName\(int day\).*?\n}\n", app, re.S)
assert day_match, "dayName() not found"
day_body = day_match.group(0)
assert "static const QStringList" not in day_body
assert all(f'tr("{day}")' in day_body for day in
           ("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"))

# Imperatively cached QML result sets must reload after C++ models are refreshed.
assert "target: App" in schedule and re.search(r"function\s+onDataChanged\(\)\s*\{.*?root\.reload\(\)", schedule, re.S)
assert "target: Language" in settings and "onEffectiveLanguageChanged() { root.load() }" in settings

# Validate the translated dynamic values seen in the model-based UI.
tree = ET.parse(ts_path)
root = tree.getroot()
translations = {}
for context in root.findall("context"):
    if context.findtext("name") != "AppController":
        continue
    for message in context.findall("message"):
        source = message.findtext("source") or ""
        trans = message.find("translation")
        if trans is None:
            continue
        if message.get("numerus") == "yes":
            translations[source] = [(x.text or "") for x in trans.findall("numerusform")]
        else:
            translations[source] = "".join(trans.itertext()).strip()

expected = {
    "Monday": "Montag",
    "Tuesday": "Dienstag",
    "Wednesday": "Mittwoch",
    "Thursday": "Donnerstag",
    "Friday": "Freitag",
    "Saturday": "Samstag",
    "Sunday": "Sonntag",
    "Individual lesson": "Einzelunterricht",
    "Group lesson": "Gruppenunterricht",
    "Ensemble lesson": "Ensembleunterricht",
    "Planned": "Geplant",
    "Done": "Erledigt",
    "Specific pupil": "Bestimmter Schüler",
    "Every lesson": "Bei jedem Unterricht",
    "At application start": "Beim Programmstart",
}
for source, german in expected.items():
    assert translations.get(source) == german, \
        f"AppController translation mismatch: {source!r} -> {translations.get(source)!r}"

plural = translations.get("Lesson %1 ends in %n minute(s).")
assert plural == ["Unterricht %1 endet in %n Minute.",
                  "Unterricht %1 endet in %n Minuten."], plural

# QUPIL_AUTO_LESSON_PREFIX_REGRESSION_V1
# This is a static regression guard, not a database/UI runtime test.
auto_name_matches = list(re.finditer(
    r"void AppController::updateLessonAutoName\(int lessonId\)\n\{.*?\n\}\n",
    app, re.S))
assert len(auto_name_matches) == 1, "updateLessonAutoName() must exist exactly once"
auto_name_body = auto_name_matches[0].group(0)
assert re.search(
    r'if\s*\(l\.isEmpty\(\)\s*\|\|\s*!l\.value\(QStringLiteral\("autoName"\)\)'
    r'\.toBool\(\)\)\s*return\s*;', auto_name_body), \
    "Empty lessons and manually named lessons must stay protected"
app_contexts = [c for c in root.findall("context")
                if c.findtext("name") == "AppController"]
assert len(app_contexts) == 1, "AppController translation context must be unique"
for kind, source, german in ((1, "IL-", "EU-"), (2, "GL-", "GU-"),
                             (3, "EnsL-", "EnsU-")):
    assert re.search(
        rf'case\s+{kind}\s*:\s*name\s*=\s*tr\("{re.escape(source)}"\)\s*;\s*break\s*;',
        auto_name_body), f"Lesson type {kind} must use tr({source!r})"
    matches = [m for m in app_contexts[0].findall("message")
               if m.findtext("source") == source]
    assert len(matches) == 1, f"Expected exactly one AppController :: {source}"
    message = matches[0]
    translation = message.find("translation")
    assert not message.findtext("comment") and message.get("numerus") != "yes"
    assert translation is not None and translation.get("type") not in {
        "unfinished", "obsolete", "vanished"}, f"Inactive prefix: {source}"
    assert "".join(translation.itertext()) == german, f"Wrong German prefix: {source}"
assert re.search(r'default\s*:\s*name\s*=\s*QStringLiteral\("L-"\)\s*;\s*break\s*;',
                 auto_name_body), "Fallback L- must remain unchanged"
print("PASS: static guards for translated lesson prefixes and manual-name protection")
# END QUPIL_AUTO_LESSON_PREFIX_REGRESSION_V1

print("PASS: translator initializes before AppController; dynamic model retranslation is wired and catalog values are correct")

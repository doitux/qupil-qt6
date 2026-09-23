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

print("PASS: translator initializes before AppController; dynamic model retranslation is wired and catalog values are correct")

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
assert "Qt6::Widgets" not in cmake
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

print(f"PASS: {len(qml_files)} QML files listed; Qt Widgets absent from QML app; audio/SQLite and legacy third-party replacements use Qt modules only")

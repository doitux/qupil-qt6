#!/usr/bin/env python3
"""Static SQL smoke test for the Qt 6/QML migration.

This does not replace C++ tests. It extracts the fresh-schema CREATE TABLE
statements and constant AppController SQL strings, then asks SQLite to parse
those queries against the resulting database. That catches table/column typos
without requiring a Qt SDK in CI or in this migration environment.
"""
from __future__ import annotations

import ast
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_CPP = (ROOT / "src/app/databasemanager.cpp").read_text(encoding="utf-8")
APP_CPP = (ROOT / "src/app/appcontroller.cpp").read_text(encoding="utf-8")


def cpp_string(body: str) -> str:
    parts = re.findall(r'"(?:\\.|[^"\\])*"', body, flags=re.S)
    return "".join(ast.literal_eval(part) for part in parts)


def qstring_literals(text: str) -> list[str]:
    # The migration only uses ordinary string literals inside QStringLiteral.
    # Matching nested function calls is unnecessary for the SQL we validate.
    out: list[str] = []
    pos = 0
    token = "QStringLiteral("
    while True:
        start = text.find(token, pos)
        if start < 0:
            break
        i = start + len(token)
        depth = 1
        in_string = False
        escaped = False
        while i < len(text) and depth:
            ch = text[i]
            if in_string:
                if escaped:
                    escaped = False
                elif ch == "\\":
                    escaped = True
                elif ch == '"':
                    in_string = False
            else:
                if ch == '"':
                    in_string = True
                elif ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
            i += 1
        body = text[start + len(token): i - 1]
        if '"' in body:
            out.append(cpp_string(body))
        pos = i
    return out


conn = sqlite3.connect(":memory:")
cur = conn.cursor()

schema_begin = DB_CPP.index("const QStringList createStatements")
schema_end = DB_CPP.index("for (const QString &sql", schema_begin)
creates = [s for s in qstring_literals(DB_CPP[schema_begin:schema_end])
           if s.lstrip().upper().startswith("CREATE TABLE")]
assert len(creates) >= 18, f"expected at least 18 schema statements, got {len(creates)}"
for statement in creates:
    cur.execute(statement)

# Mirror the idempotent post-create seed/update steps that are plain SQL.
for statement in qstring_literals(DB_CPP[schema_end:]):
    if statement.startswith(("UPDATE activity ", "UPDATE lesson ", "UPDATE lastlessonname ",
                             "INSERT OR IGNORE INTO ", "REPLACE INTO dbinfos ")):
        cur.execute(statement)

expected = {
    "pupil": {"pupilid", "recitalinterval", "ensembleactivityrequested"},
    "lesson": {"lessonid", "lessonname", "lessonlocation"},
    "lastlessonname": {"llnid", "lessonname", "namekind", "lessontype", "durationminutes",
                       "locationtoken", "pupiltoken", "formatrev"},
    "pupilatlesson": {"palid", "lessonid", "pupilid", "llnid", "stopdate"},
    "piece": {"pieceid", "cpieceid", "piececomposerid", "state"},
    "activity": {"activityid", "noncontinoustype", "continoustype", "continousstopdate"},
    "recital": {"recitalid", "organisator", "defaultaccompanist", "state"},
    "reminder": {"reminderid", "mode", "pupilid", "notificationsound"},
}
for table, columns in expected.items():
    found = {row[1] for row in cur.execute(f"PRAGMA table_info({table})")}
    missing = columns - found
    assert not missing, f"{table}: missing {sorted(missing)}"

revision = cur.execute("SELECT data_structure_rev FROM dbinfos WHERE id=0").fetchone()
assert revision == (4,), f"expected schema revision 4, got {revision}"
assert "UPDATE lesson SET lessonname=NULL WHERE COALESCE(autolessonname,1)=1" in DB_CPP
assert "UPDATE lastlessonname SET lessonname=NULL WHERE namekind=2" in DB_CPP

# Revision 4 reserves lesson.lessonname for manual names. Automatic active names
# and structured automatic history snapshots must lose any stale localized literal.
cur.execute("INSERT INTO lesson (lessonid,autolessonname,lessonname) VALUES (101,1,'IL-25-Lin-OleBor')")
cur.execute("INSERT INTO lesson (lessonid,autolessonname,lessonname) VALUES (102,0,'My quartet')")
cur.execute("INSERT INTO lastlessonname (llnid,lessonname,namekind) VALUES (201,'EU-25-Lin-OleBor',2)")
cur.execute("INSERT INTO lastlessonname (llnid,lessonname,namekind) VALUES (202,'Legacy lesson',0)")
cur.execute("UPDATE lesson SET lessonname=NULL WHERE COALESCE(autolessonname,1)=1")
cur.execute("UPDATE lastlessonname SET lessonname=NULL WHERE namekind=2")
assert cur.execute("SELECT lessonname FROM lesson WHERE lessonid=101").fetchone() == (None,)
assert cur.execute("SELECT lessonname FROM lesson WHERE lessonid=102").fetchone() == ("My quartet",)
assert cur.execute("SELECT lessonname FROM lastlessonname WHERE llnid=201").fetchone() == (None,)
assert cur.execute("SELECT lessonname FROM lastlessonname WHERE llnid=202").fetchone() == ("Legacy lesson",)

queries = []
for statement in qstring_literals(APP_CPP):
    sql = statement.strip()
    if "%" in sql:  # dynamically formatted identifier query; checked separately by code review.
        continue
    if re.match(r"^(SELECT|INSERT|UPDATE|DELETE|REPLACE)\b", sql, re.I):
        queries.append(sql)

failures: list[tuple[str, str]] = []
for sql in queries:
    # SQLite's EXPLAIN parses and resolves tables/columns without executing the DML.
    values = [0] * sql.count("?")
    try:
        cur.execute("EXPLAIN " + sql, values).fetchall()
    except sqlite3.Error as exc:
        failures.append((sql, str(exc)))

if failures:
    for sql, message in failures:
        print("FAIL:", message)
        print("  SQL:", sql)
    raise SystemExit(1)

print(f"PASS: {len(creates)} schema statements; {len(queries)} constant SQL statements parsed by SQLite")

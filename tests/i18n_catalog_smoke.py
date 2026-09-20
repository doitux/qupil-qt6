#!/usr/bin/env python3
"""Validate the curated German Qt Linguist catalog without Qt tools."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
TS = ROOT / "i18n/qupil_de.ts"
root = ET.parse(TS).getroot()
assert root.get("language") == "de_DE"

placeholder_re = re.compile(r"%(?:n|\d+)")
messages = []
for context in root.findall("context"):
    context_name = context.findtext("name") or ""
    for message in context.findall("message"):
        source = message.findtext("source") or ""
        translation = message.find("translation")
        assert translation is not None, f"missing translation: {context_name} :: {source}"
        assert translation.get("type") not in {"unfinished", "obsolete", "vanished"}, \
            f"inactive translation: {context_name} :: {source}"
        source_placeholders = sorted(placeholder_re.findall(source))
        if message.get("numerus") == "yes":
            forms = [(form.text or "").strip() for form in translation.findall("numerusform")]
            assert len(forms) == 2 and all(forms), f"German numerus needs two forms: {context_name} :: {source}"
            for form in forms:
                assert sorted(placeholder_re.findall(form)) == source_placeholders, \
                    f"placeholder mismatch: {context_name} :: {source} -> {form}"
            text_values = forms
        else:
            text = "".join(translation.itertext()).strip()
            assert text, f"empty translation: {context_name} :: {source}"
            assert sorted(placeholder_re.findall(text)) == source_placeholders, \
                f"placeholder mismatch: {context_name} :: {source} -> {text}"
            text_values = [text]
        if source.rstrip().endswith("?"):
            assert all(v.rstrip().endswith("?") for v in text_values), \
                f"question mark lost: {context_name} :: {source}"
        if "…" in source:
            assert all("…" in v for v in text_values), \
                f"ellipsis lost: {context_name} :: {source}"
        messages.append((context_name, source, text_values))

assert len(messages) >= 409, f"catalog unexpectedly shrank to {len(messages)} messages"

# Exact remnants from the rejected word-fallback catalog must never return.
forbidden_fragments = (
    " daten rows", " schüler imported", " ist empty", " not found", " ending soon",
    " ready für concert", " noten school", " settings saved", " reminder added",
    " first unterricht", " external werk", " father – telefon", " mother – telefon",
    " no previous ensemble", " nein schüler", " nein backup", " required.",
)
for context, source, values in messages:
    for value in values:
        folded = value.casefold()
        for fragment in forbidden_fragments:
            assert fragment.casefold() not in folded, \
                f"mixed-language fallback detected: {context} :: {source} -> {value}"

print(f"PASS: {len(messages)} curated German messages; numerus/placeholders/punctuation/mixed-language guards are clean")

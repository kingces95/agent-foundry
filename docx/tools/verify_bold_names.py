#!/usr/bin/env python3
"""Verify that selected whole-word names are directly bold in a DOCX body."""

from __future__ import annotations

import argparse
import json
import re
import time
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"


def is_bold(run: ET.Element) -> bool:
    run_properties = run.find(f"{W}rPr")
    if run_properties is None:
        return False
    bold = run_properties.find(f"{W}b")
    if bold is None:
        return False
    value = bold.get(f"{W}val")
    return value is None or value.lower() not in {"0", "false", "off", "none"}


def read_body(path: Path) -> tuple[str, list[tuple[str, list[bool]]]]:
    with zipfile.ZipFile(path) as archive:
        root = ET.fromstring(archive.read("word/document.xml"))

    paragraphs: list[tuple[str, list[bool]]] = []
    document_text: list[str] = []
    for paragraph in root.iter(f"{W}p"):
        pieces: list[str] = []
        bold_flags: list[bool] = []
        for run in paragraph.iter(f"{W}r"):
            run_text = "".join(node.text or "" for node in run.iter(f"{W}t"))
            pieces.append(run_text)
            bold_flags.extend([is_bold(run)] * len(run_text))
        text = "".join(pieces)
        paragraphs.append((text, bold_flags))
        document_text.append(text)
    return "\n".join(document_text), paragraphs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("document", type=Path)
    parser.add_argument("--original", type=Path,
                        help="confirm that visible main-body text is unchanged")
    parser.add_argument("--names", nargs="+",
                        default=["Jane", "Rochester", "Edward", "St. John", "Helen", "Bertha"])
    args = parser.parse_args()

    started = time.perf_counter()
    output_text, paragraphs = read_body(args.document)
    visible_text_unchanged = None
    if args.original:
        original_text, _ = read_body(args.original)
        visible_text_unchanged = original_text == output_text

    results: dict[str, dict[str, int]] = {}
    failures: list[dict[str, object]] = []
    for name in args.names:
        pattern = re.compile(rf"(?<!\w){re.escape(name)}(?!\w)", re.IGNORECASE)
        occurrences = 0
        not_fully_bold = 0
        for paragraph_index, (text, flags) in enumerate(paragraphs, 1):
            for match in pattern.finditer(text):
                occurrences += 1
                if not all(flags[match.start():match.end()]):
                    not_fully_bold += 1
                    if len(failures) < 20:
                        failures.append({
                            "name": name,
                            "paragraph": paragraph_index,
                            "text": text[max(0, match.start() - 30):match.end() + 30],
                        })
        results[name] = {
            "occurrences": occurrences,
            "not_fully_bold": not_fully_bold,
        }

    valid = all(item["not_fully_bold"] == 0 for item in results.values())
    if visible_text_unchanged is False:
        valid = False
    report = {
        "valid": valid,
        "document": str(args.document.resolve()),
        "visible_body_text_unchanged": visible_text_unchanged,
        "timing_ms": round((time.perf_counter() - started) * 1000, 1),
        "names": results,
        "failures": failures,
    }
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if valid else 1


if __name__ == "__main__":
    raise SystemExit(main())

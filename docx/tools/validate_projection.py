#!/usr/bin/env python3
"""Validate hashes and paragraph coverage for a projected DOCX tree."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


PARAGRAPH_MARKER_RE = re.compile(r"^<!-- (?P<id>p\d{6}) -->$", re.MULTILINE)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def read_jsonl(path: Path) -> list[dict]:
    with path.open("r", encoding="utf-8") as stream:
        return [json.loads(line) for line in stream if line.strip()]


def validate(root: Path) -> dict:
    root = root.resolve()
    manifest_path = root / "projection" / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    errors: list[str] = []

    source_path = root / manifest["source"]["file"]
    if sha256_bytes(source_path.read_bytes()) != manifest["source"]["sha256"]:
        errors.append("Source DOCX hash does not match manifest.")

    ledger_path = root / manifest["ledger"]["file"]
    ledger_bytes = ledger_path.read_bytes()
    if sha256_bytes(ledger_bytes) != manifest["ledger"]["sha256"]:
        errors.append("Paragraph ledger hash does not match manifest.")
    records = read_jsonl(ledger_path)
    if len(records) != manifest["document"]["paragraph_count"]:
        errors.append("Paragraph ledger count does not match manifest.")

    expected_ids = [f"p{ordinal:06d}" for ordinal in range(1, len(records) + 1)]
    actual_ids = [record["id"] for record in records]
    if actual_ids != expected_ids:
        errors.append("Paragraph IDs are not continuous and ordered.")

    tables_path = root / manifest["tables"]["file"]
    if sha256_bytes(tables_path.read_bytes()) != manifest["tables"]["sha256"]:
        errors.append("Table ledger hash does not match manifest.")
    if len(read_jsonl(tables_path)) != manifest["tables"]["count"]:
        errors.append("Table ledger count does not match manifest.")

    expected_projected = {
        record["id"]
        for record in records
        if record["kind"] not in {"blank", "page-marker"}
    }
    seen: list[str] = []
    for part in manifest["parts"]:
        chapter_path = root / "projection" / part["file"]
        chapter_bytes = chapter_path.read_bytes()
        if sha256_bytes(chapter_bytes) != part["sha256"]:
            errors.append(f"Part hash mismatch: {part['file']}")
        markers = PARAGRAPH_MARKER_RE.findall(chapter_bytes.decode("utf-8"))
        if len(markers) != part["projected_paragraph_count"]:
            errors.append(f"Paragraph marker count mismatch: {part['file']}")
        seen.extend(markers)

    seen_set = set(seen)
    duplicates = len(seen) - len(seen_set)
    missing = sorted(expected_projected - seen_set)
    unexpected = sorted(seen_set - expected_projected)
    if duplicates:
        errors.append(f"Projected paragraph markers contain {duplicates} duplicate(s).")
    if missing:
        errors.append(f"Missing projected paragraph IDs: {', '.join(missing[:10])}")
    if unexpected:
        errors.append(f"Unexpected projected paragraph IDs: {', '.join(unexpected[:10])}")

    result = {
        "valid": not errors,
        "source_sha256": manifest["source"]["sha256"],
        "paragraphs": len(records),
        "projected_paragraphs": len(seen),
        "chapters": manifest["document"]["chapter_count"],
        "tables": manifest["tables"]["count"],
        "errors": errors,
    }
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, help="Document projection root")
    args = parser.parse_args()
    result = validate(args.root)
    print(json.dumps(result, indent=2))
    if not result["valid"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

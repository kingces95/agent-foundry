#!/usr/bin/env python3
"""Validate a Jane Eyre map/reduce analysis and optionally write build.json."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


ARC_SPECS = {
    1: list(range(1, 11)),
    2: list(range(11, 21)),
    3: list(range(21, 28)),
    4: list(range(28, 36)),
    5: list(range(36, 39)),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def paragraph_number(paragraph_id: str) -> int:
    match = re.fullmatch(r"p(\d{6})", paragraph_id)
    if not match:
        raise ValueError(f"invalid paragraph ID {paragraph_id!r}")
    return int(match.group(1))


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def validate(corpus: Path) -> tuple[list[str], dict[str, Any]]:
    errors: list[str] = []
    projection = corpus / "projection"
    analysis = corpus / "analysis"
    maps_dir = analysis / "maps"
    reductions_dir = analysis / "reductions"
    summary_path = analysis / "document-summary.md"
    manifest_path = projection / "manifest.json"
    ledger_path = projection / "paragraphs.jsonl"

    manifest = load_json(manifest_path)
    chapter_parts = {
        int(part["chapter"]): part
        for part in manifest["parts"]
        if part.get("chapter") is not None
    }
    require(sorted(chapter_parts) == list(range(1, 39)),
            "projection manifest must contain chapters 1-38", errors)

    paragraphs: dict[str, dict[str, Any]] = {}
    with ledger_path.open(encoding="utf-8") as stream:
        for line_number, line in enumerate(stream, 1):
            if not line.strip():
                continue
            record = json.loads(line)
            paragraph_id = record.get("id")
            require(paragraph_id not in paragraphs,
                    f"duplicate paragraph ID {paragraph_id} at ledger line {line_number}", errors)
            paragraphs[paragraph_id] = record

    expected_map_paths = [maps_dir / f"chapter-{chapter:02d}.json" for chapter in range(1, 39)]
    actual_map_paths = sorted(maps_dir.glob("chapter-*.json"))
    require(actual_map_paths == expected_map_paths,
            "analysis must contain exactly chapter-01.json through chapter-38.json", errors)

    map_records: dict[int, dict[str, Any]] = {}
    map_build: list[dict[str, Any]] = []
    map_evidence_count = 0
    for chapter, map_path in enumerate(expected_map_paths, 1):
        if not map_path.exists():
            continue
        try:
            record = load_json(map_path)
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{map_path.name}: cannot parse JSON: {exc}")
            continue
        map_records[chapter] = record
        prefix = map_path.name
        require(record.get("schema_version") == 1, f"{prefix}: unsupported schema_version", errors)
        require(record.get("kind") == "chapter-map", f"{prefix}: kind must be chapter-map", errors)
        require(record.get("chapter") == chapter, f"{prefix}: chapter field mismatch", errors)
        for field in ("summary", "events", "characters", "themes", "threads", "evidence"):
            require(bool(record.get(field)), f"{prefix}: {field} must be nonempty", errors)

        source = record.get("input", {})
        part = chapter_parts.get(chapter, {})
        expected_rel = f"../../projection/{part.get('file', '')}"
        require(source.get("file") == expected_rel, f"{prefix}: input file mismatch", errors)
        require(source.get("sha256") == part.get("sha256"), f"{prefix}: declared projection hash mismatch", errors)
        require(source.get("source_start") == part.get("source_start"), f"{prefix}: source_start mismatch", errors)
        require(source.get("source_end") == part.get("source_end"), f"{prefix}: source_end mismatch", errors)
        source_path = (map_path.parent / source.get("file", "")).resolve()
        require(source_path.is_file(), f"{prefix}: input projection does not exist", errors)
        if source_path.is_file():
            require(sha256(source_path) == source.get("sha256"),
                    f"{prefix}: input projection has changed", errors)

        for evidence in record.get("evidence", []):
            map_evidence_count += 1
            source_paragraph = paragraphs.get(evidence)
            require(source_paragraph is not None, f"{prefix}: unknown evidence {evidence}", errors)
            if source_paragraph is not None:
                require(source_paragraph.get("chapter") == chapter,
                        f"{prefix}: evidence {evidence} belongs to chapter {source_paragraph.get('chapter')}", errors)
            try:
                number = paragraph_number(evidence)
                lo = paragraph_number(source.get("source_start", ""))
                hi = paragraph_number(source.get("source_end", ""))
                require(lo <= number <= hi, f"{prefix}: evidence {evidence} outside declared range", errors)
            except ValueError as exc:
                errors.append(f"{prefix}: {exc}")

        map_build.append({
            "chapter": chapter,
            "file": f"maps/{map_path.name}",
            "sha256": sha256(map_path),
            "input_sha256": source.get("sha256"),
            "evidence_count": len(record.get("evidence", [])),
        })

    expected_arc_paths = [reductions_dir / f"arc-{arc:02d}.json" for arc in range(1, 6)]
    actual_arc_paths = sorted(reductions_dir.glob("arc-*.json"))
    require(actual_arc_paths == expected_arc_paths,
            "analysis must contain exactly arc-01.json through arc-05.json", errors)

    reduction_build: list[dict[str, Any]] = []
    reduction_evidence_count = 0
    reduced_chapters: list[int] = []
    for arc, arc_path in enumerate(expected_arc_paths, 1):
        if not arc_path.exists():
            continue
        try:
            record = load_json(arc_path)
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{arc_path.name}: cannot parse JSON: {exc}")
            continue
        prefix = arc_path.name
        expected_chapters = ARC_SPECS[arc]
        require(record.get("schema_version") == 1, f"{prefix}: unsupported schema_version", errors)
        require(record.get("kind") == "arc-reduction", f"{prefix}: kind must be arc-reduction", errors)
        require(record.get("arc") == arc, f"{prefix}: arc field mismatch", errors)
        require(record.get("chapters") == expected_chapters, f"{prefix}: chapter coverage mismatch", errors)
        reduced_chapters.extend(record.get("chapters", []))
        for field in ("summary", "developments", "character_arcs", "themes", "evidence"):
            require(bool(record.get(field)), f"{prefix}: {field} must be nonempty", errors)

        inputs = record.get("inputs", [])
        require(len(inputs) == len(expected_chapters), f"{prefix}: input count mismatch", errors)
        for index, chapter in enumerate(expected_chapters):
            if index >= len(inputs):
                break
            item = inputs[index]
            expected_file = f"../maps/chapter-{chapter:02d}.json"
            require(item.get("file") == expected_file, f"{prefix}: input {index + 1} file mismatch", errors)
            input_path = (arc_path.parent / item.get("file", "")).resolve()
            require(input_path.is_file(), f"{prefix}: missing input {item.get('file')}", errors)
            if input_path.is_file():
                require(sha256(input_path) == item.get("sha256"),
                        f"{prefix}: stale map hash for chapter {chapter}", errors)

        permitted_chapters = set(expected_chapters)
        for evidence in record.get("evidence", []):
            reduction_evidence_count += 1
            source_paragraph = paragraphs.get(evidence)
            require(source_paragraph is not None, f"{prefix}: unknown evidence {evidence}", errors)
            if source_paragraph is not None:
                require(source_paragraph.get("chapter") in permitted_chapters,
                        f"{prefix}: evidence {evidence} outside the arc", errors)

        reduction_build.append({
            "arc": arc,
            "file": f"reductions/{arc_path.name}",
            "sha256": sha256(arc_path),
            "chapters": expected_chapters,
            "evidence_count": len(record.get("evidence", [])),
        })

    require(reduced_chapters == list(range(1, 39)),
            "arc reductions must cover chapters 1-38 exactly once and in order", errors)
    require(summary_path.is_file(), "document-summary.md is missing", errors)
    if summary_path.is_file():
        summary_text = summary_path.read_text(encoding="utf-8")
        for heading in ("## Synopsis", "## Narrative summary", "## Principal character arcs",
                        "## Central themes", "## Build and coverage note"):
            require(heading in summary_text, f"document-summary.md missing {heading}", errors)
        require(len(summary_text.split()) >= 1000, "document-summary.md is unexpectedly short", errors)

    source_path = corpus / manifest["source"]["file"]
    require(source_path.is_file(), "source DOCX is missing", errors)
    if source_path.is_file():
        require(sha256(source_path) == manifest["source"]["sha256"],
                "source DOCX hash differs from projection manifest", errors)
    require(sha256(ledger_path) == manifest["ledger"]["sha256"],
            "paragraph ledger hash differs from projection manifest", errors)

    build = {
        "schema_version": 1,
        "valid": not errors,
        "source": {
            "file": "../source/jane-eyre.docx",
            "sha256": manifest["source"]["sha256"],
        },
        "projection": {
            "manifest_file": "../projection/manifest.json",
            "manifest_sha256": sha256(manifest_path),
            "paragraph_ledger_sha256": sha256(ledger_path),
        },
        "coverage": {
            "chapters_expected": 38,
            "chapter_maps": len(map_records),
            "arc_reductions": len(reduction_build),
            "chapters_reduced": reduced_chapters,
            "map_evidence_citations": map_evidence_count,
            "reduction_evidence_citations": reduction_evidence_count,
        },
        "maps": map_build,
        "reductions": reduction_build,
        "summary": {
            "file": "document-summary.md",
            "sha256": sha256(summary_path) if summary_path.is_file() else None,
            "word_count": len(summary_path.read_text(encoding="utf-8").split()) if summary_path.is_file() else 0,
        },
        "errors": errors,
    }
    return errors, build


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    default_corpus = Path(__file__).resolve().parents[1] / "jane-eyre"
    parser.add_argument("--corpus", type=Path, default=default_corpus,
                        help="corpus root containing source, projection, and analysis")
    parser.add_argument("--write-build", action="store_true",
                        help="write analysis/build.json even when validation fails")
    args = parser.parse_args()

    corpus = args.corpus.resolve()
    try:
        errors, build = validate(corpus)
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"valid": False, "fatal_error": str(exc)}, indent=2))
        return 2

    if args.write_build:
        output = corpus / "analysis" / "build.json"
        output.write_text(json.dumps(build, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(json.dumps({
        "valid": not errors,
        "chapter_maps": build["coverage"]["chapter_maps"],
        "arc_reductions": build["coverage"]["arc_reductions"],
        "summary_word_count": build["summary"]["word_count"],
        "errors": errors,
    }, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())

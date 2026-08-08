#!/usr/bin/env python3
"""Bold selected whole-word names by patching a DOCX's main OOXML story."""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import tempfile
import time
import zipfile
from pathlib import Path

from lxml import etree

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
XML_NS = "http://www.w3.org/XML/1998/namespace"
W = f"{{{W_NS}}}"
NS = {"w": W_NS}


def set_bold(run: etree._Element) -> None:
    properties = run.find(f"{W}rPr")
    if properties is None:
        properties = etree.Element(f"{W}rPr")
        run.insert(0, properties)
    bold = properties.find(f"{W}b")
    if bold is None:
        bold = etree.SubElement(properties, f"{W}b")
    bold.attrib.pop(f"{W}val", None)


def set_run_text(run: etree._Element, text: str) -> None:
    for node in list(run):
        if node.tag != f"{W}rPr":
            run.remove(node)
    text_node = etree.SubElement(run, f"{W}t")
    if text[:1].isspace() or text[-1:].isspace():
        text_node.set(f"{{{XML_NS}}}space", "preserve")
    text_node.text = text


def segments(mask: list[bool]) -> list[tuple[int, int, bool]]:
    if not mask:
        return []
    result: list[tuple[int, int, bool]] = []
    start = 0
    state = mask[0]
    for index, value in enumerate(mask[1:], 1):
        if value != state:
            result.append((start, index, state))
            start = index
            state = value
    result.append((start, len(mask), state))
    return result


def patch_document(xml: bytes, names: list[str]) -> tuple[bytes, dict[str, int], int]:
    parser = etree.XMLParser(remove_blank_text=False, resolve_entities=False)
    root = etree.fromstring(xml, parser)
    patterns = {
        name: re.compile(rf"(?<!\w){re.escape(name)}(?!\w)", re.IGNORECASE)
        for name in names
    }
    counts = {name: 0 for name in names}
    split_runs = 0

    for paragraph in root.xpath(".//w:p", namespaces=NS):
        run_records: list[tuple[etree._Element, str, int, int]] = []
        paragraph_text: list[str] = []
        cursor = 0
        for run in paragraph.xpath(".//w:r", namespaces=NS):
            text = "".join(run.xpath(".//w:t/text()", namespaces=NS))
            if not text:
                continue
            start = cursor
            cursor += len(text)
            run_records.append((run, text, start, cursor))
            paragraph_text.append(text)
        if not run_records:
            continue

        text = "".join(paragraph_text)
        selected = [False] * len(text)
        for name, pattern in patterns.items():
            for match in pattern.finditer(text):
                counts[name] += 1
                selected[match.start():match.end()] = [True] * (match.end() - match.start())

        for run, run_text, start, end in run_records:
            mask = selected[start:end]
            if not any(mask):
                continue
            if all(mask):
                set_bold(run)
                continue

            children = list(run)
            first_text_index = next(
                (index for index, child in enumerate(children) if child.tag == f"{W}t"),
                len(children),
            )
            prefix_children = [
                copy.deepcopy(child) for child in children[:first_text_index]
                if child.tag != f"{W}rPr"
            ]
            trailing_complex = [
                child.tag for child in children[first_text_index:]
                if child.tag not in {f"{W}t"}
            ]
            if trailing_complex:
                raise RuntimeError(
                    "cannot safely split a run with non-text content after its text: "
                    + ", ".join(trailing_complex)
                )

            parent = run.getparent()
            insertion_index = parent.index(run)
            for piece_number, (piece_start, piece_end, make_bold) in enumerate(segments(mask)):
                clone = copy.deepcopy(run)
                set_run_text(clone, run_text[piece_start:piece_end])
                if piece_number == 0:
                    text_index = next(
                        index for index, child in enumerate(clone)
                        if child.tag == f"{W}t"
                    )
                    for prefix_child in prefix_children:
                        clone.insert(text_index, prefix_child)
                        text_index += 1
                if make_bold:
                    set_bold(clone)
                parent.insert(insertion_index, clone)
                insertion_index += 1
            parent.remove(run)
            split_runs += 1

    declaration = xml.startswith(b"<?xml")
    output = etree.tostring(root, xml_declaration=declaration, encoding="UTF-8", standalone=True)
    return output, counts, split_runs


def write_patched_docx(input_path: Path, output_path: Path, document_xml: bytes) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary_name = tempfile.mkstemp(
        suffix=".docx", prefix=f".{output_path.stem}-", dir=output_path.parent
    )
    os.close(handle)
    temporary_path = Path(temporary_name)
    try:
        with zipfile.ZipFile(input_path, "r") as source, zipfile.ZipFile(temporary_path, "w") as target:
            for info in source.infolist():
                payload = document_xml if info.filename == "word/document.xml" else source.read(info.filename)
                target.writestr(info, payload)
        os.replace(temporary_path, output_path)
    finally:
        temporary_path.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--names", nargs="+",
                        default=["Jane", "Rochester", "Edward", "St. John", "Helen", "Bertha"])
    args = parser.parse_args()

    started = time.perf_counter()
    with zipfile.ZipFile(args.input) as archive:
        original_xml = archive.read("word/document.xml")
    patched_xml, counts, split_runs = patch_document(original_xml, args.names)
    write_patched_docx(args.input, args.output, patched_xml)
    elapsed = (time.perf_counter() - started) * 1000

    print(json.dumps({
        "input": str(args.input.resolve()),
        "output": str(args.output.resolve()),
        "bytes": args.output.stat().st_size,
        "names": counts,
        "total_occurrences": sum(counts.values()),
        "runs_split": split_runs,
        "timing_ms": round(elapsed, 1),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

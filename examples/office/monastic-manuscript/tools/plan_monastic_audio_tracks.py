from __future__ import annotations

import json
import re
import sys
import zipfile
from pathlib import Path

from lxml import etree

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
NS = {"w": W}
Q = lambda name: f"{{{W}}}{name}"
HEADER_RE = re.compile(r"^\s*W?Audio:\s*(.+?)\s*$", re.IGNORECASE)
ARCHIVE_RE = re.compile(r"^\s*Archive\s*#:\s*(.+?)\s*$", re.IGNORECASE)
INVALID_FILENAME = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def paragraph_text(element):
    return "".join(element.xpath(".//w:t/text()", namespaces=NS))


def is_empty_separator(element):
    if element.tag != Q("p") or paragraph_text(element).strip():
        return False
    meaningful = element.xpath(
        ".//w:drawing | .//w:object | .//w:pict | .//w:sectPr | "
        ".//w:footnoteReference | .//w:endnoteReference",
        namespaces=NS,
    )
    return not meaningful


def clean_filename(value):
    value = INVALID_FILENAME.sub("-", value)
    value = re.sub(r"\s+", " ", value).strip(" .")
    return value[:150].rstrip(" .")


def label_from_header(header):
    label = HEADER_RE.match(header).group(1)
    label = re.sub(r"\s*,\s*", " ", label)
    return re.sub(r"\s+", " ", label).strip()


def archive_near(children, start, end):
    for child in children[start + 1 : min(end, start + 14)]:
        if child.tag != Q("p"):
            continue
        match = ARCHIVE_RE.match(paragraph_text(child))
        if match:
            return re.sub(r"\.docx$", "", match.group(1).strip(), flags=re.IGNORECASE)
    return None


def build_plan(input_path):
    with zipfile.ZipFile(input_path) as package:
        root = etree.fromstring(package.read("word/document.xml"))
    body = root.find(".//w:body", namespaces=NS)
    children = list(body)
    boundaries = []
    for child_index, child in enumerate(children):
        if child.tag != Q("p"):
            continue
        text = paragraph_text(child).strip()
        if HEADER_RE.match(text):
            boundaries.append((child_index, text))
    if not boundaries:
        raise RuntimeError("No Audio:/WAudio: track headers were found")

    tracks = []
    width = max(3, len(str(len(boundaries))))
    for offset, (start, header) in enumerate(boundaries):
        raw_end = boundaries[offset + 1][0] if offset + 1 < len(boundaries) else len(children)
        end = raw_end
        while end > start + 1 and (
            children[end - 1].tag == Q("sectPr") or is_empty_separator(children[end - 1])
        ):
            end -= 1
        archive = archive_near(children, start, raw_end)
        name_parts = [f"{offset + 1:0{width}d}", label_from_header(header)]
        if archive:
            name_parts.append(archive)
        tracks.append(
            {
                "ordinal": offset + 1,
                "header": header,
                "archive": archive,
                "filename": clean_filename(" - ".join(name_parts)) + ".docx",
                "start_child": start,
                "end_child": end,
            }
        )
    return {"input": str(input_path), "track_count": len(tracks), "tracks": tracks}


if __name__ == "__main__":
    print(json.dumps(build_plan(Path(sys.argv[1])), ensure_ascii=True, indent=2))

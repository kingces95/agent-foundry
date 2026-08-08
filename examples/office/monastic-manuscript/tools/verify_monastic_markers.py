from __future__ import annotations

import hashlib
import json
import sys
import zipfile
from pathlib import Path

from lxml import etree

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
NS = {"w": W}


def paragraphs(path):
    with zipfile.ZipFile(path) as z:
        root = etree.fromstring(z.read("word/document.xml"))
    return ["".join(p.xpath(".//w:t/text()", namespaces=NS)) for p in root.xpath(".//w:body//w:p", namespaces=NS)]


target = Path(sys.argv[1])
output = Path(sys.argv[2])
expected_sections = int(sys.argv[3])
target_p = paragraphs(target)
output_p = paragraphs(output)
marker_words = {
    "begin red section",
    "start red section",
    "end red section",
    "red section begins",
    "red section ends",
}
target_content = [p for p in target_p if p.strip().lower() not in marker_words]
output_content = [p for p in output_p if p.strip().lower() not in marker_words]
markers = [p.strip() for p in output_p if p.strip().lower() in marker_words]
expected_markers = [
    item
    for _ in range(expected_sections)
    for item in ("Start Red Section", "End Red Section")
]
with zipfile.ZipFile(output) as output_zip:
    output_root = etree.fromstring(output_zip.read("word/document.xml"))
marker_paragraphs = [
    p
    for p in output_root.xpath(".//w:body//w:p", namespaces=NS)
    if "".join(p.xpath(".//w:t/text()", namespaces=NS)).strip()
    in {"Start Red Section", "End Red Section"}
]
red_bold_markers = 0
for paragraph in marker_paragraphs:
    run = paragraph.find(".//w:r", namespaces=NS)
    color = None if run is None else run.find("./w:rPr/w:color", namespaces=NS)
    bold = None if run is None else run.find("./w:rPr/w:b", namespaces=NS)
    if color is not None and color.get(f"{{{W}}}val", "").upper() == "FF0000" and bold is not None:
        red_bold_markers += 1

with zipfile.ZipFile(target) as left, zipfile.ZipFile(output) as right:
    left_names = left.namelist()
    right_names = right.namelist()
    package_names_equal = left_names == right_names
    changed_parts = []
    for name in left_names:
        if hashlib.sha256(left.read(name)).digest() != hashlib.sha256(right.read(name)).digest():
            changed_parts.append(name)
    right.testzip()

report = {
    "package_names_equal": package_names_equal,
    "changed_parts": changed_parts,
    "target_paragraphs": len(target_p),
    "output_paragraphs": len(output_p),
    "start_markers": markers.count("Start Red Section"),
    "end_markers": markers.count("End Red Section"),
    "markers_alternate": markers == expected_markers,
    "red_bold_markers": red_bold_markers,
    "non_marker_paragraph_text_equal": target_content == output_content,
    "valid": (
        package_names_equal
        and changed_parts == ["word/document.xml"]
        and markers == expected_markers
        and red_bold_markers == expected_sections * 2
        and target_content == output_content
    ),
}
print(json.dumps(report, indent=2))
if not report["valid"]:
    raise SystemExit(1)

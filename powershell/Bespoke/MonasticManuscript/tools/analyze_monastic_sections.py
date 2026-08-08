from __future__ import annotations

import json
import re
import sys
import zipfile
from collections import Counter
from pathlib import Path

from lxml import etree

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
NS = {"w": W}
Q = lambda n: f"{{{W}}}{n}"


def load(path: Path):
    with zipfile.ZipFile(path) as z:
        doc = etree.fromstring(z.read("word/document.xml"))
        styles_root = etree.fromstring(z.read("word/styles.xml"))
    styles = {}
    for style in styles_root.xpath(".//w:style", namespaces=NS):
        sid = style.get(Q("styleId"))
        color = style.find("./w:rPr/w:color", namespaces=NS)
        based = style.find("./w:basedOn", namespaces=NS)
        styles[sid] = (
            None if color is None else color.get(Q("val")),
            None if based is None else based.get(Q("val")),
        )

    def style_color(sid):
        seen = set()
        while sid and sid not in seen:
            seen.add(sid)
            color, sid = styles.get(sid, (None, None))
            if color:
                return color.upper()
        return None

    paragraphs = []
    for index, p in enumerate(doc.xpath(".//w:body//w:p", namespaces=NS)):
        p_style_el = p.find("./w:pPr/w:pStyle", namespaces=NS)
        p_style = None if p_style_el is None else p_style_el.get(Q("val"))
        text = "".join(p.xpath(".//w:t/text()", namespaces=NS))
        counts = Counter()
        fragments = []
        for r in p.xpath(".//w:r", namespaces=NS):
            txt = "".join(r.xpath(".//w:t/text()", namespaces=NS))
            if not txt:
                continue
            rs_el = r.find("./w:rPr/w:rStyle", namespaces=NS)
            rs = None if rs_el is None else rs_el.get(Q("val"))
            c_el = r.find("./w:rPr/w:color", namespaces=NS)
            color = None if c_el is None else c_el.get(Q("val"))
            color = (color or style_color(rs) or style_color(p_style) or "DEFAULT").upper()
            counts[color] += len(txt)
            fragments.append((txt, color))
        dominant = counts.most_common(1)[0][0] if counts else "EMPTY"
        paragraphs.append(
            {
                "index": index,
                "text": text,
                "norm": re.sub(r"\s+", " ", text).strip(),
                "dominant": dominant,
                "counts": dict(counts),
                # EE0000 is the source document's section-level red. Require it
                # to be the paragraph's dominant text color so isolated red
                # annotations do not create their own sections.
                "has_section_red": dominant == "EE0000",
                "fragments": fragments,
            }
        )
    return paragraphs


def section_spans(paragraphs):
    red_indices = [p["index"] for p in paragraphs if p["has_section_red"]]
    if not red_indices:
        return []
    spans = []
    start = prev = red_indices[0]
    for index in red_indices[1:]:
        # Empty separator paragraphs inside a colored block do not split it.
        gap = paragraphs[prev + 1 : index]
        if all(not p["norm"] for p in gap):
            prev = index
            continue
        spans.append((start, prev))
        start = prev = index
    spans.append((start, prev))
    return spans


def main():
    path = Path(sys.argv[1])
    paragraphs = load(path)
    if len(sys.argv) == 4 and sys.argv[2] == "--range":
        start_text, end_text = sys.argv[3].split(":", 1)
        start, end = int(start_text), int(end_text)
        compact = [
            {
                "index": p["index"],
                "dominant": p["dominant"],
                "counts": p["counts"],
                "text": p["norm"][:240],
            }
            for p in paragraphs[start : end + 1]
        ]
        print(json.dumps(compact, ensure_ascii=False, indent=2))
        return
    spans = section_spans(paragraphs)
    result = []
    for number, (start, end) in enumerate(spans, 1):
        red_chars = sum(p["counts"].get("EE0000", 0) for p in paragraphs[start : end + 1])
        before = next((p for p in reversed(paragraphs[:start]) if p["norm"]), None)
        after = next((p for p in paragraphs[end + 1 :] if p["norm"]), None)
        result.append(
            {
                "number": number,
                "start": start,
                "end": end,
                "paragraphs": end - start + 1,
                "red_chars": red_chars,
                "before": None if before is None else {"index": before["index"], "text": before["norm"][:180]},
                "first": paragraphs[start]["norm"][:240],
                "last": paragraphs[end]["norm"][-240:],
                "after": None if after is None else {"index": after["index"], "text": after["norm"][:180]},
            }
        )
    print(json.dumps({"path": str(path), "span_count": len(spans), "spans": result}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

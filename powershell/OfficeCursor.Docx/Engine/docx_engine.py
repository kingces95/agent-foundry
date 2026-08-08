from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import zipfile
from collections import Counter
from pathlib import Path

from lxml import etree

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
XML = "http://www.w3.org/XML/1998/namespace"
NS = {"w": W}
Q = lambda name: f"{{{W}}}{name}"
PPR_ORDER = [
    "pStyle", "keepNext", "keepLines", "pageBreakBefore", "widowControl", "numPr",
    "suppressLineNumbers", "pBdr", "shd", "tabs", "suppressAutoHyphens", "kinsoku",
    "wordWrap", "overflowPunct", "topLinePunct", "autoSpaceDE", "autoSpaceDN", "bidi",
    "adjustRightInd", "snapToGrid", "spacing", "ind", "contextualSpacing", "mirrorIndents",
    "suppressOverlap", "jc", "textDirection", "textAlignment", "textboxTightWrap",
    "outlineLvl", "divId", "cnfStyle", "rPr", "sectPr", "pPrChange",
]
RPR_ORDER = [
    "rStyle", "rFonts", "b", "bCs", "i", "iCs", "caps", "smallCaps", "strike",
    "dstrike", "outline", "shadow", "emboss", "imprint", "noProof", "snapToGrid",
    "vanish", "webHidden", "color", "spacing", "w", "kern", "position", "sz", "szCs",
    "highlight", "u", "effect", "bdr", "shd", "fitText", "vertAlign", "rtl", "cs",
    "em", "lang", "eastAsianLayout", "specVanish", "oMath", "rPrChange",
]
ALIGNMENT_VALUES = {"left": "left", "center": "center", "right": "right", "justify": "both"}
UNDERLINE_VALUES = {"none": "none", "single": "single", "double": "double", "words": "words"}
HIGHLIGHT_VALUES = {
    "none": "none", "yellow": "yellow", "brightgreen": "green", "turquoise": "cyan",
    "pink": "magenta", "blue": "blue", "red": "red", "darkblue": "darkBlue",
    "teal": "darkCyan", "green": "darkGreen", "violet": "darkMagenta",
    "darkred": "darkRed", "darkyellow": "darkYellow", "gray50": "darkGray",
    "gray25": "lightGray", "black": "black",
}


def paragraph_text(element):
    return "".join(element.xpath(".//w:t/text()", namespaces=NS))


def normalized_text(element):
    return re.sub(r"\s+", " ", paragraph_text(element)).strip()


def read_package(path):
    with zipfile.ZipFile(path) as package:
        return [(item, package.read(item)) for item in package.infolist()]


def package_part(parts, name):
    return next(data for item, data in parts if item.filename == name)


def write_package(parts, output_path, document_xml):
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = output_path.with_suffix(output_path.suffix + ".tmp")
    try:
        with zipfile.ZipFile(temporary, "w") as output:
            for item, data in parts:
                output.writestr(item, document_xml if item.filename == "word/document.xml" else data)
        os.replace(temporary, output_path)
    finally:
        if temporary.exists():
            temporary.unlink()


def style_colors(styles_xml):
    root = etree.fromstring(styles_xml)
    styles = {}
    for style in root.xpath(".//w:style", namespaces=NS):
        style_id = style.get(Q("styleId"))
        color = style.find("./w:rPr/w:color", namespaces=NS)
        based_on = style.find("./w:basedOn", namespaces=NS)
        styles[style_id] = (
            None if color is None else color.get(Q("val")),
            None if based_on is None else based_on.get(Q("val")),
        )
    return styles


def inherited_color(styles, style_id):
    seen = set()
    while style_id and style_id not in seen:
        seen.add(style_id)
        color, style_id = styles.get(style_id, (None, None))
        if color:
            return color.upper()
    return None


def project_paragraphs(document_xml, styles_xml):
    root = etree.fromstring(document_xml)
    body = root.find(".//w:body", namespaces=NS)
    styles = style_colors(styles_xml)
    projected = []
    for index, paragraph in enumerate(root.xpath(".//w:body//w:p", namespaces=NS)):
        paragraph_style_element = paragraph.find("./w:pPr/w:pStyle", namespaces=NS)
        paragraph_style = None if paragraph_style_element is None else paragraph_style_element.get(Q("val"))
        counts = Counter()
        for run in paragraph.xpath(".//w:r", namespaces=NS):
            text = paragraph_text(run)
            if not text:
                continue
            run_style_element = run.find("./w:rPr/w:rStyle", namespaces=NS)
            run_style = None if run_style_element is None else run_style_element.get(Q("val"))
            color_element = run.find("./w:rPr/w:color", namespaces=NS)
            direct_color = None if color_element is None else color_element.get(Q("val"))
            color = (
                direct_color
                or inherited_color(styles, run_style)
                or inherited_color(styles, paragraph_style)
                or "DEFAULT"
            ).upper()
            counts[color] += len(text)
        text = paragraph_text(paragraph)
        parent = paragraph.getparent()
        projected.append(
            {
                "index": index,
                "body_child_index": body.index(paragraph) if parent is body else None,
                "text": text,
                "normalized_text": re.sub(r"\s+", " ", text).strip(),
                "dominant_color": counts.most_common(1)[0][0] if counts else "EMPTY",
                "character_count": len(text),
            }
        )
    return projected


def changed_parts(original_parts, output_path):
    with zipfile.ZipFile(output_path) as output:
        bad_part = output.testzip()
        if bad_part:
            raise RuntimeError(f"Corrupt ZIP member: {bad_part}")
        names = output.namelist()
        output_data = {name: output.read(name) for name in names}
    original_names = [item.filename for item, _ in original_parts]
    if original_names != names:
        raise RuntimeError("Output package part names or ordering changed")
    return [
        item.filename
        for item, data in original_parts
        if hashlib.sha256(data).digest() != hashlib.sha256(output_data[item.filename]).digest()
    ]


def property_map(value, description):
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise RuntimeError(f"{description} must be an object")
    return {str(key).casefold(): item for key, item in value.items()}


def ordered_child(parent, name, order):
    existing = parent.find(f"./w:{name}", namespaces=NS)
    if existing is not None:
        return existing
    child = etree.Element(Q(name))
    desired = order.index(name)
    position = len(parent)
    for index, sibling in enumerate(parent):
        local_name = etree.QName(sibling).localname
        if local_name in order and order.index(local_name) > desired:
            position = index
            break
    parent.insert(position, child)
    return child


def set_toggle(parent, name, value, order):
    element = ordered_child(parent, name, order)
    element.set(Q("val"), "1" if value else "0")


def points_to_twips(value):
    return str(round(float(value) * 20))


def points_to_half_points(value):
    return str(round(float(value) * 2))


def paragraph_style_map(styles_xml):
    root = etree.fromstring(styles_xml)
    result = {}
    for style in root.xpath(".//w:style[@w:type='paragraph']", namespaces=NS):
        style_id = style.get(Q("styleId"))
        if style_id:
            result[style_id.casefold()] = style_id
        name = style.find("./w:name", namespaces=NS)
        display_name = None if name is None else name.get(Q("val"))
        if display_name and style_id:
            result[display_name.casefold()] = style_id
    return result


def apply_run_formatting(properties, formatting):
    if "fontname" in formatting:
        fonts = ordered_child(properties, "rFonts", RPR_ORDER)
        for attribute in ("ascii", "hAnsi", "eastAsia", "cs"):
            fonts.set(Q(attribute), str(formatting["fontname"]))
    for key, tag in (("bold", "b"), ("italic", "i"), ("strikethrough", "strike")):
        if key in formatting:
            set_toggle(properties, tag, bool(formatting[key]), RPR_ORDER)
    if "color" in formatting:
        color = ordered_child(properties, "color", RPR_ORDER)
        value = str(formatting["color"])
        color.set(Q("val"), "auto" if value.casefold() == "auto" else value.upper())
    if "fontsizepoints" in formatting:
        value = points_to_half_points(formatting["fontsizepoints"])
        ordered_child(properties, "sz", RPR_ORDER).set(Q("val"), value)
        ordered_child(properties, "szCs", RPR_ORDER).set(Q("val"), value)
    if "highlightcolor" in formatting:
        value = HIGHLIGHT_VALUES[str(formatting["highlightcolor"]).casefold()]
        ordered_child(properties, "highlight", RPR_ORDER).set(Q("val"), value)
    if "underline" in formatting:
        value = UNDERLINE_VALUES[str(formatting["underline"]).casefold()]
        ordered_child(properties, "u", RPR_ORDER).set(Q("val"), value)
    if "verticalposition" in formatting:
        value = str(formatting["verticalposition"]).casefold()
        vertical = {"baseline": "baseline", "superscript": "superscript", "subscript": "subscript"}[value]
        ordered_child(properties, "vertAlign", RPR_ORDER).set(Q("val"), vertical)


def apply_paragraph_formatting(properties, formatting, styles):
    if "style" in formatting:
        requested = str(formatting["style"])
        style_id = styles.get(requested.casefold())
        if not style_id:
            raise RuntimeError(f"Paragraph style was not found by name or ID: {requested}")
        ordered_child(properties, "pStyle", PPR_ORDER).set(Q("val"), style_id)
    for key, tag in (
        ("keepwithnext", "keepNext"), ("keeplines", "keepLines"),
        ("pagebreakbefore", "pageBreakBefore"),
    ):
        if key in formatting:
            set_toggle(properties, tag, bool(formatting[key]), PPR_ORDER)
    if "alignment" in formatting:
        value = ALIGNMENT_VALUES[str(formatting["alignment"]).casefold()]
        ordered_child(properties, "jc", PPR_ORDER).set(Q("val"), value)

    spacing_keys = {
        "spacebeforepoints", "spaceafterpoints", "linespacingrule",
        "linespacingmultiple", "linespacingpoints",
    }
    if spacing_keys.intersection(formatting):
        spacing = ordered_child(properties, "spacing", PPR_ORDER)
        if "spacebeforepoints" in formatting:
            spacing.set(Q("before"), points_to_twips(formatting["spacebeforepoints"]))
        if "spaceafterpoints" in formatting:
            spacing.set(Q("after"), points_to_twips(formatting["spaceafterpoints"]))
        if "linespacingrule" in formatting:
            rule = str(formatting["linespacingrule"]).casefold()
            if rule == "single":
                line, line_rule = "240", "auto"
            elif rule == "oneandhalf":
                line, line_rule = "360", "auto"
            elif rule == "double":
                line, line_rule = "480", "auto"
            elif rule == "multiple":
                line, line_rule = str(round(float(formatting["linespacingmultiple"]) * 240)), "auto"
            elif rule == "exactly":
                line, line_rule = points_to_twips(formatting["linespacingpoints"]), "exact"
            else:
                line, line_rule = points_to_twips(formatting["linespacingpoints"]), "atLeast"
            spacing.set(Q("line"), line)
            spacing.set(Q("lineRule"), line_rule)

    indent_keys = {"leftindentpoints", "rightindentpoints", "specialindent", "specialindentbypoints"}
    if indent_keys.intersection(formatting):
        indent = ordered_child(properties, "ind", PPR_ORDER)
        if "leftindentpoints" in formatting:
            indent.set(Q("left"), points_to_twips(formatting["leftindentpoints"]))
        if "rightindentpoints" in formatting:
            indent.set(Q("right"), points_to_twips(formatting["rightindentpoints"]))
        if "specialindent" in formatting:
            for attribute in ("firstLine", "hanging", "firstLineChars", "hangingChars"):
                indent.attrib.pop(Q(attribute), None)
            special = str(formatting["specialindent"]).casefold()
            if special == "none":
                indent.set(Q("firstLine"), "0")
                indent.set(Q("hanging"), "0")
            elif special == "firstline":
                indent.set(Q("firstLine"), points_to_twips(formatting["specialindentbypoints"]))
            else:
                indent.set(Q("hanging"), points_to_twips(formatting["specialindentbypoints"]))


def inserted_paragraph(reference, edit, styles):
    paragraph = etree.Element(Q("p"), nsmap=reference.nsmap)
    if edit.get("CopyParagraphFormatting", True):
        properties = reference.find("./w:pPr", namespaces=NS)
        if properties is not None:
            paragraph.append(copy.deepcopy(properties))
    paragraph_formatting = property_map(get_field(edit, "ParagraphFormatting", {}), "ParagraphFormatting")
    if paragraph_formatting:
        properties = paragraph.find("./w:pPr", namespaces=NS)
        if properties is None:
            properties = etree.Element(Q("pPr"))
            paragraph.insert(0, properties)
        apply_paragraph_formatting(properties, paragraph_formatting, styles)
    run = etree.SubElement(paragraph, Q("r"))
    run_formatting = property_map(get_field(edit, "RunFormatting", {}), "RunFormatting")
    if run_formatting:
        formatting = etree.SubElement(run, Q("rPr"))
        apply_run_formatting(formatting, run_formatting)
    text = etree.SubElement(run, Q("t"))
    text.set(f"{{{XML}}}space", "preserve")
    text.text = str(edit.get("Text", ""))
    return paragraph


def get_field(value, name, default=None):
    for key, item in value.items():
        if key.casefold() == name.casefold():
            return item
    return default


def edit_paragraphs(args):
    input_path = Path(args.input)
    output_path = Path(args.output)
    if output_path.exists() and not args.force:
        raise RuntimeError(f"Output already exists: {output_path}; use --force")
    edits = json.loads(Path(args.edits_json).read_text(encoding="utf-8-sig"))
    if isinstance(edits, dict):
        edits = [edits]
    parts = read_package(input_path)
    styles = paragraph_style_map(package_part(parts, "word/styles.xml"))
    root = etree.fromstring(package_part(parts, "word/document.xml"))
    paragraphs = root.xpath(".//w:body//w:p", namespaces=NS)
    inserted = deleted = 0
    for raw_edit in edits:
        action = str(get_field(raw_edit, "Action", "")).casefold()
        index = int(get_field(raw_edit, "Index", -1))
        if index < 0 or index >= len(paragraphs):
            raise RuntimeError(f"Paragraph index is out of range: {index}")
        reference = paragraphs[index]
        parent = reference.getparent()
        if parent is None:
            raise RuntimeError(f"Paragraph {index} was already deleted")
        if action == "delete":
            parent.remove(reference)
            deleted += 1
        elif action in {"insertbefore", "insertafter"}:
            position = parent.index(reference) + (1 if action == "insertafter" else 0)
            parent.insert(position, inserted_paragraph(reference, raw_edit, styles))
            inserted += 1
        else:
            raise RuntimeError(f"Unsupported paragraph edit action: {get_field(raw_edit, 'Action')}")
    document_xml = etree.tostring(root, xml_declaration=True, encoding="UTF-8", standalone=True)
    write_package(parts, output_path, document_xml)
    changed = changed_parts(parts, output_path)
    if changed != ["word/document.xml"]:
        raise RuntimeError(f"Expected only word/document.xml to change; changed: {changed}")
    with zipfile.ZipFile(output_path) as output:
        output_root = etree.fromstring(output.read("word/document.xml"))
    output_count = len(output_root.xpath(".//w:body//w:p", namespaces=NS))
    expected_count = len(paragraphs) + inserted - deleted
    if output_count != expected_count:
        raise RuntimeError(
            f"Paragraph-count verification failed: expected {expected_count}, found {output_count}"
        )
    return {
        "input": str(input_path), "output": str(output_path), "edit_count": len(edits),
        "inserted_count": inserted, "deleted_count": deleted,
        "changed_parts": changed, "verified": True,
    }


def canonical_body(children):
    return b"".join(
        etree.tostring(child, method="c14n") for child in children if child.tag != Q("sectPr")
    )


def export_body_slices(args):
    input_path = Path(args.input)
    slices = json.loads(Path(args.slices_json).read_text(encoding="utf-8-sig"))
    if isinstance(slices, dict):
        slices = [slices]
    parts = read_package(input_path)
    original_root = etree.fromstring(package_part(parts, "word/document.xml"))
    body = original_root.find(".//w:body", namespaces=NS)
    children = list(body)
    section_properties = next((child for child in reversed(children) if child.tag == Q("sectPr")), None)
    reports = []
    outputs = set()
    for raw_slice in slices:
        start = int(get_field(raw_slice, "StartIndex"))
        end = int(get_field(raw_slice, "EndIndex"))
        output_path = Path(str(get_field(raw_slice, "OutputPath")))
        if start < 0 or end <= start or end > len(children):
            raise RuntimeError(f"Invalid body slice [{start}, {end})")
        folded = str(output_path.resolve()).casefold()
        if folded in outputs:
            raise RuntimeError(f"Duplicate output path: {output_path}")
        outputs.add(folded)
        if output_path.exists() and not args.force:
            raise RuntimeError(f"Output already exists: {output_path}; use --force")

        root = copy.deepcopy(original_root)
        output_body = root.find(".//w:body", namespaces=NS)
        for child in list(output_body):
            output_body.remove(child)
        for child in children[start:end]:
            if child.tag != Q("sectPr"):
                output_body.append(copy.deepcopy(child))
        if section_properties is not None:
            output_body.append(copy.deepcopy(section_properties))
        document_xml = etree.tostring(root, xml_declaration=True, encoding="UTF-8", standalone=True)
        write_package(parts, output_path, document_xml)
        with zipfile.ZipFile(output_path) as package:
            if package.testzip():
                raise RuntimeError(f"Output package is corrupt: {output_path}")
            verified_root = etree.fromstring(package.read("word/document.xml"))
        actual = canonical_body(list(verified_root.find(".//w:body", namespaces=NS)))
        expected = canonical_body(children[start:end])
        if actual != expected:
            raise RuntimeError(f"Output body differs from source slice: {output_path}")
        reports.append(
            {"output": str(output_path), "start_index": start, "end_index": end,
             "body_sha256": hashlib.sha256(actual).hexdigest(), "verified": True}
        )
    return {"input": str(input_path), "slice_count": len(reports), "slices": reports}


def parser():
    root = argparse.ArgumentParser(description="Office Cursor offline DOCX primitives")
    commands = root.add_subparsers(dest="command", required=True)
    inspect = commands.add_parser("get-paragraphs")
    inspect.add_argument("--input", required=True)
    edit = commands.add_parser("edit-paragraphs")
    edit.add_argument("--input", required=True)
    edit.add_argument("--output", required=True)
    edit.add_argument("--edits-json", required=True)
    edit.add_argument("--force", action="store_true")
    export = commands.add_parser("export-body-slices")
    export.add_argument("--input", required=True)
    export.add_argument("--slices-json", required=True)
    export.add_argument("--force", action="store_true")
    return root


def main():
    args = parser().parse_args()
    if args.command == "get-paragraphs":
        parts = read_package(Path(args.input))
        result = {
            "input": args.input,
            "paragraphs": project_paragraphs(
                package_part(parts, "word/document.xml"), package_part(parts, "word/styles.xml")
            ),
        }
    elif args.command == "edit-paragraphs":
        result = edit_paragraphs(args)
    else:
        result = export_body_slices(args)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

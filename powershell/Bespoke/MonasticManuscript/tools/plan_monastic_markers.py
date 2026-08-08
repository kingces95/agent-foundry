from __future__ import annotations

import json
import re
import sys
from difflib import SequenceMatcher
from pathlib import Path

from analyze_monastic_sections import load

MARKER_RE = re.compile(r"(?i)^\s*(?:begin|start|end|red section begins|red section ends).*red section|^\s*red section (?:begins|ends)\s*$")


def is_marker(text: str) -> bool:
    low = text.strip().lower()
    return low in {
        "begin red section",
        "start red section",
        "end red section",
        "red section begins",
        "red section ends",
    }


def annotation_only(p: dict) -> bool:
    if not p["norm"]:
        return True
    return p["dominant"] == "FF0000"


def explicit_intervals(paragraphs: list[dict]):
    starts = []
    intervals = []
    for p in paragraphs:
        low = p["norm"].lower()
        if low in {"begin red section", "start red section", "red section begins"}:
            starts.append(p["index"])
        elif low in {"end red section", "red section ends"} and starts:
            intervals.append((starts.pop(), p["index"]))
    return intervals


def derive_sections(paragraphs: list[dict]):
    explicit = explicit_intervals(paragraphs)
    inside_explicit = set()
    for start, end in explicit:
        inside_explicit.update(range(start + 1, end))

    is_red = [False] * len(paragraphs)
    for p in paragraphs:
        i = p["index"]
        is_red[i] = p["dominant"] == "EE0000" or i in inside_explicit

    sections = []
    i = 0
    while i < len(paragraphs):
        if not is_red[i]:
            i += 1
            continue
        start = i
        last_red = i
        j = i + 1
        while j < len(paragraphs):
            if is_red[j]:
                last_red = j
                j += 1
            elif annotation_only(paragraphs[j]):
                j += 1
            else:
                break
        end = last_red
        # Keep annotation-only paragraphs between red paragraphs, but do not
        # extend a section past its final section-red paragraph.
        sections.append((start, end))
        i = max(j, end + 1)

    # Explicit source markers are instructions, not transcript content.
    cleaned = []
    for start, end in sections:
        while start <= end and (not paragraphs[start]["norm"] or is_marker(paragraphs[start]["norm"])):
            start += 1
        while end >= start and (not paragraphs[end]["norm"] or is_marker(paragraphs[end]["norm"])):
            end -= 1
        if start <= end:
            cleaned.append((start, end))
    return cleaned


def comparable(paragraphs):
    return [p for p in paragraphs if p["norm"] and not is_marker(p["norm"])]


def exact_alignment(source, target):
    sm = SequenceMatcher(None, [p["norm"] for p in source], [p["norm"] for p in target], autojunk=False)
    mapping = {}
    for block in sm.get_matching_blocks():
        for offset in range(block.size):
            mapping[source[block.a + offset]["index"]] = target[block.b + offset]["index"]
    return mapping, sm.ratio()


def text_score(left: str, right: str) -> float:
    if len(left) >= 24 and len(right) >= 24 and (left in right or right in left):
        return 1.0
    return SequenceMatcher(None, left, right, autojunk=False).ratio()


def fuzzy_map(source_p, target, exact, source_index, boundary):
    if source_index in exact:
        return exact[source_index], 1.0, "exact"
    prior = [s for s in exact if s < source_index]
    later = [s for s in exact if s > source_index]
    lo = exact[max(prior)] + 1 if prior else 0
    hi = exact[min(later)] - 1 if later else target[-1]["index"]
    candidates = [p for p in target if lo <= p["index"] <= hi]
    if not candidates:
        candidates = target
    if prior and later:
        left_source, right_source = max(prior), min(later)
        left_target, right_target = exact[left_source], exact[right_source]
        fraction = (source_index - left_source) / max(1, right_source - left_source)
        expected = left_target + fraction * (right_target - left_target)
    elif prior:
        anchor = max(prior)
        expected = exact[anchor] + (source_index - anchor)
    elif later:
        anchor = min(later)
        expected = exact[anchor] - (anchor - source_index)
    else:
        expected = source_index
    best = max(
        candidates,
        key=lambda p: (text_score(source_p["norm"], p["norm"]), -abs(p["index"] - expected)),
    )
    score = text_score(source_p["norm"], best["norm"])
    if score >= 0.85:
        return best["index"], score, "fuzzy"
    # A rewritten or deleted boundary paragraph is still safely locatable from
    # the surrounding exact alignment. Start before the next exact paragraph;
    # end after the previous exact paragraph.
    if boundary == "start" and later:
        anchor = min(later)
        return exact[anchor], 1.0, "next_exact_anchor"
    if boundary == "end" and prior:
        anchor = max(prior)
        return exact[anchor], 1.0, "previous_exact_anchor"
    return best["index"], score, "fuzzy_low"


def map_section_boundary(source, target, exact, start, end, boundary):
    indices = range(start, end + 1) if boundary == "start" else range(end, start - 1, -1)
    # Prefer the first/last paragraph that participates in the monotonic exact
    # alignment. This avoids matching a deleted heading to the same words in
    # an earlier, unrelated paragraph.
    for source_index in indices:
        if source_index in exact:
            return exact[source_index], 1.0, "exact", source_index

    indices = range(start, end + 1) if boundary == "start" else range(end, start - 1, -1)
    fallback = None
    for source_index in indices:
        if not source[source_index]["norm"] or is_marker(source[source_index]["norm"]):
            continue
        mapped = fuzzy_map(source[source_index], target, exact, source_index, boundary)
        if fallback is None:
            fallback = (*mapped, source_index)
        if mapped[2] in {"exact", "fuzzy"}:
            return (*mapped, source_index)
    return fallback


def build_plan(source_path: Path, target_path: Path):
    source_p = load(source_path)
    target_p = load(target_path)
    sections = derive_sections(source_p)
    source_c = comparable(source_p)
    target_c = comparable(target_p)
    exact, alignment_ratio = exact_alignment(source_c, target_c)

    plans = []
    for number, (start, end) in enumerate(sections, 1):
        start_i, start_score, start_method, start_anchor = map_section_boundary(source_p, target_c, exact, start, end, "start")
        end_i, end_score, end_method, end_anchor = map_section_boundary(source_p, target_c, exact, start, end, "end")
        plans.append(
            {
                "number": number,
                "source_start": start,
                "source_end": end,
                "target_start": start_i,
                "target_end": end_i,
                "source_start_anchor": start_anchor,
                "source_end_anchor": end_anchor,
                "start_score": round(start_score, 4),
                "end_score": round(end_score, 4),
                "start_method": start_method,
                "end_method": end_method,
                "first": source_p[start]["norm"][:180],
                "last": source_p[end]["norm"][-180:],
            }
        )

    issues = []
    previous_end = -1
    for plan in plans:
        if plan["target_start"] > plan["target_end"]:
            issues.append({"section": plan["number"], "issue": "reversed"})
        if plan["target_start"] <= previous_end:
            issues.append({"section": plan["number"], "issue": "overlap_or_out_of_order"})
        if min(plan["start_score"], plan["end_score"]) < 0.85:
            issues.append({"section": plan["number"], "issue": "low_confidence"})
        previous_end = max(previous_end, plan["target_end"])

    return {
        "source": str(source_path),
        "target": str(target_path),
        "section_count": len(plans),
        "exact_paragraph_matches": len(exact),
        "alignment_ratio": round(alignment_ratio, 4),
        "issues": issues,
        "plans": plans,
    }


if __name__ == "__main__":
    # Keep the CLI stream ASCII-safe for Windows PowerShell 5.1 hosts. JSON
    # decoding restores the original Unicode text for callers.
    print(json.dumps(build_plan(Path(sys.argv[1]), Path(sys.argv[2])), ensure_ascii=True, indent=2))

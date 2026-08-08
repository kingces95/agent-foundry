# Monastic red-section marker workflow

## Task

Transfer section boundaries from a color-coded editorial DOCX into a checked
transcript without copying the source document's formatting.

## Discovered conventions

- EE0000 is section-level red in VPI MSH this one.docx.
- FF0000 is annotation red used for timestamps and Tibetan labels.
- FF0000-only paragraphs inside an EE0000 region do not split the section.
- Ordinary black, green, or purple prose ends an EE0000 section.
- Existing Begin/End red section pairs in the source are authoritative even
  where mixed run formatting makes the visual region otherwise ambiguous.
- Output markers are literal Start Red Section and End Red Section paragraphs.
- Both output marker types are explicitly formatted red and bold.

## Alignment and safety

The profile planner aligns normalized non-empty paragraphs with a monotonic exact
sequence match, then handles rewritten or merged paragraphs with constrained
fuzzy and substring matching. It refuses plans with low-confidence, reversed,
or overlapping boundaries.

The planner emits only indexed insert/delete operations. The general
`Edit-DocxParagraph` capability applies and structurally verifies the package
change; it has no knowledge of marker meanings or this manuscript.

The source files are never overwritten. Verification requires:

- only word/document.xml changes inside the DOCX package;
- equal non-marker paragraph text before and after;
- equal counts of start and end markers;
- strict marker alternation;
- a parseable ZIP/OOXML package.

For the 2026-08-07 manuscript, the result contained 118 section pairs, 236
markers, 6,053 exact paragraph matches, and a 0.9678 sequence alignment ratio.
Word rendered the result as 1,110 A5 pages and PDF extraction found all 236
markers.

## Commands

Run powershell/Bespoke/MonasticManuscript/Add-ManuscriptRedSectionMarkers.ps1
to create and structurally verify the marked transcript.

Use Export-WordDocumentPdf from the OfficeCursor.Word module when LibreOffice
is unavailable and Word's native renderer is the QA fallback.

## Audio-track splitting

The marked checked transcript contains 130 explicit Audio:/WAudio: headers
covering Tapes 1 through 67. Split-ManuscriptAudioTrack.ps1 uses those headers
as authoritative boundaries and names files with a three-digit source ordinal,
the literal tape/side label, and the nearby archive number.

The source contains intentional or unresolved anomalies, including duplicate
labels and duplicate-marked recordings. Do not renumber or silently correct
them; the source ordinal provides stable identity and sort order.

The bespoke planner decides the ranges and filenames, then
`Export-DocxBodySlice` writes the packages. Each output's canonical OOXML body
must equal the corresponding source slice. Empty boundary separator
paragraphs may be omitted to prevent blank trailing pages, but substantive
text, drawings, references, and section content may not be dropped.

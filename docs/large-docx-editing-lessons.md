# Large DOCX editing: lessons from the Jane Eyre benchmark

This note records operational knowledge for future Codex sessions. It is based
on `docx/jane-eyre/test/benchmark.json`, not estimated performance.

## Benchmark

The input was the Jane Eyre fixture, which Microsoft Word reports as 610 pages.
The transform bolded `Jane`, `Rochester`, `Edward`, `St. John`, `Helen`, and
`Bertha` in the main document story. There were 938 source occurrences.

| Path | Edit time | Other measured time | Result |
| --- | ---: | ---: | --- |
| Word COM with six native `Replace All` operations | 10,258 ms | 4,844 ms open; 535 ms save; 28,001 ms process total | All matches bold, but Word regenerated stale TOC and pagination fields. Not formatting-only. |
| Direct OOXML patch | 481 ms | 419 ms exhaustive verification | All 938 matches bold; extracted visible body text unchanged. |

The direct package edit was about 21 times faster than the Word-native edit
itself, before Word process startup and teardown. A separate read-only Word
open test succeeded in 5,194 ms.

## What worked

For a closed `.docx` on disk, modify the OOXML package directly when the change
can be expressed deterministically. A DOCX is a ZIP package; the main body is
`word/document.xml`. Preserve every package part except the part being edited.

The character-name tool:

1. Reads `word/document.xml` once.
2. Builds paragraph text across Word runs.
3. Finds whole-word names locally.
4. Adds direct bold formatting to complete matching runs.
5. Splits a run only when a match occupies part of that run.
6. Rewrites through a temporary package and atomically replaces the output.

The verifier independently extracts paragraph text, maps every character back
to run formatting, checks every occurrence, and compares visible body text with
the source.

Reproduce the edit and verification with the bundled workspace Python:

```powershell
$python = 'C:\Users\chris\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'

& $python .\docx\tools\bold_docx_names.py `
    .\docx\jane-eyre\source\jane-eyre.docx `
    .\docx\jane-eyre\test\jane-eyre-main-characters-bold.docx

& $python .\docx\tools\verify_bold_names.py `
    .\docx\jane-eyre\test\jane-eyre-main-characters-bold.docx `
    --original .\docx\jane-eyre\source\jane-eyre.docx
```

## What failed or misled us

### Per-occurrence COM loops

Do not cross the PowerShell/COM boundary once per match in a large document.
Exhaustive verification that way ran for more than 120 seconds and was
terminated. Equivalent local OOXML verification took 419 ms.

Use one native Word `Find.Execute`/`Replace All` call per generalized criterion,
not one call per occurrence. Move exhaustive inspection out of COM.

### Saving through Word is not necessarily a local change

Word may update fields, repaginate, or normalize compatibility-mode structures
when a document is opened and saved. In this fixture it replaced the stale TOC
placeholder with hundreds of generated entries and changed pagination-related
content. Both `SaveAs2` and an in-place `Save` exhibited this behavior.

A successful Word save does not prove that only the requested edit occurred.
Always compare semantic text and, when necessary, package parts.

### Timing only the headline operation

Measure these separately:

- process or session startup
- document open
- semantic projection or search
- edit/transform
- save/package write
- verification
- optional render/repagination

Otherwise a fast transformation can look slow because application lifecycle or
verification dominates it.

## Decision rule

Use direct OOXML for closed files when the operation is deterministic and can
be structurally verified: text replacement, localized run formatting,
comments, relationships, and many style or metadata changes.

Use live Word automation when Word must resolve behavior that OOXML alone does
not conveniently model: layout-dependent ranges, native selection semantics,
field calculation, tracked UI state, or an actively edited unsaved document.

For live Word:

- Keep one persistent Word/REPL session instead of starting Word per command.
- Discover documents once and retain stable document handles.
- Batch multiple transforms before save and repagination.
- Use Word-native bulk operations.
- Avoid field updates unless explicitly requested.
- Return compact counts and changed-range identities, not thousands of COM
  objects.
- Verify bulk results from a serialized snapshot when possible.

For large semantic edits, use the hybrid architecture:

```text
DOCX or live Word snapshot
        -> stable text/tree projection with paragraph IDs and hashes
        -> GPT selects or rewrites semantic targets
        -> narrow OOXML or native Word patch
        -> hash/text/format verification
        -> optional render and human preview
```

The projection is for reasoning and target selection. The patch should be as
small and mechanical as possible. Before applying, compare the current source
hash with the hash used to create the projection; on mismatch, resync and
reprompt rather than attempting conflict resolution in the first prototype.

## Reusable artifacts

- `docx/tools/bold_docx_names.py`: fast formatting-only OOXML transform.
- `docx/tools/verify_bold_names.py`: exhaustive structural verification.
- `docx/tools/Set-WordCharacterNamesBold.ps1`: Word-native comparison and
  timing harness; useful as a benchmark, not the preferred closed-file path.
- `docx/jane-eyre/test/benchmark.json`: exact measurements and hashes.
- `docx/jane-eyre/test/jane-eyre-main-characters-bold.docx`: verified output.

## Next optimization targets

1. Generalize the OOXML patcher from a name list to declarative text, style,
   and formatting predicates.
2. Extend story coverage deliberately to headers, footers, notes, comments,
   and text boxes instead of silently assuming `document.xml` is everything.
3. Record changed paragraph IDs and before/after run hashes for preview and
   undo manifests.
4. Add a persistent live-Word host so COM startup is paid once.
5. Benchmark save and repagination policies on an actively edited document.
6. Add package-part and semantic diffs as a standard safety gate.


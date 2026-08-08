# Office Cursor PowerShell modules

This pack is the seed interop layer between a local coding agent and Microsoft
Word. Public commands wrap first-class Word COM and DOCX/OOXML operations in an
interface discoverable with ordinary PowerShell tooling.

Functions are grouped first by visibility and then by Word capability:

```text
OfficeCursor.Word/
├── Public/
│   ├── Documents/       Open-document discovery and document-level commands
│   ├── Content/         Range text and paragraph content transformations
│   ├── Formatting/      Font, paragraph, style, and visual transformations
│   ├── Search/          Native Word Find queries and convenience finders
│   └── Serialization/   Flat OPC and other external representations
└── Private/
    ├── Documents/       Document identity and resolution
    ├── Formatting/      Color and other Word-format value conversion
    ├── Interop/         COM connection, threading, and Word transactions
    ├── Search/          General native Word Find execution
    └── Utility/         Host-independent hashing and small helpers
```

The module loader searches these trees recursively. A new capability bucket can
be added without changing module-loading code; only public exports in the module
manifest need to be declared.

```powershell
Import-Module .\packs\office\modules\OfficeCursor.Word\OfficeCursor.Word.psd1

Get-Command -Module OfficeCursor.Word
Get-Help Set-WordFontColor -Full
```

## General Word search

`Find-WordRange` maps parameters directly onto Word's native `Find` object.
Criteria compose: supplying text and a color means both must match.

```powershell
Find-WordRange -Text 'lecture' -MatchWholeWord
Find-WordRange -FontColor Red
Find-WordRange -Text 'the' -FontColor Blue -MatchWholeWord
Find-WordRange -Text '<[A-Z][a-z]@>' -UseWildcards -Bold $true
Find-WordRange -HighlightColor Yellow
```

Specific finders should normally be thin, memorable wrappers around this
general capability. For example, `Find-WordFontColor -Color Red` delegates to
`Find-WordRange -FontColor Red` rather than implementing another COM loop.

## Composable content mutations

Search results carry document identity, range coordinates, and expected text.
They can flow directly into an optimistic range replacement:

```powershell
Find-WordRange -Text ' — proof copy' |
    Set-WordRangeText -ReplacementText ''
```

Paragraph insertion is a separate general capability. Newlines become manual
line breaks within the inserted Word paragraph:

```powershell
Add-WordParagraph -Text "First line`nSecond line" -Style Normal
```

Both mutations support `-WhatIf`, create one named Word undo record, and return
structured verification results.

Font properties compose with the same range pipeline:

```powershell
Find-WordRange -HighlightColor Yellow |
    Set-WordRangeFont -Bold $true
```

For large text-driven formatting batches, keep the operation inside Word and
group it into one undo record instead of materializing every matching range:

```powershell
Set-WordTextFont `
    -Text Jane,Rochester,Edward,'St. John',Helen,Bertha `
    -Bold $true `
    -MatchWholeWord `
    -UndoName 'Bold main character names'
```

`Set-WordTextFont` uses one native Replace All per criterion, creates one Word
undo record for the batch, and deliberately leaves the document unsaved.

## Example: change red text to blue

```powershell
Get-WordOpenDocument |
    Where-Object Active |
    Set-WordFontColor -FromColor Red -ToColor Blue
```

Preview the operation with PowerShell's standard `-WhatIf` parameter:

```powershell
Set-WordFontColor -FromColor Red -ToColor Blue -WhatIf
```

Inspect and export the document's live Flat OPC XML:

```powershell
$xml = Get-WordDocumentXml
Export-WordDocumentXml
```

Export a file through Word's native PDF renderer without touching the current
interactive document:

```powershell
Export-WordDocumentPdf -InputPath manuscript.docx -OutputPath qa\manuscript.pdf
```

## Command conventions

New commands should follow this precedent:

1. Use an approved PowerShell `Verb-WordNoun` name.
2. Accept `DocumentPath` from the pipeline by its `FullName` alias.
3. Default to Word's active document when no document is supplied.
4. Keep raw COM attachment, constants, and quirks in `Private` functions.
5. Use `SupportsShouldProcess` for mutations.
6. Group mutations into one named Word undo record.
7. Return structured objects; do not format output inside a command.
8. Verify the intended postcondition and important invariants.
9. State the Word story in scope. Initial commands operate on the main body.
10. Include comment-based help and at least one pipeline example.
11. Place the command in the narrowest existing capability bucket. Add a bucket
    when a coherent new area such as comments, revisions, tables, or citations
    first appears; do not create a bucket for a single incidental helper.

The module intentionally starts small. Codex can inspect these commands and add
new wrappers as manuscript-editing needs reveal more of Word's object model.

## Offline DOCX primitives

`OfficeCursor.Docx` operates on closed packages and is separate from the live
COM module:

```powershell
Import-Module .\packs\office\modules\OfficeCursor.Docx\OfficeCursor.Docx.psd1

Get-DocxParagraph -Path manuscript.docx
Edit-DocxParagraph -InputPath manuscript.docx -OutputPath revised.docx -Edit $edits
Export-DocxBodySlice -InputPath manuscript.docx -Slice $slices
Get-DocxSchema
Get-DocxSchema -Name ParagraphEdit -Path RunFormatting
```

Its public commands expose package mechanisms, not editorial workflows. See
[`docs/offline-docx-api.md`](docs/offline-docx-api.md) for the API and the
rules deliberately retained in the monastic profile.

Project-specific compositions live outside the core module under
[`examples/office`](../../examples/office). They may depend on public commands,
but never on private functions. The full dependency and promotion model is
documented in [`docs/architecture.md`](docs/architecture.md).

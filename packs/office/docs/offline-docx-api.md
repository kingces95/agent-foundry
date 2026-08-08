# Offline DOCX API: harvested mechanisms

`OfficeCursor.Docx` is the closed-file counterpart to the live COM module. Its
surface is intentionally smaller than the workflows that revealed it.

## Public capabilities

### `Get-DocxParagraph`

Projects each main-body paragraph into a structured object with its paragraph
index, direct body-child index when applicable, visible text, normalized text,
effective dominant font color, and character count. Effective color follows
direct run formatting, character styles, and paragraph styles.

### `Edit-DocxParagraph`

Applies a batch of `InsertBefore`, `InsertAfter`, and `Delete` operations against
paragraph indexes from the projection. An insertion creates a new `w:p` before
or after the reference; it does not splice text or newline characters into the
reference paragraph. By default it copies the reference paragraph's `w:pPr`,
then applies requested run and paragraph overrides.

```powershell
$edits = @(
    @{
        Action = 'InsertBefore'
        Index = 42
        Text = 'Review'
        RunFormatting = @{ Color = 'FF0000'; Bold = $true }
        ParagraphFormatting = @{ Alignment = 'Center'; SpaceAfterPoints = 6 }
    }
    @{ Action = 'Delete'; Index = 99 }
)
Edit-DocxParagraph -InputPath input.docx -OutputPath output.docx -Edit $edits
```

The initial human-facing formatting family is:

| Object | Properties |
| --- | --- |
| `RunFormatting` | `FontName`, `FontSizePoints`, `Bold`, `Italic`, `Underline`, `Color`, `HighlightColor`, `StrikeThrough`, `VerticalPosition` |
| `ParagraphFormatting` | `Style`, `Alignment`, `SpaceBeforePoints`, `SpaceAfterPoints`, `LineSpacingRule`, `LineSpacingMultiple`, `LineSpacingPoints`, `LeftIndentPoints`, `RightIndentPoints`, `SpecialIndent`, `SpecialIndentByPoints`, `KeepWithNext`, `KeepLines`, `PageBreakBefore` |

Enums use readable strings such as `Single`, `Justify`, `FirstLine`, and
`Superscript`. Measurements are points. Properties are tri-state where Word
allows it: omission means inherit, `$true` enables, and `$false` explicitly
disables. Property names and enum values use the canonical casing shown by the
schema. PowerShell's standard `Test-Json` command rejects unknown keys,
unsupported enum values, invalid ranges, and incompatible combinations before
writing a temporary plan. The Python engine performs the OOXML mutation and
package checks.

Line-spacing values are unambiguous:

- `Single`, `OneAndHalf`, and `Double` need no companion value;
- `Multiple` requires `LineSpacingMultiple`;
- `Exactly` and `AtLeast` require `LineSpacingPoints`.

Likewise, `SpecialIndent` accepts `None`, `FirstLine`, or `Hanging`; the latter
two require `SpecialIndentByPoints`.

### `Get-DocxSchema`

Lists the module schema catalog or projects a selected Draft 2020-12 JSON
Schema into records that a user, script, or GPT can inspect directly:

```powershell
Get-DocxSchema
Get-DocxSchema -Name ParagraphEdit
Get-DocxSchema -Name ParagraphEdit -Path RunFormatting
Get-DocxSchema -Name ParagraphEdit -Path ParagraphFormatting.Alignment
Get-DocxSchema -Name ParagraphEdit -Path 'ParagraphFormatting.LineSpacing*'
Get-DocxSchema -Name ParagraphEdit -AsJson
```

`Schema/catalog.json` registers reusable structured types and maps each one to
the command parameters that consume it. `ParagraphEdit` is the first entry and
resolves to `Schema/paragraph-edit.schema.json`, the single source of truth for
property names, types, enum values, ranges, descriptions, action applicability,
and conditional requirements. Both discovery and validation resolve the schema
through the catalog. OOXML mappings stay private because they describe execution
rather than the caller contract.

### `Export-DocxBodySlice`

Exports inclusive/exclusive ranges of direct `w:body` children as complete
DOCX packages. It carries forward the source section properties and verifies
the canonical output body against each requested source slice.

```powershell
$slices = @(
    @{ StartIndex = 0; EndIndex = 120; OutputPath = 'part-001.docx' }
    @{ StartIndex = 120; EndIndex = 245; OutputPath = 'part-002.docx' }
)
Export-DocxBodySlice -InputPath input.docx -Slice $slices
```

## What deliberately stayed bespoke

The monastic workflow discovered these primitives, but did not donate its
business rules to the module. These remain under
`examples/office/monastic-manuscript`:

- the meanings of EE0000 and FF0000;
- recognition and wording of red-section markers;
- paragraph alignment and confidence policy;
- Audio:/WAudio: track boundaries;
- Archive #: lookup, tape labels, and output filename conventions;
- decisions about ignorable separator paragraphs.

The test for promotion is: can the command describe an ability of DOCX/OOXML
without mentioning the request that exposed it? If not, it remains bespoke.

## Repetition result

The marker workflow was run four times through the extracted paragraph-edit
primitive. Every run produced a byte-identical package with 118 section pairs,
236 bold-red insertions, two legacy-marker deletions, 6,053 exact paragraph
matches, and unchanged non-marker text.

The 130-part audio split was run three times through the body-slice exporter.
All runs produced identical filenames and byte-identical corresponding
packages; all 390 outputs passed canonical body verification.

After the formatting schema was expanded, the full 118-section workflow was
run twice more. Both packages were byte-identical, retained all 236 bold-red
markers, and passed the unchanged-content verifier.

# PowerShell architecture: primitives, capabilities, and bespoke workflows

Office Cursor has two mechanism modules beneath bespoke workflows:

```text
Bespoke editing workflows
       |                 |
       v                 v
OfficeCursor.Word   OfficeCursor.Docx
       |                 |
       v                 v
Word COM model      ZIP/OOXML package
```

## 1. Private primitives

`OfficeCursor.Word/Private` contains mechanical implementation details:

- connect to the running Word application;
- resolve a document identity;
- execute Word's native Find engine;
- convert Word enum and formatting values;
- create an undo transaction;
- hash and normalize host data.

Private functions are not an API. They may change whenever the public commands
need a better implementation. Code outside the core module must not call them.

## 2. Public capabilities

`OfficeCursor.Word/Public` exposes stable, composable Word operations:

- discover documents;
- search ranges by text and formatting;
- inspect and export a document;
- perform guarded, undoable mutations.

Public commands contain no editing-team vocabulary. Parameters express the
bespoke part of a request through general Word concepts. For example:

```powershell
Find-WordRange -Style 'Block Quotation' -Italic $false
Set-WordFontColor -FromColor Red -ToColor Blue
Find-WordRange -Text 'proof copy' | Set-WordRangeText -ReplacementText ''
```

A public command may compose several private primitives. It must provide help,
structured output, pipeline document selection, and verification appropriate to
its risk.

`OfficeCursor.Docx` follows the same public/private rule, but its public surface
describes package abilities rather than editorial outcomes: project paragraphs,
apply indexed paragraph edits, and export body slices. Alignment policy,
boundary recognition, marker vocabulary, and filename rules are not core APIs.

Complex input objects are reusable types, not command-specific mini-APIs.
`OfficeCursor.Docx/Schema/catalog.json` maps each registered type to the command
parameters that consume it. `Get-DocxSchema` lists and inspects that catalog;
ordinary scalar parameters remain discoverable through `Get-Command` and
`Get-Help`.

## 3. Bespoke workflows

`examples/office/<project>` is the agent's workshop. A project may encode:

- the styles and terminology used by one editing team;
- manuscript-specific lint rules;
- repeated transformations and editorial checks;
- project defaults and exceptions.

Bespoke scripts import and compose public commands. They must not automate COM
or edit OOXML directly when a public primitive already exists, and must not
reach into either module's private scope. If a workflow needs an unavailable
mechanism, add the smallest general capability that expresses the tool's
ability—not the business request—then use it from the workflow.

## Promotion rule

```text
One manuscript needs a workflow
    -> add a Bespoke command

The workflow needs an unavailable Word operation
    -> add a Public capability backed by Private primitives

Several profiles reuse the same workflow
    -> promote it into the core module
```

Repetition alone is not sufficient for promotion. A candidate must be useful
without carrying vocabulary from the request that discovered it.

Team-specific names remain bespoke even when the underlying operation becomes
general. `Format-LectureQuotation` belongs to a manuscript profile;
`Set-WordParagraphStyle` belongs to the core module.

## Verification rule

Live mutations follow the transaction shape:

```text
resolve target -> inspect precondition -> ShouldProcess -> one Word undo record
-> verify intended result -> return a structured report
```

The initial module limits searches and mutations to Word's main-text story.
Commands must state when they expand into headers, footnotes, comments, text
boxes, or other stories.

Offline mutations use a copy-and-verify shape:

```text
read source package -> construct an indexed plan -> write a new package
-> verify changed parts and structural postconditions -> return a report
```

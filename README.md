# Office Cursor

Office Cursor is an experiment in giving local coding agents a discoverable,
scriptable interface to the live Microsoft Word object model.

The first usable artifacts are two deliberately small PowerShell modules:

- [`OfficeCursor.Word`](powershell/OfficeCursor.Word) controls a running Word
  instance through COM.
- [`OfficeCursor.Docx`](powershell/OfficeCursor.Docx) inspects and transforms
  closed DOCX packages without starting Word.

They are precedents—not complete abstractions. Codex can inspect their public
commands, private helpers, help text, and conventions, then extend the library
when a manuscript-editing task reveals another reusable capability.

```powershell
Import-Module .\powershell\OfficeCursor.Word\OfficeCursor.Word.psd1

Get-Command -Module OfficeCursor.Word
Get-WordOpenDocument
Set-WordFontColor -FromColor Red -ToColor Blue -WhatIf

Import-Module .\powershell\OfficeCursor.Docx\OfficeCursor.Docx.psd1
Get-DocxParagraph -Path manuscript.docx
```

See [`powershell/README.md`](powershell/README.md) for the current command set
and the conventions new commands should follow. See
[`docs/architecture.md`](docs/architecture.md) for the boundary between private
COM primitives, public Word capabilities, and bespoke editing-team workflows.

The first project-specific seed is
[`powershell/Bespoke/MonasticManuscript`](powershell/Bespoke/MonasticManuscript).

Large-document experiments live under [`docx`](docx). The first fixture projects
the complete Jane Eyre DOCX into a hashed paragraph ledger and searchable
chapter Markdown files so Git and Codex can treat a book like a source tree.
The measured editing results and operational guidance for future agents are in
[`docs/large-docx-editing-lessons.md`](docs/large-docx-editing-lessons.md).
The conservative offline API and its promotion test are documented in
[`docs/offline-docx-api.md`](docs/offline-docx-api.md).

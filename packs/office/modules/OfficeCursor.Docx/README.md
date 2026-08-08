# OfficeCursor.Docx

This module exposes a deliberately small set of offline DOCX/OOXML mechanisms:

- `Get-DocxParagraph` projects text, indexes, and effective formatting;
- `Edit-DocxParagraph` applies validated batch insert/delete edits, including
  common UI-facing run and paragraph formatting, to a new package;
- `Export-DocxBodySlice` turns body ranges into verified DOCX packages;
- `Get-DocxSchema` lists reusable structured-data contracts and inspects the
  same standard JSON Schemas used for validation.

```powershell
Import-Module .\OfficeCursor.Docx.psd1
Get-Command -Module OfficeCursor.Docx
Get-Help Edit-DocxParagraph -Full
Get-DocxSchema
Get-DocxSchema -Name ParagraphEdit -Path ParagraphFormatting
```

The module requires PowerShell 7.4 or newer. `Schema/catalog.json` registers
complex input types and their consuming command parameters. Validation resolves
the registered schema and uses `Test-Json` rather than a parallel hand-written
property list.

Public commands describe package abilities. Request-specific interpretation and
planning belongs under `examples/office`. See
[`../../docs/offline-docx-api.md`](../../docs/offline-docx-api.md).

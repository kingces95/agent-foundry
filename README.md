# Agent Foundry

Agent Foundry is a seed repository for teaching local coding agents to operate
the software people already use, grow project-specific workflows from real
requests, and harvest the reusable mechanisms back into public capability packs.

```text
natural-language request
        -> bespoke example workflow
        -> application-native operation
        -> verified result
        -> reusable capability harvested into a pack
```

The repository has three layers:

- [`foundry`](foundry) defines shared pack contracts and contribution rules.
- [`packs`](packs) contains reusable, discoverable application capabilities.
- [`examples`](examples) contains concrete projects where new capabilities are
  discovered and exercised.

## First pack: Office Cursor

[`packs/office`](packs/office) gives local agents a scriptable interface to
Microsoft Word and DOCX files. Its two deliberately small PowerShell modules
are precedents rather than exhaustive wrappers:

- `OfficeCursor.Word` controls a running Word instance through COM.
- `OfficeCursor.Docx` inspects and transforms closed DOCX packages through
  OOXML without starting Word.

```powershell
Import-Module .\packs\office\modules\OfficeCursor.Word\OfficeCursor.Word.psd1
Get-WordOpenDocument
Set-WordFontColor -FromColor Red -ToColor Blue -WhatIf

Import-Module .\packs\office\modules\OfficeCursor.Docx\OfficeCursor.Docx.psd1
Get-DocxParagraph -Path manuscript.docx
Get-DocxSchema
```

The [`monastic-manuscript`](examples/office/monastic-manuscript) example keeps
one editing team's language and policies outside the public modules. The
[`jane-eyre`](examples/office/jane-eyre) example explores treating a large Word
document like a searchable source tree.

See [`AGENTS.md`](AGENTS.md) for the harvesting discipline and
[`packs/office/AGENTS.md`](packs/office/AGENTS.md) for Office-specific safety
and API conventions.

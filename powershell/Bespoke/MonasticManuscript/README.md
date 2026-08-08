# Monastic Manuscript profile

This is the seed editing universe for a team compiling a manuscript from
translations of lectures. It demonstrates how a project can give semantic names
to Word styles and compose general Office Cursor commands without touching COM.

First adapt `profile.psd1` to the styles in the team's Word template. Then audit
an open manuscript:

```powershell
.\Test-ManuscriptStyle.ps1
```

Find content by its semantic role:

```powershell
.\Get-ManuscriptStyle.ps1 -Role BlockQuotation
```

Append a translated passage using the configured Translation style:

```powershell
.\Add-ManuscriptTranslation.ps1 -Language Tibetan -Lines @(
    'First translated line',
    'Second translated line'
)
```

New commands in this directory should speak the team's language—for example,
`Format-LectureQuotation`, `Find-UnresolvedAttribution`, or
`Test-TranslatorNote`—while applying mutations through public Office Cursor
capabilities. Profile-owned planners may encode this manuscript's semantics.

## Mark sections from a color-coded source

Add-ManuscriptRedSectionMarkers.ps1 aligns a color-coded source DOCX with a
checked transcript. It treats EE0000 as section-level red, allows FF0000
timestamp and Tibetan annotations inside a section, and writes paired Start
Red Section / End Red Section markers to a new file.

The alignment and color interpretation remain bespoke. The script emits a
batch of indexed insert/delete edits and delegates package mutation to
`Edit-DocxParagraph`.

```powershell
.\Add-ManuscriptRedSectionMarkers.ps1 `
    -ColorSourcePath 'VPI MSH this one.docx' `
    -TranscriptPath 'VPI Checked Transcript working file.docx'
```

## Split the marked transcript into audio tracks

Split-ManuscriptAudioTrack.ps1 creates one DOCX for every Audio:/WAudio: header.
Names begin with a zero-padded source ordinal, then the original tape/side label
and archive number. Source anomalies remain literal and the ordinal prevents
collisions while preserving manuscript order.

The profile planner owns those boundary and filename rules. It delegates only
the resulting body ranges to `Export-DocxBodySlice`.

```powershell
.\Split-ManuscriptAudioTrack.ps1 `
    -InputPath 'VPI Checked Transcript - Red Sections Marked.docx' `
    -OutputDirectory 'Audio Tracks'
```

Transfer editorial emphasis from a raw source into a main manuscript:

```powershell
.\Copy-ManuscriptHighlightEmphasis.ps1 `
    -SourceDocumentPath $raw.FullName `
    -TargetDocumentPath $main.FullName `
    -HighlightColor Yellow `
    -WhatIf
```

The workflow composes `Find-WordRange -HighlightColor`, exact target text
search, and `Set-WordRangeFont -Bold`; it contains no direct COM automation.

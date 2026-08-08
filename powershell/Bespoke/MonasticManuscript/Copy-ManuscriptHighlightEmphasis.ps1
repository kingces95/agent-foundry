<#
.SYNOPSIS
Copies highlighted source passages into bold emphasis in a target manuscript.

.DESCRIPTION
Finds ranges with an exact highlight color in a source document, finds exact
case-sensitive text matches in a target document, and applies bold formatting
through the public OfficeCursor.Word range-font command.

.EXAMPLE
.\Copy-ManuscriptHighlightEmphasis.ps1 `
    -SourceDocumentPath 'https://example/source.docx' `
    -TargetDocumentPath 'https://example/manuscript.docx' `
    -HighlightColor Yellow `
    -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [string]$SourceDocumentPath,

    [Parameter(Mandatory)]
    [string]$TargetDocumentPath,

    [object]$HighlightColor = 'Yellow',

    [bool]$Bold = $true
)

$modulePath = Join-Path $PSScriptRoot '..\..\OfficeCursor.Word\OfficeCursor.Word.psd1'
Import-Module $modulePath -ErrorAction Stop

$sourceRanges = @(Find-WordRange `
    -DocumentPath $SourceDocumentPath `
    -HighlightColor $HighlightColor)

$targetRanges = [Collections.Generic.List[object]]::new()
$unmatchedTexts = [Collections.Generic.List[string]]::new()

foreach ($sourceRange in $sourceRanges) {
    if ([string]::IsNullOrEmpty([string]$sourceRange.Text)) {
        continue
    }

    $matches = @(Find-WordRange `
        -DocumentPath $TargetDocumentPath `
        -Text ([string]$sourceRange.Text) `
        -MatchCase)

    if ($matches.Count -eq 0) {
        $unmatchedTexts.Add([string]$sourceRange.Text)
        continue
    }

    foreach ($match in $matches) {
        $targetRanges.Add($match)
    }
}

# A repeated highlighted source passage may discover the same target range more
# than once. Mutate each target coordinate only once.
$uniqueTargetRanges = @($targetRanges |
    Sort-Object Document, Start, End -Unique)

$changes = @()
if ($uniqueTargetRanges.Count -gt 0) {
    $changes = @($uniqueTargetRanges |
        Set-WordRangeFont -Bold $Bold -WhatIf:$WhatIfPreference)
}

[pscustomobject]@{
    PSTypeName       = 'OfficeCursor.Word.Bespoke.HighlightEmphasisTransfer'
    SourceDocument   = $SourceDocumentPath
    TargetDocument   = $TargetDocumentPath
    HighlightColor   = [string]$HighlightColor
    SourceRanges     = $sourceRanges.Count
    TargetRanges     = $uniqueTargetRanges.Count
    UnmatchedTexts   = @($unmatchedTexts)
    AppliedRanges    = @($changes | Where-Object Applied).Count
    VerifiedRanges   = @($changes | Where-Object Verified).Count
    Verified         = $unmatchedTexts.Count -eq 0 -and
                       $uniqueTargetRanges.Count -gt 0 -and
                       @($changes | Where-Object { -not $_.Verified }).Count -eq 0
    Changes          = $changes
}


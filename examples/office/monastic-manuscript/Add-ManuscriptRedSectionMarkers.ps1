<#
.SYNOPSIS
Adds the editing team's red-section markers to a checked transcript.
.DESCRIPTION
All manuscript policy lives here and in this profile's planner: EE0000 is
section red, FF0000 annotations are transparent, and the team's marker aliases
are normalized. The resulting indexed insert/delete plan is applied through the
general OfficeCursor.Docx paragraph-edit capability.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][string]$ColorSourcePath,
    [Parameter(Mandatory)][string]$TranscriptPath,
    [string]$OutputPath,
    [string]$PythonPath,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$source = Get-Item -LiteralPath $ColorSourcePath -ErrorAction Stop
$transcript = Get-Item -LiteralPath $TranscriptPath -ErrorAction Stop
if (-not $OutputPath) {
    $OutputPath = Join-Path $transcript.DirectoryName "$($transcript.BaseName) - Red Sections Marked.docx"
}
if (-not $PythonPath) {
    $bundled = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
    if (Test-Path -LiteralPath $bundled) { $PythonPath = $bundled }
    else { $PythonPath = (Get-Command python -ErrorAction Stop).Source }
}

$module = Join-Path $PSScriptRoot '..\..\..\packs\office\modules\OfficeCursor.Docx\OfficeCursor.Docx.psd1'
Import-Module $module -Force
$planner = Join-Path $PSScriptRoot 'tools\plan_monastic_markers.py'
$planJson = (& $PythonPath $planner $source.FullName $transcript.FullName) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) { throw "Manuscript marker planning failed with exit code $LASTEXITCODE." }
$plan = $planJson | ConvertFrom-Json
if (@($plan.issues).Count) { throw "The manuscript marker plan has $(@($plan.issues).Count) issue(s)." }

$markerText = @(
    'Begin Red Section', 'Start Red Section', 'End Red Section',
    'Red section begins', 'Red section ends'
)
$existing = Get-DocxParagraph -Path $transcript.FullName -PythonPath $PythonPath |
    Where-Object { $markerText -contains $_.NormalizedText }
$edits = [Collections.Generic.List[object]]::new()
foreach ($section in $plan.plans) {
    $edits.Add([pscustomobject]@{
        Action = 'InsertBefore'; Index = [int]$section.target_start
        Text = 'Start Red Section'
        RunFormatting = @{ Color = 'FF0000'; Bold = $true }
    })
    $edits.Add([pscustomobject]@{
        Action = 'InsertAfter'; Index = [int]$section.target_end
        Text = 'End Red Section'
        RunFormatting = @{ Color = 'FF0000'; Bold = $true }
    })
}
foreach ($paragraph in $existing) {
    $edits.Add([pscustomobject]@{ Action = 'Delete'; Index = $paragraph.Index })
}

$editParameters = @{
    InputPath = $transcript.FullName; OutputPath = $OutputPath; Edit = $edits
    PythonPath = $PythonPath; Force = $Force; WhatIf = $WhatIfPreference
}
$editResult = Edit-DocxParagraph @editParameters
if ($null -eq $editResult) { return }

$verify = Join-Path $PSScriptRoot 'tools\verify_monastic_markers.py'
$verifyJson = (& $PythonPath $verify $transcript.FullName $editResult.Output $plan.section_count) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) { throw "Manuscript marker verification failed with exit code $LASTEXITCODE." }
$verified = $verifyJson | ConvertFrom-Json

[pscustomobject]@{
    PSTypeName             = 'OfficeCursor.Word.ManuscriptRedSections'
    ColorSource            = $source.FullName
    Transcript             = $transcript.FullName
    Output                 = $editResult.Output
    Sections               = [int]$plan.section_count
    MarkersInserted        = [int]$editResult.InsertedCount
    ExistingMarkersRemoved = [int]$editResult.DeletedCount
    AlignmentRatio         = [double]$plan.alignment_ratio
    ExactParagraphMatches  = [int]$plan.exact_paragraph_matches
    NonMarkerTextUnchanged = [bool]$verified.non_marker_paragraph_text_equal
    RedBoldMarkers         = [int]$verified.red_bold_markers
    Verified               = [bool]$verified.valid
}

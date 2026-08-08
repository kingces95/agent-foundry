<#
.SYNOPSIS
Splits a combined manuscript into one ordered DOCX per Audio track header.
.DESCRIPTION
The profile planner owns the Audio:/WAudio:, Archive #:, filename, and empty
separator rules. It emits body ranges; OfficeCursor.Docx exports and verifies
those ranges as complete packages.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][string]$InputPath,
    [string]$OutputDirectory,
    [string]$PythonPath,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$inputFile = Get-Item -LiteralPath $InputPath -ErrorAction Stop
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $inputFile.DirectoryName "$($inputFile.BaseName) - Audio Tracks"
}
if (-not $PythonPath) {
    $bundled = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
    if (Test-Path -LiteralPath $bundled) { $PythonPath = $bundled }
    else { $PythonPath = (Get-Command python -ErrorAction Stop).Source }
}

$planner = Join-Path $PSScriptRoot 'tools\plan_monastic_audio_tracks.py'
$planJson = (& $PythonPath $planner $inputFile.FullName) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) { throw "Audio-track planning failed with exit code $LASTEXITCODE." }
$plan = $planJson | ConvertFrom-Json
$slices = foreach ($track in $plan.tracks) {
    [pscustomobject]@{
        StartIndex = [int]$track.start_child
        EndIndex   = [int]$track.end_child
        OutputPath = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) $track.filename
    }
}

$module = Join-Path $PSScriptRoot '..\..\..\packs\office\modules\OfficeCursor.Docx\OfficeCursor.Docx.psd1'
Import-Module $module -Force
$exportParameters = @{
    InputPath = $inputFile.FullName; Slice = $slices; PythonPath = $PythonPath
    Force = $Force; WhatIf = $WhatIfPreference
}
$outputs = @(Export-DocxBodySlice @exportParameters)
if ($WhatIfPreference) { return }

$tracks = for ($index = 0; $index -lt $outputs.Count; $index++) {
    [pscustomobject]@{
        Ordinal   = [int]$plan.tracks[$index].ordinal
        Header    = [string]$plan.tracks[$index].header
        Archive   = [string]$plan.tracks[$index].archive
        Path      = $outputs[$index].Output
        BodySha256 = $outputs[$index].BodySha256
        Verified  = $outputs[$index].Verified
    }
}
[pscustomobject]@{
    PSTypeName      = 'OfficeCursor.Word.ManuscriptAudioTrackSplit'
    Input           = $inputFile.FullName
    OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
    TrackCount      = $tracks.Count
    VerifiedCount   = @($tracks | Where-Object Verified).Count
    Tracks          = $tracks
}

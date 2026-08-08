<#
.SYNOPSIS
Reports which configured manuscript style roles occur in an open Word document.

.EXAMPLE
.\Test-ManuscriptStyle.ps1

.EXAMPLE
Get-WordOpenDocument | Where-Object Active | .\Test-ManuscriptStyle.ps1
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('FullName')]
    [string]$DocumentPath,

    [string]$ProfilePath = (Join-Path $PSScriptRoot 'profile.psd1')
)

begin {
    $modulePath = Join-Path $PSScriptRoot '..\..\..\packs\office\modules\OfficeCursor.Word\OfficeCursor.Word.psd1'
    Import-Module $modulePath -ErrorAction Stop
    $profile = Import-PowerShellDataFile -LiteralPath $ProfilePath
}

process {
    foreach ($role in @($profile.Styles.Keys | Sort-Object)) {
        $styleName = [string]$profile.Styles[$role]
        try {
            $matches = @(Find-WordRange -DocumentPath $DocumentPath -Style $styleName)
            [pscustomobject]@{
                PSTypeName = 'OfficeCursor.Word.Bespoke.StyleAudit'
                Profile    = [string]$profile.Name
                Role       = [string]$role
                Style      = $styleName
                Available  = $true
                MatchCount = $matches.Count
                Error      = $null
            }
        }
        catch {
            [pscustomobject]@{
                PSTypeName = 'OfficeCursor.Word.Bespoke.StyleAudit'
                Profile    = [string]$profile.Name
                Role       = [string]$role
                Style      = $styleName
                Available  = $false
                MatchCount = 0
                Error      = $_.Exception.Message
            }
        }
    }
}

<#
.SYNOPSIS
Finds ranges assigned to a semantic style role in the manuscript profile.

.EXAMPLE
.\Get-ManuscriptStyle.ps1 -Role BlockQuotation

.EXAMPLE
Get-WordOpenDocument | Where-Object Active |
    .\Get-ManuscriptStyle.ps1 -Role LectureTitle
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Role,

    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('FullName')]
    [string]$DocumentPath,

    [string]$ProfilePath = (Join-Path $PSScriptRoot 'profile.psd1')
)

begin {
    $modulePath = Join-Path $PSScriptRoot '..\..\OfficeCursor.Word\OfficeCursor.Word.psd1'
    Import-Module $modulePath -ErrorAction Stop

    $profile = Import-PowerShellDataFile -LiteralPath $ProfilePath
    if (-not $profile.Styles.ContainsKey($Role)) {
        $knownRoles = @($profile.Styles.Keys | Sort-Object) -join ', '
        throw "Unknown manuscript style role '$Role'. Known roles: $knownRoles"
    }

    $styleName = [string]$profile.Styles[$Role]
}

process {
    Find-WordRange -DocumentPath $DocumentPath -Style $styleName |
        Select-Object @{ Name = 'Role'; Expression = { $Role } }, *
}


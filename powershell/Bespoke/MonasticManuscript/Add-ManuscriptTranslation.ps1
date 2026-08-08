<#
.SYNOPSIS
Appends a translated passage using the manuscript profile's Translation style.

.EXAMPLE
.\Add-ManuscriptTranslation.ps1 -Language Tibetan -Lines @(
    'First translated line',
    'Second translated line'
)
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [string]$Language,

    [Parameter(Mandatory)]
    [string[]]$Lines,

    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('FullName')]
    [string]$DocumentPath,

    [string]$ProfilePath = (Join-Path $PSScriptRoot 'profile.psd1')
)

process {
    $modulePath = Join-Path $PSScriptRoot '..\..\OfficeCursor.Word\OfficeCursor.Word.psd1'
    Import-Module $modulePath -ErrorAction Stop
    $profile = Import-PowerShellDataFile -LiteralPath $ProfilePath
    $styleName = [string]$profile.Styles.Translation
    $translationText = $Lines -join [string][char]11

    $parameters = @{
        DocumentPath = $DocumentPath
        Text         = $translationText
        Style        = $styleName
    }
    if ($WhatIfPreference) {
        $parameters.WhatIf = $true
    }

    Add-WordParagraph @parameters |
        Select-Object @{ Name = 'Language'; Expression = { $Language } },
                      @{ Name = 'Role'; Expression = { 'Translation' } }, *
}


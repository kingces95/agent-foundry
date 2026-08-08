[CmdletBinding()]
param()

$modulePath = Join-Path $PSScriptRoot 'powershell\OfficeCursor.Word\OfficeCursor.Word.psd1'
Import-Module $modulePath -Force
OfficeCursor.Word\Get-WordOpenDocument


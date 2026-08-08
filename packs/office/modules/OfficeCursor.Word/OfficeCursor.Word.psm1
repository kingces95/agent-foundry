$privateFunctions = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Recurse -File -Filter '*.ps1' |
    Sort-Object FullName
$publicFunctions = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Recurse -File -Filter '*.ps1' |
    Sort-Object FullName

foreach ($functionFile in @($privateFunctions) + @($publicFunctions)) {
    . $functionFile.FullName
}

Export-ModuleMember -Function $publicFunctions.BaseName

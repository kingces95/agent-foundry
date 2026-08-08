function Get-DocxSchemaCatalogData {
    [CmdletBinding()]
    param([switch]$Raw)

    $moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $catalogPath = Join-Path $moduleRoot 'Schema/catalog.json'
    $catalogJson = Get-Content -LiteralPath $catalogPath -Raw -ErrorAction Stop
    if ($Raw) { return $catalogJson }
    return $catalogJson | ConvertFrom-Json -Depth 100
}

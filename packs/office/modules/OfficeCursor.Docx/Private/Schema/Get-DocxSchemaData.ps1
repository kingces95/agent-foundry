function Get-DocxSchemaData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Raw
    )

    $catalog = Get-DocxSchemaCatalogData
    $registration = $catalog.schemas.PSObject.Properties |
        Where-Object Name -IEQ $Name |
        Select-Object -First 1
    if (-not $registration) {
        $available = @($catalog.schemas.PSObject.Properties.Name) -join ', '
        throw "DOCX schema '$Name' is not registered. Available schemas: $available."
    }
    $moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $schemaPath = Join-Path $moduleRoot "Schema/$($registration.Value.file)"
    $schemaJson = Get-Content -LiteralPath $schemaPath -Raw -ErrorAction Stop
    if ($Raw) { return $schemaJson }
    return $schemaJson | ConvertFrom-Json -Depth 100
}

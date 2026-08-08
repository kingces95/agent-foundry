function ConvertTo-DocxParagraphEditPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Edit)

    $schemaJson = Get-DocxSchemaData -Name ParagraphEdit -Raw
    $planJson = $Edit | ConvertTo-Json -Depth 20 -AsArray
    try {
        $valid = Test-Json -Json $planJson -Schema $schemaJson -ErrorAction Stop
    }
    catch {
        throw "Invalid DOCX paragraph edit plan. $($_.Exception.Message)"
    }
    if (-not $valid) {
        throw 'Invalid DOCX paragraph edit plan.'
    }
    return $planJson | ConvertFrom-Json -Depth 20
}

function Edit-DocxParagraph {
    <#
    .SYNOPSIS
    Applies indexed paragraph edits to a copy of a DOCX.
    .DESCRIPTION
    Accepts a batch of InsertBefore, InsertAfter, and Delete edit objects. Each
    edit addresses a paragraph index returned by Get-DocxParagraph. The source
    package is never modified; only word/document.xml may differ in the output.
    Insertions accept validated RunFormatting and ParagraphFormatting objects.
    An omitted formatting property inherits; explicit false disables a boolean
    property. Measurements use points.
    .EXAMPLE
    $edit = @{
        Action = 'InsertBefore'
        Index = 42
        Text = 'Review this passage'
        RunFormatting = @{ Bold = $true; Color = 'FF0000' }
        ParagraphFormatting = @{
            Alignment = 'Center'
            SpaceAfterPoints = 6
            SpecialIndent = 'FirstLine'
            SpecialIndentByPoints = 18
        }
    }
    Edit-DocxParagraph -InputPath input.docx -OutputPath output.docx -Edit $edit
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][object[]]$Edit,
        [string]$PythonPath,
        [switch]$Force
    )

    $normalizedEdits = @(ConvertTo-DocxParagraphEditPlan -Edit $Edit)
    $inputFile = (Get-Item -LiteralPath $InputPath -ErrorAction Stop).FullName
    $output = [IO.Path]::GetFullPath($OutputPath)
    if ((Test-Path -LiteralPath $output) -and -not $Force) {
        throw "Output already exists: $output. Use -Force to replace it."
    }
    if (-not $PSCmdlet.ShouldProcess($output, "Apply $($normalizedEdits.Count) indexed paragraph edits to a copy of $inputFile")) {
        return
    }

    $editFile = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($editFile, ($normalizedEdits | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        $arguments = @('--input', $inputFile, '--output', $output, '--edits-json', $editFile)
        if ($Force) { $arguments += '--force' }
        $result = Invoke-DocxEngine -Command 'edit-paragraphs' -ArgumentList $arguments -PythonPath $PythonPath
    }
    finally {
        Remove-Item -LiteralPath $editFile -Force -ErrorAction SilentlyContinue
    }
    [pscustomobject]@{
        PSTypeName    = 'OfficeCursor.Docx.ParagraphEditResult'
        Input         = $inputFile
        Output        = $output
        EditCount     = [int]$result.edit_count
        InsertedCount = [int]$result.inserted_count
        DeletedCount  = [int]$result.deleted_count
        ChangedParts  = @($result.changed_parts)
        Verified      = [bool]$result.verified
    }
}

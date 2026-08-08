function Set-WordTextFont {
    <#
    .SYNOPSIS
    Applies font formatting to text with Word's native bulk Find/Replace.

    .DESCRIPTION
    Executes one in-process Word Replace All operation per supplied text
    criterion and groups the complete batch into one custom Word undo record.
    This avoids returning or mutating thousands of individual COM ranges.

    The active document is used unless DocumentPath identifies another open
    document. The command does not save the document.

    .EXAMPLE
    Set-WordTextFont -Text Jane,Rochester -Bold $true -MatchWholeWord

    .EXAMPLE
    Set-WordTextFont -DocumentPath C:\Manuscript.docx `
        -Text 'draft' -Italic $true -UndoName 'Italicize draft labels'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Text,

        [Nullable[bool]]$Bold,

        [Nullable[bool]]$Italic,

        [string]$FontName,

        [Nullable[float]]$FontSize,

        [object]$FontColor,

        [switch]$MatchCase,

        [switch]$MatchWholeWord,

        [switch]$UseWildcards,

        [string]$DocumentPath,

        [string]$UndoName = 'Office Cursor: set text font'
    )

    $propertyNames = @('Bold', 'Italic', 'FontName', 'FontSize', 'FontColor')
    $requestedProperties = @($propertyNames | Where-Object { $PSBoundParameters.ContainsKey($_) })
    if ($requestedProperties.Count -eq 0) {
        throw 'Specify at least one font property to set.'
    }

    $criteria = @($Text | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($criteria.Count -eq 0) {
        throw 'Supply at least one nonempty text criterion.'
    }

    $word = Connect-WordApplication
    $document = Resolve-WordDocument -Application $word -DocumentPath $DocumentPath
    if ([bool]$document.ReadOnly) {
        throw "The target Word document is read-only: $($document.FullName)"
    }

    $setBold = $PSBoundParameters.ContainsKey('Bold')
    $setItalic = $PSBoundParameters.ContainsKey('Italic')
    $setFontName = $PSBoundParameters.ContainsKey('FontName')
    $setFontSize = $PSBoundParameters.ContainsKey('FontSize')
    $setFontColor = $PSBoundParameters.ContainsKey('FontColor')
    $targetColor = if ($setFontColor) { ConvertTo-WordColor -Color $FontColor }
    $description = "Set $($requestedProperties -join ', ') for $($criteria.Count) text criterion/criteria"

    if (-not $PSCmdlet.ShouldProcess([string]$document.FullName, $description)) {
        return [pscustomobject]@{
            PSTypeName     = 'OfficeCursor.Word.TextFontBatch'
            Document       = [string]$document.FullName
            Criteria       = $criteria
            Properties     = $requestedProperties
            Applied        = $false
            UndoRecord     = $UndoName
            ElapsedMs      = 0
            DocumentSaved  = [bool]$document.Saved
        }
    }

    $wdFindStop = 0
    $wdReplaceAll = 2
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $undoStarted = $false
    try {
        $word.UndoRecord.StartCustomRecord($UndoName)
        $undoStarted = $true

        foreach ($criterion in $criteria) {
            $range = $document.Content.Duplicate
            $find = $range.Find
            $find.ClearFormatting()
            $find.Replacement.ClearFormatting()
            if ($setBold) {
                $find.Replacement.Font.Bold = if ($Bold) { -1 } else { 0 }
            }
            if ($setItalic) {
                $find.Replacement.Font.Italic = if ($Italic) { -1 } else { 0 }
            }
            if ($setFontName) {
                $find.Replacement.Font.Name = $FontName
            }
            if ($setFontSize) {
                $find.Replacement.Font.Size = [float]$FontSize
            }
            if ($setFontColor) {
                $find.Replacement.Font.Color = $targetColor
            }

            [void]$find.Execute(
                $criterion,
                [bool]$MatchCase,
                [bool]$MatchWholeWord,
                [bool]$UseWildcards,
                $false,
                $false,
                $true,
                $wdFindStop,
                $true,
                '^&',
                $wdReplaceAll,
                $false, $false, $false, $false
            )
        }
    }
    finally {
        if ($undoStarted) {
            $word.UndoRecord.EndCustomRecord()
        }
    }
    $watch.Stop()

    [pscustomobject]@{
        PSTypeName     = 'OfficeCursor.Word.TextFontBatch'
        Document       = [string]$document.FullName
        Criteria       = $criteria
        Properties     = $requestedProperties
        Applied        = $true
        UndoRecord     = $UndoName
        ElapsedMs      = [math]::Round($watch.Elapsed.TotalMilliseconds, 1)
        DocumentSaved  = [bool]$document.Saved
    }
}

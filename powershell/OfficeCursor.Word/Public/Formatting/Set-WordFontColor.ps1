function Set-WordFontColor {
    <#
    .SYNOPSIS
    Changes main-body text from one font color to another in an open document.

    .DESCRIPTION
    Uses Word's formatting-aware Find API, groups all changes into one Word
    undo record, verifies the source color no longer occurs, and verifies that
    the document text did not change.

    .PARAMETER FromColor
    Existing CSS color name, RRGGBB, #RRGGBB, Automatic, or Word color integer.

    .PARAMETER ToColor
    Replacement CSS color name, RRGGBB, #RRGGBB, Automatic, or Word color integer.

    .EXAMPLE
    Set-WordFontColor -FromColor Red -ToColor Blue

    .EXAMPLE
    Get-WordOpenDocument | Where-Object Name -like '*Manuscript*' |
        Set-WordFontColor -FromColor '#FF0000' -ToColor '#0000FF'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [object]$FromColor,

        [Parameter(Mandatory)]
        [object]$ToColor,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]$DocumentPath
    )

    process {
        $word = Connect-WordApplication
        $document = Resolve-WordDocument -Application $word -DocumentPath $DocumentPath
        $fromValue = ConvertTo-WordColor -Color $FromColor
        $toValue = ConvertTo-WordColor -Color $ToColor

        if ($fromValue -eq $toValue) {
            throw 'FromColor and ToColor resolve to the same Word color.'
        }

        $fromDisplay = ConvertFrom-WordColor -Value $fromValue
        $toDisplay = ConvertFrom-WordColor -Value $toValue
        $matches = @(Get-WordRangeMatches -Document $document -FontColorValue $fromValue)
        $beforeText = [string]$document.Content.Text
        $applied = $false

        if ($matches.Count -gt 0 -and $PSCmdlet.ShouldProcess(
            [string]$document.FullName,
            "Change $($matches.Count) font-color ranges from $fromDisplay to $toDisplay")) {
            Invoke-WordUndoRecord -Application $word -Name "Office Cursor: $fromDisplay to $toDisplay" -Action {
                foreach ($match in $matches) {
                    $match.Range.Font.Color = $toValue
                }
            }
            $applied = $true
        }

        $remaining = @(Get-WordRangeMatches -Document $document -FontColorValue $fromValue).Count
        $textUnchanged = $beforeText -ceq [string]$document.Content.Text

        [pscustomobject]@{
            PSTypeName            = 'OfficeCursor.Word.FontColorChange'
            Document              = [string]$document.FullName
            FromColor             = $fromDisplay
            ToColor               = $toDisplay
            MatchedRanges         = $matches.Count
            Applied               = $applied
            RemainingSourceRanges = $remaining
            TextUnchanged          = $textUnchanged
            Verified               = if ($applied) {
                $remaining -eq 0 -and $textUnchanged
            }
            else {
                $matches.Count -eq 0
            }
        }
    }
}

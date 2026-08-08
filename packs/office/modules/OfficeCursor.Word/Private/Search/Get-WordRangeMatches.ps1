function Get-WordRangeMatches {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Document,

        [AllowEmptyString()]
        [string]$Text,

        [switch]$MatchCase,

        [switch]$MatchWholeWord,

        [switch]$UseWildcards,

        [Nullable[int]]$FontColorValue,

        [string]$FontName,

        [Nullable[float]]$FontSize,

        [Nullable[bool]]$Bold,

        [Nullable[bool]]$Italic,

        [string]$Style,

        [Nullable[bool]]$Highlighted,

        [Nullable[int]]$HighlightColorIndex
    )

    $criterionNames = @(
        'Text', 'FontColorValue', 'FontName', 'FontSize', 'Bold', 'Italic',
        'Style', 'Highlighted', 'HighlightColorIndex'
    )
    $hasCriterion = @($criterionNames | Where-Object { $PSBoundParameters.ContainsKey($_) }).Count -gt 0
    if (-not $hasCriterion) {
        throw 'Specify at least one text or formatting search criterion.'
    }

    $wdFindStop = 0
    $position = [int]$Document.Content.Start

    while ($position -lt [int]$Document.Content.End) {
        $searchRange = $Document.Range($position, [int]$Document.Content.End)
        $find = $searchRange.Find
        $find.ClearFormatting()
        $find.Text = if ($PSBoundParameters.ContainsKey('Text')) { $Text } else { '' }
        $find.Forward = $true
        $find.Wrap = $wdFindStop
        $find.Format = $true
        $find.MatchCase = [bool]$MatchCase
        $find.MatchWholeWord = [bool]$MatchWholeWord
        $find.MatchWildcards = [bool]$UseWildcards

        if ($PSBoundParameters.ContainsKey('FontColorValue')) {
            $find.Font.Color = [int]$FontColorValue
        }
        if ($PSBoundParameters.ContainsKey('FontName')) {
            $find.Font.Name = $FontName
        }
        if ($PSBoundParameters.ContainsKey('FontSize')) {
            $find.Font.Size = [float]$FontSize
        }
        if ($PSBoundParameters.ContainsKey('Bold')) {
            $find.Font.Bold = if ($Bold) { -1 } else { 0 }
        }
        if ($PSBoundParameters.ContainsKey('Italic')) {
            $find.Font.Italic = if ($Italic) { -1 } else { 0 }
        }
        if ($PSBoundParameters.ContainsKey('Style')) {
            $find.Style = $Style
        }
        if ($PSBoundParameters.ContainsKey('Highlighted')) {
            $find.Highlight = if ($Highlighted) { -1 } else { 0 }
        }
        if ($PSBoundParameters.ContainsKey('HighlightColorIndex')) {
            # Word Find can search highlighted text, but exact highlight color
            # is filtered from each returned live range.
            $find.Highlight = -1
        }

        if (-not $find.Execute()) {
            break
        }

        if ($searchRange.Start -eq $searchRange.End) {
            throw 'Word returned an empty range. Zero-length wildcard matches are not supported.'
        }

        if ($PSBoundParameters.ContainsKey('HighlightColorIndex') -and
            [int]$searchRange.HighlightColorIndex -ne [int]$HighlightColorIndex) {
            $position = [int]$searchRange.End
            continue
        }

        [pscustomobject]@{
            Range = $searchRange.Duplicate
            Start = [int]$searchRange.Start
            End   = [int]$searchRange.End
            Text  = [string]$searchRange.Text
        }

        $position = [int]$searchRange.End
    }
}

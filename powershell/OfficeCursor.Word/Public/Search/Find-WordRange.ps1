function Find-WordRange {
    <#
    .SYNOPSIS
    Finds main-body Word ranges by text and first-class Word formatting criteria.

    .DESCRIPTION
    Wraps Microsoft Word's native Find object. Multiple supplied criteria are
    combined, so a result must satisfy both the text and formatting conditions.
    Word wildcard syntax is not regular-expression syntax.

    .PARAMETER Text
    Text or a Word wildcard pattern to find. Omit it for a formatting-only search.

    .PARAMETER FontColor
    A CSS color name, RRGGBB, #RRGGBB, Automatic, or Word color integer.

    .PARAMETER Bold
    Find bold ($true) or non-bold ($false) text. Omit to ignore bold formatting.

    .PARAMETER HighlightColor
    Finds text with an exact Word highlight color such as Yellow or BrightGreen.

    .EXAMPLE
    Find-WordRange -Text 'lecture' -MatchWholeWord

    .EXAMPLE
    Find-WordRange -FontColor Red

    .EXAMPLE
    Find-WordRange -Text 'the' -FontColor Blue -MatchWholeWord

    .EXAMPLE
    Find-WordRange -Text '<[A-Z][a-z]@>' -UseWildcards -Bold $true

    .EXAMPLE
    Find-WordRange -HighlightColor Yellow
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Text,

        [switch]$MatchCase,

        [switch]$MatchWholeWord,

        [switch]$UseWildcards,

        [object]$FontColor,

        [string]$FontName,

        [Nullable[float]]$FontSize,

        [Nullable[bool]]$Bold,

        [Nullable[bool]]$Italic,

        [string]$Style,

        [Nullable[bool]]$Highlighted,

        [object]$HighlightColor,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]$DocumentPath
    )

    process {
        $word = Connect-WordApplication
        $document = Resolve-WordDocument -Application $word -DocumentPath $DocumentPath

        $search = @{
            Document      = $document
            MatchCase     = $MatchCase
            MatchWholeWord = $MatchWholeWord
            UseWildcards  = $UseWildcards
        }

        foreach ($name in @(
            'Text', 'FontName', 'FontSize', 'Bold', 'Italic', 'Style', 'Highlighted'
        )) {
            if ($PSBoundParameters.ContainsKey($name)) {
                $search[$name] = $PSBoundParameters[$name]
            }
        }
        if ($PSBoundParameters.ContainsKey('FontColor')) {
            $search['FontColorValue'] = ConvertTo-WordColor -Color $FontColor
        }
        if ($PSBoundParameters.ContainsKey('HighlightColor')) {
            $search['HighlightColorIndex'] = ConvertTo-WordHighlightColor -Color $HighlightColor
        }

        foreach ($match in Get-WordRangeMatches @search) {
            $range = $match.Range
            $font = $range.Font
            $fontColorValue = [int]$font.Color
            [pscustomobject]@{
                PSTypeName = 'OfficeCursor.Word.RangeMatch'
                Document   = [string]$document.FullName
                Story      = 'MainText'
                Start      = $match.Start
                End        = $match.End
                Text       = $match.Text
                Style      = if ($PSBoundParameters.ContainsKey('Style')) { $Style } else { $null }
                FontName   = [string]$font.Name
                FontSize   = [float]$font.Size
                FontColor  = ConvertFrom-WordColor -Value $fontColorValue
                HighlightColor = ConvertFrom-WordHighlightColor -Value ([int]$range.HighlightColorIndex)
                Bold       = if ([int]$font.Bold -eq -1) { $true } elseif ([int]$font.Bold -eq 0) { $false } else { $null }
                Italic     = if ([int]$font.Italic -eq -1) { $true } elseif ([int]$font.Italic -eq 0) { $false } else { $null }
            }
        }
    }
}

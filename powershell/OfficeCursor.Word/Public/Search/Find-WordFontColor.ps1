function Find-WordFontColor {
    <#
    .SYNOPSIS
    Finds main-body ranges whose text has a specified font color.

    .PARAMETER Color
    A CSS color name, RRGGBB, #RRGGBB, Automatic, or Word color integer.

    .EXAMPLE
    Find-WordFontColor -Color Red

    .EXAMPLE
    Get-WordOpenDocument | Where-Object Active | Find-WordFontColor -Color '#FF0000'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Color,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]$DocumentPath
    )

    process {
        Find-WordRange -DocumentPath $DocumentPath -FontColor $Color
    }
}

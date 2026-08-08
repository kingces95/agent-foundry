function ConvertTo-WordHighlightColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Color
    )

    if ($Color -is [byte] -or $Color -is [int16] -or
        $Color -is [int32] -or $Color -is [int64]) {
        return [int]$Color
    }

    $colors = @{
        None        = 0
        Black       = 1
        Blue        = 2
        Turquoise   = 3
        BrightGreen = 4
        Pink        = 5
        Red         = 6
        Yellow      = 7
        White       = 8
        DarkBlue    = 9
        Teal        = 10
        Green       = 11
        Violet      = 12
        DarkRed     = 13
        DarkYellow  = 14
        Gray50      = 15
        Gray25      = 16
    }

    $name = ([string]$Color).Replace(' ', '')
    foreach ($knownName in $colors.Keys) {
        if ($knownName -ieq $name) {
            return [int]$colors[$knownName]
        }
    }

    throw "Unknown Word highlight color '$Color'."
}


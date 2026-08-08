function ConvertFrom-WordHighlightColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Value
    )

    $names = @{
        0 = 'None'; 1 = 'Black'; 2 = 'Blue'; 3 = 'Turquoise';
        4 = 'BrightGreen'; 5 = 'Pink'; 6 = 'Red'; 7 = 'Yellow';
        8 = 'White'; 9 = 'DarkBlue'; 10 = 'Teal'; 11 = 'Green';
        12 = 'Violet'; 13 = 'DarkRed'; 14 = 'DarkYellow';
        15 = 'Gray50'; 16 = 'Gray25'
    }

    if ($names.ContainsKey($Value)) {
        return [string]$names[$Value]
    }
    if ([Math]::Abs([long]$Value) -eq 9999999) {
        return 'Mixed'
    }
    return "Unknown($Value)"
}


function ConvertFrom-WordColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Value
    )

    if ($Value -eq -16777216) {
        return 'Automatic'
    }
    if ([Math]::Abs([long]$Value) -eq 9999999) {
        return 'Mixed'
    }

    $red = $Value -band 0xFF
    $green = ($Value -shr 8) -band 0xFF
    $blue = ($Value -shr 16) -band 0xFF
    return '#{0:X2}{1:X2}{2:X2}' -f $red, $green, $blue
}

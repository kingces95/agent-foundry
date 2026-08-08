function ConvertTo-WordColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Color
    )

    if ($Color -is [byte] -or $Color -is [int16] -or
        $Color -is [int32] -or $Color -is [int64]) {
        return [int]$Color
    }

    $text = ([string]$Color).Trim()
    if ($text -ieq 'Automatic') {
        return -16777216 # wdColorAutomatic
    }

    if ($text -match '^#?(?<rgb>[0-9a-fA-F]{6})$') {
        $rgb = $Matches.rgb
        $red = [Convert]::ToInt32($rgb.Substring(0, 2), 16)
        $green = [Convert]::ToInt32($rgb.Substring(2, 2), 16)
        $blue = [Convert]::ToInt32($rgb.Substring(4, 2), 16)
        return [int]($red -bor ($green -shl 8) -bor ($blue -shl 16))
    }

    if (-not ('System.Drawing.Color' -as [type])) {
        Add-Type -AssemblyName System.Drawing
    }

    $namedColor = [System.Drawing.Color]::FromName($text)
    if (-not $namedColor.IsKnownColor) {
        throw "Unknown color '$Color'. Use a CSS color name, RRGGBB, #RRGGBB, Automatic, or a Word color integer."
    }

    $red = [int]$namedColor.R
    $green = [int]$namedColor.G
    $blue = [int]$namedColor.B
    return [int]($red -bor ($green -shl 8) -bor ($blue -shl 16))
}

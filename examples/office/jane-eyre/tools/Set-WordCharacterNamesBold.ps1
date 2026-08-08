[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputPath,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [string[]]$Names = @('Jane', 'Rochester', 'Edward', 'St. John', 'Helen', 'Bertha')
)

$ErrorActionPreference = 'Stop'
$wdFindStop = 0
$wdReplaceAll = 2
$wdStatisticPages = 2

$inputFile = Get-Item -LiteralPath $InputPath
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = [System.IO.Path]::GetDirectoryName($outputFullPath)
if (-not [System.IO.Directory]::Exists($outputDirectory)) {
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
}

$totalWatch = [System.Diagnostics.Stopwatch]::StartNew()
$copyWatch = [System.Diagnostics.Stopwatch]::StartNew()
[System.IO.File]::Copy($inputFile.FullName, $outputFullPath, $true)
$copyWatch.Stop()

$word = $null
$document = $null
$openMilliseconds = 0
$editMilliseconds = 0
$saveMilliseconds = 0
$pageCount = 0

try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0

    $openWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $document = $word.Documents.Open($outputFullPath, $false, $false)
    $openWatch.Stop()
    $openMilliseconds = $openWatch.Elapsed.TotalMilliseconds
    $pageCount = $document.ComputeStatistics($wdStatisticPages)

    # Word's native Replace All performs the search inside Word rather than
    # crossing the PowerShell/COM boundary once per match.
    $editWatch = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($name in $Names) {
        $range = $document.Content.Duplicate
        $find = $range.Find
        $find.ClearFormatting()
        $find.Replacement.ClearFormatting()
        $find.Replacement.Font.Bold = -1
        [void]$find.Execute(
            $name,                 # FindText
            $false,                # MatchCase
            $true,                 # MatchWholeWord
            $false,                # MatchWildcards
            $false,                # MatchSoundsLike
            $false,                # MatchAllWordForms
            $true,                 # Forward
            $wdFindStop,           # Wrap
            $true,                 # Format
            '^&',                  # ReplaceWith: preserve matched text
            $wdReplaceAll,         # Replace
            $false, $false, $false, $false
        )
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($find)
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($range)
    }
    $editWatch.Stop()
    $editMilliseconds = $editWatch.Elapsed.TotalMilliseconds

    $saveWatch = [System.Diagnostics.Stopwatch]::StartNew()
    # The output is already a byte-for-byte DOCX copy. Save in place so Word
    # does not perform a format conversion or regenerate fields such as TOCs.
    $document.Save()
    $saveWatch.Stop()
    $saveMilliseconds = $saveWatch.Elapsed.TotalMilliseconds

}
finally {
    if ($null -ne $document) {
        $document.Close($false)
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document)
    }
    if ($null -ne $word) {
        $word.Quit()
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word)
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}

$totalWatch.Stop()
$result = [ordered]@{
    input = $inputFile.FullName
    output = $outputFullPath
    bytes = (Get-Item -LiteralPath $outputFullPath).Length
    pages = $pageCount
    names = $Names
    timing_ms = [ordered]@{
        copy = [math]::Round($copyWatch.Elapsed.TotalMilliseconds, 1)
        open = [math]::Round($openMilliseconds, 1)
        edit = [math]::Round($editMilliseconds, 1)
        save = [math]::Round($saveMilliseconds, 1)
        total = [math]::Round($totalWatch.Elapsed.TotalMilliseconds, 1)
    }
    verification = 'Run a bulk OOXML verification pass after this timed Word edit.'
}

$result | ConvertTo-Json -Depth 5

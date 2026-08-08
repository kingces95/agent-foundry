function Export-DocxBodySlice {
    <#
    .SYNOPSIS
    Exports one or more ranges of DOCX body children as complete DOCX files.
    .DESCRIPTION
    Each slice is an object containing StartIndex (inclusive), EndIndex
    (exclusive), and OutputPath. Indexes address direct w:body children. The
    source section properties are retained and every output body is verified.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][object[]]$Slice,
        [string]$PythonPath,
        [switch]$Force
    )

    $inputFile = (Get-Item -LiteralPath $InputPath -ErrorAction Stop).FullName
    if (-not $PSCmdlet.ShouldProcess($inputFile, "Export $($Slice.Count) verified DOCX body slices")) {
        return
    }
    $sliceFile = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($sliceFile, ($Slice | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        $arguments = @('--input', $inputFile, '--slices-json', $sliceFile)
        if ($Force) { $arguments += '--force' }
        $result = Invoke-DocxEngine -Command 'export-body-slices' -ArgumentList $arguments -PythonPath $PythonPath
    }
    finally {
        Remove-Item -LiteralPath $sliceFile -Force -ErrorAction SilentlyContinue
    }
    foreach ($item in $result.slices) {
        [pscustomobject]@{
            PSTypeName = 'OfficeCursor.Docx.BodySliceResult'
            Input      = $inputFile
            Output     = [string]$item.output
            StartIndex = [int]$item.start_index
            EndIndex   = [int]$item.end_index
            BodySha256 = [string]$item.body_sha256
            Verified   = [bool]$item.verified
        }
    }
}

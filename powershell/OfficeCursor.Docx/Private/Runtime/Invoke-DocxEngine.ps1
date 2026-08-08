function Invoke-DocxEngine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [string]$PythonPath
    )

    $python = Resolve-DocxPython -PythonPath $PythonPath
    $engine = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'Engine\docx_engine.py'
    $output = (& $python $engine $Command @ArgumentList) -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0) {
        throw "DOCX engine command '$Command' failed with exit code $LASTEXITCODE."
    }
    return $output | ConvertFrom-Json
}

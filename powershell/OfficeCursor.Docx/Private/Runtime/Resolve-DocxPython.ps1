function Resolve-DocxPython {
    [CmdletBinding()]
    param([string]$PythonPath)

    if ($PythonPath) {
        $candidate = Get-Item -LiteralPath $PythonPath -ErrorAction Stop
        return $candidate.FullName
    }

    $bundled = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
    if (Test-Path -LiteralPath $bundled) {
        return $bundled
    }

    $command = Get-Command python -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw 'Python was not found. Supply -PythonPath; the offline DOCX engine also requires lxml.'
}

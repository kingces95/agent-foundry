function Resolve-DocxPython {
    [CmdletBinding()]
    param([string]$PythonPath)

    if ($PythonPath) {
        $candidate = Get-Item -LiteralPath $PythonPath -ErrorAction Stop
        return $candidate.FullName
    }

    if ($IsWindows -and $env:USERPROFILE) {
        $bundled = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
        if (Test-Path -LiteralPath $bundled) {
            return $bundled
        }
    }

    foreach ($name in @('python3', 'python')) {
        $commands = @(Get-Command $name -CommandType Application -ErrorAction SilentlyContinue)
        if ($commands.Count) {
            return [string]$commands[0].Source
        }
    }

    throw 'Python was not found. Supply -PythonPath; the offline DOCX engine also requires lxml.'
}

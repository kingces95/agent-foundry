function Invoke-WordUndoRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Application,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Action,

        [object[]]$ArgumentList = @()
    )

    $started = $false
    try {
        $Application.UndoRecord.StartCustomRecord($Name)
        $started = $true
        & $Action @ArgumentList
    }
    finally {
        if ($started) {
            $Application.UndoRecord.EndCustomRecord()
        }
    }
}

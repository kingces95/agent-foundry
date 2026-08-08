function Resolve-WordDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Application,

        [string]$DocumentPath
    )

    if ([string]::IsNullOrWhiteSpace($DocumentPath)) {
        $activeDocument = $Application.ActiveDocument
        if ($null -eq $activeDocument) {
            throw 'Word has no active document.'
        }

        return $activeDocument
    }

    $targetIdentity = Get-WordDocumentIdentity -Path $DocumentPath
    foreach ($candidate in $Application.Documents) {
        $candidateIdentity = Get-WordDocumentIdentity -Path ([string]$candidate.FullName)
        if ([string]::Equals(
            $candidateIdentity,
            $targetIdentity,
            [StringComparison]::OrdinalIgnoreCase)) {
            return $candidate
        }
    }

    throw "The requested document is not open in this Word instance: $DocumentPath"
}

function Get-WordOpenDocument {
    <#
    .SYNOPSIS
    Lists documents in the running Microsoft Word instance.

    .EXAMPLE
    Get-WordOpenDocument

    .EXAMPLE
    Get-WordOpenDocument | Where-Object { -not $_.ReadOnly }
    #>
    [CmdletBinding()]
    param()

    $word = Connect-WordApplication
    $activeDocument = $word.ActiveDocument

    foreach ($document in $word.Documents) {
        $fullName = [string]$document.FullName
        $uri = $null
        $isCloudDocument = [Uri]::TryCreate(
            $fullName,
            [UriKind]::Absolute,
            [ref]$uri
        ) -and $uri.Scheme -in @('http', 'https')

        [pscustomobject]@{
            PSTypeName   = 'OfficeCursor.Word.OpenDocument'
            Active       = $null -ne $activeDocument -and
                           [string]::Equals(
                               $fullName,
                               [string]$activeDocument.FullName,
                               [StringComparison]::OrdinalIgnoreCase
                           )
            Name         = [string]$document.Name
            FullName     = $fullName
            LocationKind = if ($isCloudDocument) { 'Cloud' } else { 'Local' }
            Saved        = [bool]$document.Saved
            ReadOnly     = [bool]$document.ReadOnly
        }
    }
}

function Get-WordDocumentIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $uri = $null
    if ([Uri]::TryCreate($Path, [UriKind]::Absolute, [ref]$uri) -and
        $uri.Scheme -in @('http', 'https')) {
        return $uri.AbsoluteUri
    }

    return [IO.Path]::GetFullPath($Path)
}

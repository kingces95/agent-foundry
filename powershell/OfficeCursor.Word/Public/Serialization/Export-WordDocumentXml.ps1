function Export-WordDocumentXml {
    <#
    .SYNOPSIS
    Exports the live Flat OPC XML representation of an open Word document.

    .PARAMETER Path
    Destination XML path. For local documents the default is beside the DOCX.
    For cloud documents it is in the current directory.

    .EXAMPLE
    Export-WordDocumentXml

    .EXAMPLE
    Get-WordOpenDocument | Export-WordDocumentXml -Path C:\Temp\document.flatopc.xml
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]$DocumentPath,

        [string]$Path
    )

    process {
        $word = Connect-WordApplication
        $document = Resolve-WordDocument -Application $word -DocumentPath $DocumentPath
        $documentFullName = [string]$document.FullName
        $outputPath = $Path

        if ([string]::IsNullOrWhiteSpace($outputPath)) {
            $uri = $null
            if ([Uri]::TryCreate($documentFullName, [UriKind]::Absolute, [ref]$uri) -and
                $uri.Scheme -in @('http', 'https')) {
                $outputPath = Join-Path $PWD "$([string]$document.Name).office-cursor.flatopc.xml"
            }
            else {
                $outputPath = "$documentFullName.office-cursor.flatopc.xml"
            }
        }
        else {
            $outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)
        }

        $xml = [string]$document.WordOpenXML
        [IO.File]::WriteAllText($outputPath, $xml, [Text.UTF8Encoding]::new($false))

        [pscustomobject]@{
            PSTypeName   = 'OfficeCursor.Word.XmlExport'
            Document     = $documentFullName
            Path         = $outputPath
            Characters   = $xml.Length
            SHA256       = Get-StringSha256 -Text $xml
        }
    }
}

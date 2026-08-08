function Get-WordDocumentXml {
    <#
    .SYNOPSIS
    Gets the live Flat OPC XML representation of an open Word document.

    .PARAMETER DocumentPath
    The FullName emitted by Get-WordOpenDocument. The active document is used
    when this parameter is omitted.

    .EXAMPLE
    $xml = Get-WordDocumentXml

    .EXAMPLE
    Get-WordOpenDocument | Where-Object Active | Get-WordDocumentXml
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]$DocumentPath
    )

    process {
        $word = Connect-WordApplication
        $document = Resolve-WordDocument -Application $word -DocumentPath $DocumentPath
        [string]$document.WordOpenXML
    }
}

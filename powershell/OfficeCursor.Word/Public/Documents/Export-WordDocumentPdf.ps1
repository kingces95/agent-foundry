function Export-WordDocumentPdf {
    <#
    .SYNOPSIS
    Exports a Word document on disk to PDF through an isolated Word instance.

    .DESCRIPTION
    Opens the input read-only with macros disabled, exports all pages using
    Word's native fixed-format exporter, and closes the temporary Word instance
    without saving the source document.

    .EXAMPLE
    Export-WordDocumentPdf -InputPath manuscript.docx -OutputPath qa\manuscript.pdf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]$InputPath,

        [string]$OutputPath,

        [switch]$Force
    )

    process {
        $inputFile = Get-Item -LiteralPath $InputPath
        if (-not $OutputPath) {
            $OutputPath = [IO.Path]::ChangeExtension($inputFile.FullName, '.pdf')
        }
        $outputFullPath = [IO.Path]::GetFullPath($OutputPath)
        if ((Test-Path -LiteralPath $outputFullPath) -and -not $Force) {
            throw "Output already exists: $outputFullPath. Use -Force to replace it."
        }
        $outputDirectory = [IO.Path]::GetDirectoryName($outputFullPath)
        if (-not [IO.Directory]::Exists($outputDirectory)) {
            [void][IO.Directory]::CreateDirectory($outputDirectory)
        }
        if (-not $PSCmdlet.ShouldProcess($outputFullPath, "Export $($inputFile.Name) to PDF")) {
            return
        }

        $word = $null
        $document = $null
        $pages = 0
        $watch = [Diagnostics.Stopwatch]::StartNew()
        try {
            $wordType = [type]::GetTypeFromProgID('Word.Application', $true)
            $word = [Activator]::CreateInstance($wordType)
            $word.Visible = $false
            $word.DisplayAlerts = 0
            $word.AutomationSecurity = 3
            $document = $word.Documents.Open($inputFile.FullName, $false, $true)
            $pages = $document.ComputeStatistics(2)
            $document.ExportAsFixedFormat(
                $outputFullPath, 17, $false, 0, 0, 1, 9999, 0,
                $true, $true, 0, $true, $true, $false)
        }
        finally {
            if ($null -ne $document) {
                $document.Close($false)
                [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document)
            }
            if ($null -ne $word) {
                $word.Quit()
                [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word)
            }
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
        }
        $watch.Stop()

        $pdf = Get-Item -LiteralPath $outputFullPath
        [pscustomobject]@{
            PSTypeName     = 'OfficeCursor.Word.PdfExport'
            Input          = $inputFile.FullName
            Output         = $pdf.FullName
            Pages          = [int]$pages
            Bytes          = [long]$pdf.Length
            ElapsedMs      = [math]::Round($watch.Elapsed.TotalMilliseconds, 1)
            SourceModified = $false
            OpenedReadOnly = $true
        }
    }
}

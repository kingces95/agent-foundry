function Add-WordParagraph {
    <#
    .SYNOPSIS
    Adds a paragraph at the end of an open Word document's main story.

    .DESCRIPTION
    Newlines in Text become Word manual line breaks inside the new paragraph.
    The insertion is grouped into one Word undo record and verified after Word
    has applied it.

    .EXAMPLE
    Add-WordParagraph -Text 'A new closing paragraph.' -Style Normal

    .EXAMPLE
    Add-WordParagraph -Text "First line`nSecond line" -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [string]$Style,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]$DocumentPath
    )

    process {
        $word = Connect-WordApplication
        $document = Resolve-WordDocument -Application $word -DocumentPath $DocumentPath
        $manualBreak = [string][char]11
        $normalizedText = $Text -replace "`r`n|`r|`n", $manualBreak
        $setStyle = $PSBoundParameters.ContainsKey('Style')

        if (-not $PSCmdlet.ShouldProcess(
            [string]$document.FullName,
            "Append a paragraph containing $($normalizedText.Length) characters")) {
            [pscustomobject]@{
                PSTypeName = 'OfficeCursor.Word.ParagraphAddition'
                Document   = [string]$document.FullName
                Text       = $normalizedText
                Style      = $Style
                Applied    = $false
                Verified   = $false
            }
            return
        }

        $state = [pscustomobject]@{ Paragraph = $null }
        Invoke-WordUndoRecord -Application $word -Name 'Office Cursor: add paragraph' -Action {
            $state.Paragraph = $document.Paragraphs.Add()
            $paragraph = $state.Paragraph
            $contentRange = $paragraph.Range.Duplicate
            if ($contentRange.End -gt $contentRange.Start -and
                [string]$contentRange.Text -match "`r$") {
                $contentRange.End = $contentRange.End - 1
            }
            $contentRange.Text = $normalizedText

            if ($setStyle) {
                $paragraph.Range.Style = $Style
            }
        }

        $paragraph = $state.Paragraph
        $actualText = [string]$paragraph.Range.Text
        if ($actualText.Length -gt 0 -and $actualText[$actualText.Length - 1] -eq [char]13) {
            $actualText = $actualText.Substring(0, $actualText.Length - 1)
        }

        [pscustomobject]@{
            PSTypeName = 'OfficeCursor.Word.ParagraphAddition'
            Document   = [string]$document.FullName
            Start      = [int]$paragraph.Range.Start
            End        = [int]$paragraph.Range.End
            Text       = $normalizedText
            Style      = $Style
            Applied    = $true
            Verified   = $actualText -ceq $normalizedText
        }
    }
}

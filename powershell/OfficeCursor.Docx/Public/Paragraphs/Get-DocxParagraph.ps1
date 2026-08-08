function Get-DocxParagraph {
    <#
    .SYNOPSIS
    Projects DOCX paragraphs into structured PowerShell objects.
    .DESCRIPTION
    Reads a closed DOCX without starting Word. The projection includes stable
    indexes for the current package, visible text, and effective font colors
    resolved through direct, character-style, and paragraph-style formatting.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')][string]$Path,
        [string]$PythonPath
    )

    process {
        $inputFile = (Get-Item -LiteralPath $Path -ErrorAction Stop).FullName
        $result = Invoke-DocxEngine -Command 'get-paragraphs' -ArgumentList @('--input', $inputFile) -PythonPath $PythonPath
        foreach ($paragraph in $result.paragraphs) {
            [pscustomobject]@{
                PSTypeName       = 'OfficeCursor.Docx.Paragraph'
                Path             = $inputFile
                Index            = [int]$paragraph.index
                BodyChildIndex   = if ($null -eq $paragraph.body_child_index) { $null } else { [int]$paragraph.body_child_index }
                Text             = [string]$paragraph.text
                NormalizedText   = [string]$paragraph.normalized_text
                DominantColor    = [string]$paragraph.dominant_color
                CharacterCount   = [int]$paragraph.character_count
            }
        }
    }
}

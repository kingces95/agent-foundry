@{
    RootModule        = 'OfficeCursor.Docx.psm1'
    ModuleVersion     = '0.4.0'
    GUID              = '6f8b20a8-16de-46a2-b0de-c6b14f2debb4'
    Author            = 'Office Cursor contributors'
    Description       = 'Deterministic, verified offline transformations over DOCX/OOXML packages.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Edit-DocxParagraph'
        'Export-DocxBodySlice'
        'Get-DocxParagraph'
        'Get-DocxSchema'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Microsoft Word', 'DOCX', 'OOXML', 'Automation')
            ProjectUri = 'https://github.com/kingces95/office-cursor'
        }
    }
}

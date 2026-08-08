@{
    RootModule        = 'OfficeCursor.Word.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a560c627-aadf-45b7-be33-b200c57ade97'
    Author            = 'Office Cursor contributors'
    Description       = 'Agent-friendly PowerShell commands over the live Microsoft Word COM object model.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Add-WordParagraph'
        'Export-WordDocumentXml'
        'Export-WordDocumentPdf'
        'Find-WordFontColor'
        'Find-WordRange'
        'Get-WordDocumentXml'
        'Get-WordOpenDocument'
        'Set-WordRangeText'
        'Set-WordFontColor'
        'Set-WordRangeFont'
        'Set-WordTextFont'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Microsoft Word', 'COM', 'Automation')
            ProjectUri = 'https://github.com/kingces95/agent-foundry'
        }
    }
}

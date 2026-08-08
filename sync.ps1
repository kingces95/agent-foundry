[CmdletBinding()]
param(
    [string]$SidecarPath
)

$ErrorActionPreference = 'Stop'

function Get-RunningWord {
    # Marshal.GetActiveObject exists in Windows PowerShell 5.1, but not in
    # modern PowerShell. This small COM interop shim works in both.
    if (-not ('OfficeCursor.RunningComObject' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace OfficeCursor
{
    public static class RunningComObject
    {
        [DllImport("ole32.dll", CharSet = CharSet.Unicode)]
        private static extern int CLSIDFromProgID(string progId, out Guid clsid);

        [DllImport("oleaut32.dll", PreserveSig = false)]
        private static extern void GetActiveObject(
            ref Guid clsid,
            IntPtr reserved,
            [MarshalAs(UnmanagedType.IUnknown)] out object instance);

        public static object Get(string progId)
        {
            Guid clsid;
            int result = CLSIDFromProgID(progId, out clsid);
            if (result < 0)
                Marshal.ThrowExceptionForHR(result);

            object instance;
            GetActiveObject(ref clsid, IntPtr.Zero, out instance);
            return instance;
        }
    }
}
'@
    }

    try {
        return [OfficeCursor.RunningComObject]::Get('Word.Application')
    }
    catch {
        throw 'Could not attach to Microsoft Word. Start Word, open a saved document, and try again.'
    }
}

$word = Get-RunningWord
$document = $word.ActiveDocument

if ($null -eq $document) {
    throw 'Word has no active document.'
}

if ([string]::IsNullOrWhiteSpace($document.Path)) {
    throw 'Save the Word document before exporting it.'
}

$documentPath = $document.FullName
if ([string]::IsNullOrWhiteSpace($SidecarPath)) {
    $documentUri = $null
    if ([Uri]::TryCreate($documentPath, [UriKind]::Absolute, [ref]$documentUri) -and
        $documentUri.Scheme -in @('http', 'https')) {
        # Word reports OneDrive/SharePoint documents as URLs, which cannot
        # have an ordinary filesystem sidecar. Put it in the working folder.
        $documentName = [Uri]::UnescapeDataString($documentUri.Segments[-1])
        $SidecarPath = Join-Path $PWD "$documentName.office-cursor.json"
        Write-Warning "Word reports a cloud URL; using a local sidecar in $PWD"
    }
    else {
        $SidecarPath = "$documentPath.office-cursor.json"
    }
}
else {
    $SidecarPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SidecarPath)
}

$paragraphs = @()
for ($index = 1; $index -le $document.Paragraphs.Count; $index++) {
    $rangeText = [string]$document.Paragraphs.Item($index).Range.Text

    # Word includes structural terminators in a paragraph Range. They are not
    # editable content and are deliberately excluded from the sidecar.
    if ($rangeText.Length -ge 2 -and
        $rangeText[$rangeText.Length - 2] -eq [char]13 -and
        $rangeText[$rangeText.Length - 1] -eq [char]7) {
        $rangeText = $rangeText.Substring(0, $rangeText.Length - 2)
    }
    elseif ($rangeText.Length -ge 1 -and
            $rangeText[$rangeText.Length - 1] -eq [char]13) {
        $rangeText = $rangeText.Substring(0, $rangeText.Length - 1)
    }

    $paragraphs += [ordered]@{
        index = $index
        text  = $rangeText
    }
}

$serialization = [ordered]@{
    schemaVersion = 1
    documentPath  = $documentPath
    exportedAtUtc = [DateTime]::UtcNow.ToString('o')
    paragraphs    = $paragraphs
}

Write-Host "Word document: $documentPath"
Write-Host "Sidecar target: $SidecarPath"

$serialization |
    ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath $SidecarPath -Encoding utf8

Write-Host "Exported $($paragraphs.Count) paragraphs to:"
Write-Host $SidecarPath

[CmdletBinding()]
param(
    [string]$SidecarPath
)

$ErrorActionPreference = 'Stop'

function Get-RunningWord {
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
        throw 'Could not attach to Microsoft Word. Start Word, open the exported document, and try again.'
    }
}

function Get-DocumentIdentity([string]$Path) {
    $uri = $null
    if ([Uri]::TryCreate($Path, [UriKind]::Absolute, [ref]$uri) -and
        $uri.Scheme -in @('http', 'https')) {
        return $uri.AbsoluteUri
    }

    return [System.IO.Path]::GetFullPath($Path)
}

$word = Get-RunningWord

if ([string]::IsNullOrWhiteSpace($SidecarPath)) {
    $activeDocument = $word.ActiveDocument
    if ($null -eq $activeDocument -or [string]::IsNullOrWhiteSpace($activeDocument.Path)) {
        throw 'Activate the saved Word document to apply, or pass -SidecarPath.'
    }

    $activePath = [string]$activeDocument.FullName
    $activeUri = $null
    if ([Uri]::TryCreate($activePath, [UriKind]::Absolute, [ref]$activeUri) -and
        $activeUri.Scheme -in @('http', 'https')) {
        $documentName = [Uri]::UnescapeDataString($activeUri.Segments[-1])
        $SidecarPath = Join-Path $PWD "$documentName.office-cursor.json"
    }
    else {
        $SidecarPath = "$activePath.office-cursor.json"
    }
}

$SidecarPath = (Resolve-Path -LiteralPath $SidecarPath).Path
$serialization = Get-Content -LiteralPath $SidecarPath -Raw | ConvertFrom-Json

if ($serialization.schemaVersion -ne 1) {
    throw "Unsupported sidecar schema version: $($serialization.schemaVersion)"
}

$targetPath = [string]$serialization.documentPath
$targetIdentity = Get-DocumentIdentity $targetPath
$document = $null

foreach ($candidate in $word.Documents) {
    if ([string]::Equals(
        (Get-DocumentIdentity ([string]$candidate.FullName)),
        $targetIdentity,
        [System.StringComparison]::OrdinalIgnoreCase)) {
        $document = $candidate
        break
    }
}

if ($null -eq $document) {
    throw "The exported document is not open in this Word instance: $targetPath"
}

$records = @($serialization.paragraphs)
if ($records.Count -ne $document.Paragraphs.Count) {
    throw "Paragraph count changed: sidecar has $($records.Count), Word has $($document.Paragraphs.Count). This proof of concept only replaces existing paragraph text."
}

$changed = 0

# Work backwards so changes in earlier Range lengths cannot disturb later ones.
for ($index = $records.Count; $index -ge 1; $index--) {
    $record = $records[$index - 1]
    if ([int]$record.index -ne $index) {
        throw "Expected paragraph index $index but found $($record.index)."
    }

    $paragraphRange = $document.Paragraphs.Item($index).Range.Duplicate
    $existingText = [string]$paragraphRange.Text

    if ($existingText.Length -ge 2 -and
        $existingText[$existingText.Length - 2] -eq [char]13 -and
        $existingText[$existingText.Length - 1] -eq [char]7) {
        $paragraphRange.End = $paragraphRange.End - 2
    }
    elseif ($existingText.Length -ge 1 -and
            $existingText[$existingText.Length - 1] -eq [char]13) {
        $paragraphRange.End = $paragraphRange.End - 1
    }

    $newText = if ($null -eq $record.text) { '' } else { [string]$record.text }
    if ([string]$paragraphRange.Text -cne $newText) {
        $paragraphRange.Text = $newText
        $changed++
    }
}

Write-Host "Applied $changed changed paragraphs to:"
Write-Host $targetPath
Write-Host 'The document is changed in Word but has not been saved.'

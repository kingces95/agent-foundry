function Connect-WordApplication {
    [CmdletBinding()]
    param()

    # Marshal.GetActiveObject exists in Windows PowerShell 5.1 but not in
    # modern PowerShell. The native Running Object Table API works in both.
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
        throw 'Could not attach to Microsoft Word. Start Word in this interactive Windows session and try again.'
    }
}

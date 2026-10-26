# Sets the mode of the attached display whose adapter name contains $Match.
# The change is dynamic (not written to the registry): the virtual display is
# gone after the session, so nothing has to be reverted.

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class DisplayMode
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct DISPLAY_DEVICE
    {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct DEVMODE
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
        public int dmFields, dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
        public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
        public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
    }

    const int DM_PELSWIDTH = 0x80000, DM_PELSHEIGHT = 0x100000, DM_DISPLAYFREQUENCY = 0x400000;
    const int CDS_TEST = 0x2, ENUM_CURRENT_SETTINGS = -1, ATTACHED = 0x1;

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool EnumDisplayDevices(string device, int index, ref DISPLAY_DEVICE dd, int flags);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool EnumDisplaySettings(string device, int mode, ref DEVMODE dm);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int ChangeDisplaySettingsEx(string device, ref DEVMODE dm, IntPtr hwnd, int flags, IntPtr param);

    public static List<string> Attached(string match)
    {
        var names = new List<string>();
        var dd = new DISPLAY_DEVICE { cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE)) };
        for (var i = 0; EnumDisplayDevices(null, i, ref dd, 0); i++, dd.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE)))
            if ((dd.StateFlags & ATTACHED) != 0 && dd.DeviceString.IndexOf(match, StringComparison.OrdinalIgnoreCase) >= 0)
                names.Add(dd.DeviceName);
        return names;
    }

    // 0 on success, otherwise a DISP_CHANGE_* code (DISP_CHANGE_RESTART = 1 counts as failure).
    public static int Set(string device, int width, int height, int hz)
    {
        var dm = new DEVMODE { dmSize = (short)Marshal.SizeOf(typeof(DEVMODE)) };
        if (!EnumDisplaySettings(device, ENUM_CURRENT_SETTINGS, ref dm)) return -1;
        if (dm.dmPelsWidth == width && dm.dmPelsHeight == height && dm.dmDisplayFrequency == hz) return 0;

        dm.dmPelsWidth = width;
        dm.dmPelsHeight = height;
        dm.dmDisplayFrequency = hz;
        dm.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT | DM_DISPLAYFREQUENCY;
        var rc = ChangeDisplaySettingsEx(device, ref dm, IntPtr.Zero, CDS_TEST, IntPtr.Zero);
        return rc != 0 ? rc : ChangeDisplaySettingsEx(device, ref dm, IntPtr.Zero, 0, IntPtr.Zero);
    }
}
'@

# Waits for exactly one matching display to attach, then applies the mode.
function Set-DisplayMode([string] $Match, [int] $Width, [int] $Height, [int] $Hz, [int] $TimeoutMs = 10000) {
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
    do {
        $displays = [DisplayMode]::Attached($Match)
        if ($displays.Count -eq 1) {
            $rc = [DisplayMode]::Set($displays[0], $Width, $Height, $Hz)
            if ($rc -ne 0) { throw "Could not set $($displays[0]) to ${Width}x${Height}@$Hz (code $rc)." }
            return $displays[0]
        }
        if ($displays.Count -gt 1) { throw "Found $($displays.Count) '$Match' displays; close other virtual displays first." }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "No '$Match' display attached. Is the Parsec Virtual Display Driver installed?"
}

# Mute control for one specific playback device, addressed by its endpoint id so
# the device muted at session start is the one restored, even if the Windows
# default output changes meanwhile. WASAPI loopback keeps capturing a muted
# endpoint, so the TV still gets the sound.

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorCom {}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumeratorCom
{
    int EnumAudioEndpoints(int flow, int mask, out IntPtr devices);
    [PreserveSig] int GetDefaultAudioEndpoint(int flow, int role, out IMMDeviceCom dev);
    [PreserveSig] int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IMMDeviceCom dev);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceCom
{
    [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o);
    int OpenPropertyStore(int access, out IntPtr store);
    [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
}

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolumeCom
{
    int RegisterControlChangeNotify(IntPtr n); int UnregisterControlChangeNotify(IntPtr n);
    int GetChannelCount(out int c);
    int SetMasterVolumeLevel(float l, ref Guid g); int SetMasterVolumeLevelScalar(float l, ref Guid g);
    int GetMasterVolumeLevel(out float l); int GetMasterVolumeLevelScalar(out float l);
    int SetChannelVolumeLevel(int ch, float l, ref Guid g); int SetChannelVolumeLevelScalar(int ch, float l, ref Guid g);
    int GetChannelVolumeLevel(int ch, out float l); int GetChannelVolumeLevelScalar(int ch, out float l);
    [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid g);
    [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
}

public static class PcSpeakers
{
    static IMMDeviceEnumeratorCom Enumerator() { return (IMMDeviceEnumeratorCom)new MMDeviceEnumeratorCom(); }

    // eRender, eConsole; null when no playback device exists.
    public static string DefaultId()
    {
        IMMDeviceCom dev;
        if (Enumerator().GetDefaultAudioEndpoint(0, 0, out dev) != 0 || dev == null) return null;
        string id;
        return dev.GetId(out id) == 0 ? id : null;
    }

    // null when the device is gone.
    static IAudioEndpointVolumeCom Volume(string id)
    {
        IMMDeviceCom dev;
        if (Enumerator().GetDevice(id, out dev) != 0 || dev == null) return null;
        var iid = typeof(IAudioEndpointVolumeCom).GUID;
        object o;
        return dev.Activate(ref iid, 23, IntPtr.Zero, out o) == 0 ? (IAudioEndpointVolumeCom)o : null;
    }

    public static bool? IsMuted(string id)
    {
        var v = Volume(id);
        bool m;
        if (v == null || v.GetMute(out m) != 0) return null;
        return m;
    }

    public static bool SetMute(string id, bool mute)
    {
        var v = Volume(id);
        var g = Guid.Empty;
        return v != null && v.SetMute(mute, ref g) == 0;
    }
}
'@

# Writes the restore record before muting, so a session that is killed can be
# undone by the guard or by the next session.
function Set-PcMuted([string] $StateFile) {
    $id = [PcSpeakers]::DefaultId()
    if (-not $id) { return }
    $wasMuted = [PcSpeakers]::IsMuted($id)
    if ($null -eq $wasMuted -or $wasMuted) { return }
    @{ id = $id } | ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding UTF8
    [void][PcSpeakers]::SetMute($id, $true)
}

# Unmutes the recorded device only if it still exists and is still muted, so a
# manual change made during the session is kept. Safe to call more than once.
function Restore-PcMute([string] $StateFile) {
    if (-not (Test-Path -LiteralPath $StateFile)) { return }
    try {
        $id = (Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json).id
        if ($id -and [PcSpeakers]::IsMuted($id) -eq $true) { [void][PcSpeakers]::SetMute($id, $false) }
    }
    finally {
        Remove-Item -LiteralPath $StateFile -Force -ErrorAction SilentlyContinue
    }
}

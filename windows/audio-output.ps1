# Switches the Windows default audio output.
#   audio-output.ps1 current        -> prints the id of the current default output
#   audio-output.ps1 cable          -> sets "CABLE Input" (VB-Audio) so sound only goes to the TV
#   audio-output.ps1 restore <id>   -> goes back to a saved output
param([string]$action = "current", [string]$id = "")

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")] class PolicyConfigClient {}
[Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IPolicyConfig {
    int GetMixFormat(); int GetDeviceFormat(); int ResetDeviceFormat(); int SetDeviceFormat();
    int GetProcessingPeriod(); int SetProcessingPeriod(); int GetShareMode(); int SetShareMode();
    int GetPropertyValue(); int SetPropertyValue();
    [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role);
    int SetEndpointVisibility();
}
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumerator {}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(int flow, int mask, out IntPtr devices);
    [PreserveSig] int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice dev);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    int Activate(); int OpenPropertyStore();
    [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
}
public static class AudioOutput {
    public static string Current() {
        IMMDevice d; ((IMMDeviceEnumerator)new MMDeviceEnumerator()).GetDefaultAudioEndpoint(0, 0, out d);
        string id; d.GetId(out id); return id;
    }
    public static void Set(string id) {
        var p = (IPolicyConfig)new PolicyConfigClient();
        for (int role = 0; role < 3; role++) p.SetDefaultEndpoint(id, role);
    }
}
"@

switch ($action) {
    "current" { [AudioOutput]::Current() }
    "cable" {
        $guid = (Get-PnpDevice -Class AudioEndpoint -PresentOnly |
            Where-Object FriendlyName -like "CABLE Input*").InstanceId -replace '^SWD\\MMDEVAPI\\', ''
        if (-not $guid) { Write-Error "CABLE Input (VB-Audio Virtual Cable) not found"; exit 1 }
        [AudioOutput]::Set($guid)
    }
    "restore" { if ($id) { [AudioOutput]::Set($id) } }
}

# TV as a separate 4K monitor over AirPlay: plugs a Parsec virtual display,
# sets it to 4K and streams it to the TV with hardware HEVC.
# Stop with Ctrl+C or by closing the window; session-guard.ps1 cleans up.
param(
    # IP address of the TV; empty = auto-discover
    [string] $TvIp = '',
    [int] $Width = 3840,
    [int] $Height = 2160,
    [int] $Fps = 30,
    [int] $BitrateKbps = 25000,
    # Joint audio/video playout buffer; raise it if sound or picture stutters
    [int] $LatencyMs = 500,
    # nvenc (NVIDIA), amf (AMD) or auto
    [string] $HwAccel = 'auto',
    # Mute the PC speakers while streaming; the TV keeps the sound
    [bool] $MutePc = $true
)

$ErrorActionPreference = 'Stop'
$host.UI.RawUI.WindowTitle = 'TV 4K display'
$stateFile = Join-Path $env:TEMP 'airplay-tv-4k-mute.json'

$mutex = [Threading.Mutex]::new($false, 'Local\airplay-tv-4k')
if (-not $mutex.WaitOne(0)) { throw 'Another TV session is already running.' }

$gstRoot = @(
    $env:GSTREAMER_1_0_ROOT_MSVC_X86_64,
    [Environment]::GetEnvironmentVariable('GSTREAMER_1_0_ROOT_MSVC_X86_64', 'Machine'),
    [Environment]::GetEnvironmentVariable('GSTREAMER_1_0_ROOT_MSVC_X86_64', 'User'),
    "$env:ProgramFiles\gstreamer\1.0\msvc_x86_64"
) | Where-Object { $_ -and (Test-Path (Join-Path $_ 'bin\gst-launch-1.0.exe')) } | Select-Object -First 1
if (-not $gstRoot) { throw 'GStreamer not found. Install the 64-bit MSVC runtime, "Complete".' }
$env:PATH = "$(Join-Path $gstRoot 'bin');$env:PATH"

$engine = Join-Path $PSScriptRoot 'AirPlay.Engine.exe'
if (-not (Test-Path $engine)) { throw 'AirPlay.Engine.exe missing. Run build.cmd first.' }

. "$PSScriptRoot\pc-audio.ps1"
. "$PSScriptRoot\display-mode.ps1"

# A previous session that was killed before it could unmute.
Restore-PcMute $stateFile

$vdd = Start-Process (Join-Path $PSScriptRoot 'parsec-vdd.exe') -WindowStyle Hidden -PassThru
$guardArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSScriptRoot\session-guard.ps1`"",
    '-SessionPid', $PID, '-VddPid', $vdd.Id, '-StateFile', "`"$stateFile`"")
Start-Process powershell -WindowStyle Hidden -ArgumentList $guardArgs | Out-Null

try {
    $display = Set-DisplayMode -Match 'Parsec' -Width $Width -Height $Height -Hz 60

    # gst-device-monitor lists every monitor once per capture API; the first
    # pass (until a name repeats) is the D3D11 order the engine indexes into.
    $index = $null
    for ($try = 0; $try -lt 10 -and $null -eq $index; $try++) {
        $names = @()
        foreach ($line in (gst-device-monitor-1.0 Source/Monitor 2>$null)) {
            if ($line -match 'name\s+:\s+(.*)') {
                if ($names -contains $Matches[1]) { break }
                $names += $Matches[1]
            }
        }
        $hits = @(0..($names.Count - 1) | Where-Object { $names[$_] -eq 'ParsecVDA' })
        if ($hits.Count -gt 1) { throw "Found $($hits.Count) Parsec monitors; close other virtual displays first." }
        if ($hits.Count -eq 1) { $index = $hits[0] } else { Start-Sleep -Milliseconds 500 }
    }
    if ($null -eq $index) { throw 'The virtual display did not show up in GStreamer.' }

    if ($MutePc) { Set-PcMuted $stateFile }

    $engineArgs = @('-monitor-index', $index, '-video-codec', 'hevc', '-hwaccel', $HwAccel,
        '-fps', $Fps, '-bitrate', $BitrateKbps, '-target-latency-ms', $LatencyMs)
    if ($TvIp) { $engineArgs = @('-target', $TvIp) + $engineArgs }

    Write-Host "Streaming $display (monitor $index, ${Width}x${Height}@$Fps, $BitrateKbps kbps HEVC). Drag windows onto it."
    & $engine @engineArgs
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
}
finally {
    Restore-PcMute $stateFile
    Stop-Process -Id $vdd.Id -Force -ErrorAction SilentlyContinue
    $mutex.ReleaseMutex()
}

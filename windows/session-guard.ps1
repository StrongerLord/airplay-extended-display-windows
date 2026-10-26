# Runs hidden in its own console next to Start-TV-4K.ps1. When the session
# process ends for any reason (Ctrl+C, window closed, crash), it restores the
# PC mute state and removes the virtual display.
param(
    [Parameter(Mandatory)] [int] $SessionPid,
    [Parameter(Mandatory)] [int] $VddPid,
    [Parameter(Mandatory)] [string] $StateFile
)

. "$PSScriptRoot\pc-audio.ps1"

try {
    Wait-Process -Id $SessionPid -ErrorAction SilentlyContinue
}
finally {
    Restore-PcMute $StateFile
    Get-Process -Id $VddPid -ErrorAction SilentlyContinue |
        Where-Object ProcessName -eq 'parsec-vdd' |
        Stop-Process -Force
}

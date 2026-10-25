@echo off
rem TV as a separate 4K monitor over AirPlay. Settings are the parameters at the
rem top of Start-TV-4K.ps1, e.g.  Start-TV-4K.cmd -TvIp 192.168.1.50 -HwAccel amf
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-TV-4K.ps1" %*
if errorlevel 1 pause

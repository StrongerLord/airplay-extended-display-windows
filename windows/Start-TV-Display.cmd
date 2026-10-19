@echo off
rem ============================================================================
rem  AirPlay extended display for Windows
rem  Adds a virtual monitor (Parsec VDD) and streams it, with audio, to an
rem  AirPlay 2 TV. Stop with Ctrl+C so your audio output gets restored.
rem ============================================================================

rem ---- Settings ---------------------------------------------------------------
rem IP address of your TV (TV settings > Network). Leave empty to auto-discover.
set "TV_IP="
set "BITRATE_KBPS=8000"
set "LATENCY_MS=500"
set "FPS=30"
rem 1 = send sound only to the TV through VB-Audio Virtual Cable, 0 = keep it local too
set "AUDIO_TO_TV_ONLY=1"
rem -----------------------------------------------------------------------------

title AirPlay extended display
set "PATH=C:\Program Files\gstreamer\1.0\msvc_x86_64\bin;%PATH%"
cd /d "%~dp0"

where gst-launch-1.0 >nul 2>&1 || (echo GStreamer not found. Install the 64-bit MSVC runtime, "Complete". & pause & exit /b 1)
if not exist "%~dp0AirPlay.Engine.exe" (echo AirPlay.Engine.exe missing. Run build.cmd first. & pause & exit /b 1)

if "%AUDIO_TO_TV_ONLY%"=="1" (
    for /f "delims=" %%a in ('powershell -NoProfile -ExecutionPolicy Bypass -File audio-output.ps1 current') do set "AUDIO_BEFORE=%%a"
    powershell -NoProfile -ExecutionPolicy Bypass -File audio-output.ps1 cable
)

start "Virtual display" /min "%~dp0parsec-vdd.exe"
timeout /t 3 /nobreak >nul

rem The capture index follows the order GStreamer lists monitors in
set "IDX="
for /f %%i in ('powershell -NoProfile -Command "$i=0; foreach($l in (gst-device-monitor-1.0 Source/Monitor 2>$null)){ if($l -match 'name\s+:\s+(.*)'){ if($matches[1] -eq 'ParsecVDA'){ $i; break }; $i++ } }"') do set "IDX=%%i"
if "%IDX%"=="" (echo Virtual display not found. Is Parsec VDD installed? & goto :cleanup)

set "TARGET="
if not "%TV_IP%"=="" set "TARGET=-target %TV_IP%"
echo Streaming monitor %IDX% to the TV. Don't switch the audio output while it runs.
"%~dp0AirPlay.Engine.exe" %TARGET% -monitor-index %IDX% -fps %FPS% -bitrate %BITRATE_KBPS% -target-latency-ms %LATENCY_MS% -hwaccel none

:cleanup
taskkill /IM parsec-vdd.exe /F >nul 2>&1
if defined AUDIO_BEFORE powershell -NoProfile -ExecutionPolicy Bypass -File audio-output.ps1 restore "%AUDIO_BEFORE%"

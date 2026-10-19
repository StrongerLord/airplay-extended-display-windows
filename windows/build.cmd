@echo off
rem Builds the two executables next to this script. Needs Go 1.25+ in PATH.
cd /d "%~dp0.."
set CGO_ENABLED=0
go build -trimpath -o windows\AirPlay.Engine.exe .\cmd\doubletake || exit /b 1
go build -trimpath -o windows\parsec-vdd.exe .\cmd\parsec-vdd || exit /b 1
echo Done: windows\AirPlay.Engine.exe and windows\parsec-vdd.exe

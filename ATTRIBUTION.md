# Attribution

AirPlay Mirror is derived from [Doubletake](https://github.com/omarroth/doubletake), an AirPlay mirroring and audio sender by Omar Roth.

- Upstream base revision: `5e2f1cbe3e1070bcefec8e549c7baf884727bc00`
- Upstream license: GNU Lesser General Public License v3.0
- Fork additions: Linux fullscreen-stable monitor capture, receiver-volume preservation, JSON discovery, Windows Direct3D 11 capture, Windows WASAPI loopback audio, cross-platform process management, graphical interfaces, packaging, and CI

The original copyright notices and license files are retained.

## This repository

This repository is derived from [AirPlay Mirror](https://github.com/pedrocarv/airplay-mirror)
by pedrocarv, at revision `6dc821bbd4e2eed44f1b14df51d86d150d0f39af`, under the same licenses.

Changes made here:

- Fix: on Windows, screen-capture preparation fell through to the Linux
  PipeWire probe and failed with "pipewiresrc plugin not found"
  (`internal/airplay/capture.go`).
- New: `cmd/parsec-vdd`, a small tool that plugs a virtual monitor into the
  Parsec Virtual Display Driver so the TV can be an *extended* display.
- New: `windows/` launcher, build script and audio-output switcher.

The upstream README is kept in `docs/UPSTREAM-README.md`.

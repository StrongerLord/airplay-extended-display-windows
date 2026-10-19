# AirPlay Extended Display for Windows

**Use your AirPlay TV as a wireless second monitor for your Windows PC — extended, not just mirrored, with audio.**

Like a Mac's *"Use as separate display"*, but from Windows, free and open source.
Works with TVs that support **AirPlay 2** (Hisense VIDAA, Samsung, LG, TCL, Roku, Apple TV…),
even when the PC has **no Wi-Fi card** and is connected by Ethernet: everything goes
through your local network, nothing through the internet.

> Tested with a Hisense 55Q72QU (VIDAA) and a Windows 11 PC on Ethernet:
> 1080p30, ~8 Mbps, audio in sync.

*Español: usa tu tele con AirPlay como segundo monitor inalámbrico de tu PC con Windows (pantalla extendida, con audio), aunque la PC esté por cable al módem.*

## How it works

```
 Windows PC (Ethernet)                                   TV (Wi-Fi)
┌─────────────────────────────┐                        ┌──────────────┐
│ parsec-vdd.exe              │                        │              │
│   └─ virtual monitor ──────►│ D3D11 capture          │   AirPlay 2  │
│ AirPlay.Engine.exe          │ x264 + WASAPI loopback │   receiver   │
│   └─ AirPlay mirroring ─────┼──── local network ────►│              │
└─────────────────────────────┘                        └──────────────┘
```

1. **parsec-vdd** plugs a virtual 1920×1080 monitor into Windows. Windows treats
   it like a real screen, so you can *extend* your desktop onto it and drag windows there.
2. **AirPlay.Engine** (the [AirPlay Mirror](https://github.com/pedrocarv/airplay-mirror) /
   [Doubletake](https://github.com/omarroth/doubletake) sender) captures that monitor
   and streams it to the TV with the AirPlay screen-mirroring protocol, including PIN pairing.
3. Optionally, sound is routed into **VB-Audio Virtual Cable**, so it plays only on the TV.

## Requirements

| What | Why | Get it |
| --- | --- | --- |
| Windows 10/11 64-bit | | |
| An AirPlay 2 TV on the same network | the receiver | TV settings → AirPlay → On |
| GStreamer 1.24+ MSVC 64-bit, **Complete** install | capture and encoding | [gstreamer.freedesktop.org](https://gstreamer.freedesktop.org/download/) or `winget install gstreamerproject.gstreamer` |
| Parsec Virtual Display Driver | the extra monitor | installed with [Parsec](https://parsec.app/), or the standalone [parsec-vdd](https://github.com/nomi-san/parsec-vdd) |
| VB-Audio Virtual Cable *(optional)* | sound only on the TV | [vb-audio.com/Cable](https://vb-audio.com/Cable/) |
| Go 1.25+ | to build | [go.dev/dl](https://go.dev/dl/) |

## Quick start

```bat
git clone https://github.com/StrongerLord/airplay-extended-display-windows
cd airplay-extended-display-windows
windows\build.cmd
```

1. Open `windows\Start-TV-Display.cmd` in a text editor and set `TV_IP` to your TV's IP
   address (or leave it empty to auto-discover).
2. Double-click `windows\Start-TV-Display.cmd`.
3. The first time, the TV shows a **4-digit PIN**: type it in the window. It is remembered.
4. Windows now has an extra monitor. Drag windows onto it — they appear on the TV.
5. Press **Ctrl+C** in the window to stop. This removes the virtual monitor and restores
   your audio output.

## Tuning

Edit the settings block at the top of `Start-TV-Display.cmd`:

| Setting | Default | Notes |
| --- | --- | --- |
| `BITRATE_KBPS` | `8000` | Higher looks sharper but needs a strong Wi-Fi signal at the TV |
| `LATENCY_MS` | `500` | Playout buffer. Raise it if audio stutters, lower it for less lag |
| `FPS` | `30` | 60 is possible with a fast CPU |
| `AUDIO_TO_TV_ONLY` | `1` | `0` keeps sound on the PC too |

## Troubleshooting

- **Choppy audio** → raise `LATENCY_MS` and lower `BITRATE_KBPS`. With 15 Mbps and the
  automatic latency, audio cut out on a Wi-Fi TV; 8 Mbps + 500 ms fixed it.
- **Audio stops mid-session** → the default audio output was changed while streaming.
  WASAPI loopback ends when the device changes; restart the launcher.
- **The TV shows the wrong monitor** → the launcher finds the virtual display by the
  name `ParsecVDA` in `gst-device-monitor-1.0 Source/Monitor`. Run that command to check the order.
- **"pipewiresrc plugin not found" on Windows** → you are running an unpatched upstream
  build. This repository fixes it.
- **Encoding is done on the CPU (x264).** Only NVIDIA hardware encoding is wired in upstream;
  AMD/Intel GPUs fall back to x264. A modern 8-core CPU handles 1080p30 easily.

## Limitations

- Lag is around half a second: great for video, slides, dashboards and browsing, not for gaming.
- Some receivers never worked with the upstream sender (see its issue list).
- Use it on your own network and devices.

## Credits and license

- [Doubletake](https://github.com/omarroth/doubletake) by Omar Roth — the AirPlay sender and FairPlay/pairing implementation.
- [AirPlay Mirror](https://github.com/pedrocarv/airplay-mirror) by pedrocarv — Windows capture and audio.
- [nomi-san/parsec-vdd](https://github.com/nomi-san/parsec-vdd) — documentation of the Parsec VDD control protocol.

Licensed under the **LGPL-3.0-or-later**, with GPL-3.0 terms in `COPYING.GPL`, same as upstream.
See [ATTRIBUTION.md](ATTRIBUTION.md) for exactly what changed here.

Not affiliated with Apple. AirPlay is a trademark of Apple Inc.

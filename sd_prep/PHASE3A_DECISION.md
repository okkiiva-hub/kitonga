# Phase 3a Method Decision

## Target board
`AK3918EV300L_V296P_WIFI` (2023 production), SoC: Anyka AK3918EV300 (ARM926EJ-S),  
Wi-Fi: RTL8188-class module.

---

## The three repos compared

### 1. MuhammedKalkan/Anyka-Camera-Firmware
**Primary target:** AK3918**v200**EN080 (E27 lightbulb cameras).  
**SD "method" reality:** Not a true SD-only boot hack. It places an `update.tar` on the card, which the stock firmware unpacks and flashes. This **writes to flash** — the opposite of what Phase 3a requires. Also requires pre-existing telnet/FTP access to back up first. Not suitable.

### 2. VGerris/Anyka_ak3918_hacking_journey  ← **SELECTED**
**Primary target:** Generic AK3918 family including EV300 variants.  
**Mechanism:** Exploits a check in the stock `/usr/sbin/service.sh`: if a `Factory/` folder exists on the SD card, the script runs `Factory/config.sh` from the card instead of the normal cloud boot sequence. The config launches telnet and the `gergehack.sh` payload — **all from the SD card, nothing written to flash**.  
`rootfs_modified=0` in `gergesettings.txt` keeps it purely SD-overlay mode.  
**Wi-Fi:** Explicitly lists RTL8188 as supported.  
**Sensor:** `sensor_kern_module` in the config lets us specify the correct `.ko` for whatever image sensor is on this board — this flexibility matters because we don't yet know which sensor variant the V296P uses.  
**Reversal:** Pull SD card → stock behavior. Zero flash writes.

### 3. ThatUsernameAlreadyExist/TECKIN-TC100-Anyka-AK3918-camera-hacks
**Primary target:** Teckin TC100 specifically (one product SKU).  
**SoC match:** AK3918 v300 — which matches "EV300" at the silicon level — but all the binaries, PTZ commands, and sensor assumptions are tuned for the Teckin TC100 PCB. Using these binaries on a different PCB risks a sensor mismatch that yields a black or garbled stream. Good fallback if VGerris fails; try it second.

---

## Why VGerris wins

| Criterion | VGerris | TECKIN |
|-----------|---------|--------|
| SD-only, no flash writes | ✓ | ✓ |
| Works on generic AK3918EV300 (not one SKU) | ✓ | ✗ (Teckin TC100 only) |
| Configurable sensor module | ✓ | ✗ (hardcoded for TC100) |
| RTL8188 Wi-Fi explicitly supported | ✓ | unknown |
| Telnet enabled by default | ✓ | ✓ |
| RTSP stream | ✓ (`rtsp://<ip>:554/vs0`) | ✓ |
| PTZ support | ✓ | unclear |

---

## SD card format specification

**FAT32, 32K (32768-byte) allocation unit size.**

- Both VGerris and TECKIN documentation call out smaller allocation sizes as causing instability on these cameras.
- macOS Disk Utility automatically uses 32K clusters for FAT32 on cards ≤32 GB — no manual flag needed if using the GUI.
- Terminal command: `diskutil eraseDisk FAT32 ANKYA_CAM MBRFormat /dev/diskN`

Card size: any microSD ≤32 GB works. 8 GB is plenty; the hack payload is small.

---

## What goes on the card (and nothing else)

```
SD card root/
├── Factory/          ← triggers the exploit in stock service.sh
│   └── config.sh     ← launches telnetd + gergehack.sh
└── anyka_hack/       ← the payload (RTSP app, PTZ daemon, web UI, etc.)
    ├── gergehack.sh
    ├── gergesettings.txt   ← YOU EDIT THIS (WiFi creds + sensor module)
    └── [binaries: libre_anyka_app, ptz, web_interface, ffmpeg, curl, …]
```

No other files. No partition table changes. No flash writes.

---

## Key unknown: sensor module

The `sensor_kern_module` line in `gergesettings.txt` must match the image sensor soldered on this board. We don't know yet which one it is (H62, H63, GC1084, GC1054, GC1034 are all found on 2022-2023 AK3918 boards).

**Plan:** Set `sensor_kern_module=/usr/modules/sensor_h63.ko` as the initial guess (most common on 2022-2023 PTZ domes). After first telnet login, run `ls /usr/modules/sensor_*.ko` to see what's actually present, then update `gergesettings.txt` and reboot if the stream is black.

---

## Fallback order if VGerris fails

1. **VGerris with alternate sensor module** — try H62, GC1084, GC1054 in turn.
2. **TECKIN TC100 repo** — same SD exploit concept, different binaries.
3. **UART console** — 115200 baud on the labeled TX/RX pads, using ESP32 as 3.3V bridge. Back up full flash via U-Boot before touching anything.

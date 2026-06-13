# Phase 3a — SD Card Liberation, Cam A

## Method selected: VGerris/Anyka_ak3918_hacking_journey

See `PHASE3A_DECISION.md` for full reasoning. Short version: VGerris is the right match for the AK3918EV300 variant, generic across sensor configs, purely SD-run, zero flash writes.

## Files in this directory

| File | Purpose |
|------|---------|
| `prep_sd_vgerris.sh` | Clones VGerris repo, assembles `sd_staging/`, leaves WiFi as placeholder |
| `FORMAT_INSTRUCTIONS.md` | How to format SD card (FAT32, 32K alloc) on macOS |
| `after_boot_telnet.sh` | Post-boot: RTSP probe + telnet command guide + backup instructions |
| `sd_staging/` | Created by prep script — contents to copy to SD card |
| `PHASE3A_DECISION.md` | Full method comparison and reasoning |

## Workflow

```
MacBook                         Human
  │                               │
  ├─ ./prep_sd_vgerris.sh         │
  ├─ edit gergesettings.txt       │
  │   (fill WiFi creds)           │
  ├─ See FORMAT_INSTRUCTIONS.md   │
  │                               ├─ Format SD card (FAT32, 32K)
  │                               ├─ Copy Factory/ + anyka_hack/ to SD root
  │                               ├─ Insert SD into Cam A
  │                               └─ Power on Cam A
  │                               │
  ├─ Find camera IP               │
  │   nmap -sn 192.168.x.0/24     │
  │                               │
  └─ ./after_boot_telnet.sh <ip>  │
      (RTSP probe + backup guide) │
```

## Reversal

Pull SD card → reboot Cam A → stock firmware, no changes made.

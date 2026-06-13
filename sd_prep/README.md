# SD Card Prep (Phase 3)

This directory will hold the SD-card contents for the no-solder camera liberation.

## Which method to use?

| Method | Repo | When to use |
|--------|------|-------------|
| MuhammedKalkan factory SD | MuhammedKalkan/Anyka-Camera-Firmware | First try — runs from SD, doesn't touch flash |
| VGerris fuller toolkit | VGerris/Anyka_ak3918_hacking_journey | If you want PTZ + web UI |
| ThatUsernameAlreadyExist | TECKIN-TC100-Anyka-AK3918-camera-hacks | If above fail; good wpa_supplicant approach |

## Steps (filled in after Phase 2 confirms firmware variant)

1. Clone the matching repo onto the MacBook
2. Format a micro-SD as FAT32 (≤32 GB card recommended)
3. Copy the correct folder contents to root of SD
4. Edit `wpa_supplicant.conf` with your home Wi-Fi SSID/password
5. Hand to human: insert SD, power-cycle camera
6. Connect via telnet (root, no password) once the camera boots
7. Back up: `tar -czf /mnt/sdcard/backup_cam1.tar.gz /usr /etc`
8. Confirm RTSP stream works: `ffprobe rtsp://<ip>:554/stream`

## Reversal

Pull SD card and reboot camera → returns to stock firmware. No flash writes.

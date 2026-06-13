# SD Card Format Instructions

**Required:** FAT32, 32K (32768 byte) allocation unit size.

Both VGerris and TECKIN documentation flag smaller allocation sizes as causing instability. Use exactly 32K.

---

## macOS (Disk Utility GUI)

1. Insert SD card.
2. Open **Disk Utility** (Applications → Utilities → Disk Utility).
3. Select the SD card in the left sidebar — select the **top-level device** (e.g. "SAMSUNG 32 GB"), not a partition under it.
4. Click **Erase**.
5. Set:
   - **Name:** `ANKYA_CAM` (or anything short, no spaces)
   - **Format:** `MS-DOS (FAT)`  ← this is FAT32
   - **Scheme:** `Master Boot Record`
6. Click **Erase**.

> Disk Utility on macOS always uses 32K cluster size for FAT32 cards ≤32 GB — no extra step needed.

---

## macOS (Terminal — precise control)

```bash
# Find your SD card's disk identifier first:
diskutil list

# It will look like /dev/disk2 or /dev/disk3
# IMPORTANT: use the disk number for YOUR SD card, not disk0 or disk1

# Unmount (replace diskN with your number):
diskutil unmountDisk /dev/diskN

# Erase as FAT32 with 32K cluster (32768 bytes):
diskutil eraseDisk FAT32 ANKYA_CAM MBRFormat /dev/diskN
```

---

## After formatting

The SD card root should be completely empty. Then copy from staging:

```bash
SD=/Volumes/ANKYA_CAM   # adjust if macOS named it differently

cp -r sd_prep/sd_staging/Factory    "$SD/"
cp -r sd_prep/sd_staging/anyka_hack "$SD/"

# Verify:
ls "$SD"
# Should show: Factory   anyka_hack

# Eject cleanly before removing:
diskutil eject "$SD"
```

---

## What NOT to put on the card

- Do not copy `PREFLIGHT_CHECKLIST.txt` — it's for your reference only
- Do not add any other files unless a specific script asks for them
- The camera's `service.sh` detects the `Factory/` folder as its trigger — keep the root clean

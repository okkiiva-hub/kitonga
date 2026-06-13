#!/usr/bin/env bash
# after_boot_telnet.sh — Phase 3a post-boot: verify, discover sensor, back up, get RTSP URL
# Run on the MacBook AFTER camera boots with SD card inserted.
# Usage: ./after_boot_telnet.sh <camera-ip>
set -e

IP="${1:-}"
if [ -z "$IP" ]; then
    echo "Usage: $0 <camera-ip>"
    echo "Find the camera IP in your router's client list, or:"
    echo "  nmap -sn 192.168.1.0/24 | grep -A2 'Nmap scan'"
    exit 1
fi

BACKUP_DIR="$(dirname "$0")/../backups/cam_a_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "=== Post-boot telnet checks for Cam A at $IP ==="
echo ""

# --- 1. Reachability ---
echo "--- Ping test ---"
ping -c 3 "$IP" || { echo "Camera not reachable at $IP"; exit 1; }

# --- 2. Port check ---
echo ""
echo "--- Port scan ---"
nmap -p 21,23,80,554,8080 "$IP" 2>&1 | grep -E "PORT|open|closed|filtered"

# --- 3. RTSP probe ---
echo ""
echo "--- RTSP stream test ---"
RTSP_URLS=(
    "rtsp://$IP:554/vs0"
    "rtsp://$IP:554/vs1"
    "rtsp://$IP:554/video0_unicast"
    "rtsp://$IP:554/video1_unicast"
    "rtsp://$IP:554/stream"
)
WORKING_RTSP=""
for url in "${RTSP_URLS[@]}"; do
    echo -n "  $url … "
    if ffprobe -v quiet -rtsp_transport tcp "$url" -show_streams 2>&1 | grep -q "codec_type"; then
        echo "WORKING ✓"
        WORKING_RTSP="$url"
    else
        echo "no response"
    fi
done

# --- 4. Print telnet commands for human to run ---
echo ""
echo "========================================================"
echo "MANUAL TELNET STEPS — run these yourself:"
echo "========================================================"
echo ""
echo "  telnet $IP"
echo "  # Login: root   Password: (just press Enter — no password)"
echo ""
echo "  # 1. List available sensor modules (to confirm gergesettings.txt):"
echo "  ls /usr/modules/sensor_*.ko"
echo ""
echo "  # 2. Check running processes:"
echo "  ps | grep -E 'anyka|libre|rtsp|telnet'"
echo ""
echo "  # 3. Back up key directories to SD card:"
echo "  tar -czf /mnt/sdcard/backup_cam_a_usr.tar.gz /usr 2>/dev/null"
echo "  tar -czf /mnt/sdcard/backup_cam_a_etc.tar.gz /etc/jffs2 2>/dev/null"
echo "  cat /proc/version   # kernel version"
echo "  cat /proc/cpuinfo   # confirm AK3918"
echo "  cat /etc/fw_version 2>/dev/null || cat /etc/version 2>/dev/null  # firmware ver"
echo ""
echo "  # 4. Confirm Wi-Fi chip:"
echo "  lsmod | grep -i 8188"
echo "  dmesg | grep -i wifi | tail -5"
echo ""
echo "========================================================"
echo ""

if [ -n "$WORKING_RTSP" ]; then
    echo "✓ WORKING RTSP URL: $WORKING_RTSP"
    echo ""
    echo "Test playback (press q to quit):"
    echo "  ffplay -rtsp_transport tcp '$WORKING_RTSP'"
    echo ""
    echo "Stream info:"
    ffprobe -v quiet -print_format json -show_streams -rtsp_transport tcp "$WORKING_RTSP" 2>/dev/null \
        | python3 -c "
import sys, json
d = json.load(sys.stdin)
for s in d.get('streams', []):
    print(f'  [{s.get(\"index\")}] {s.get(\"codec_type\")} {s.get(\"codec_name\")} {s.get(\"width\",\"?\")}x{s.get(\"height\",\"?\")} @ {s.get(\"avg_frame_rate\",\"?\")}')
" 2>/dev/null || true
    echo ""
    echo "To connect watcher_local.py to this camera:"
    echo "  SOURCE='$WORKING_RTSP' CAMERA_LABEL=cam_a python3 watcher_local.py"
else
    echo "No RTSP stream found yet."
    echo "After telnet, check if libre_anyka_app is running: ps | grep libre"
    echo "If not, check gergesettings.txt sensor_kern_module matches ls /usr/modules/sensor_*.ko"
fi

echo ""
echo "After collecting backup files from SD card, copy them to:"
echo "  $BACKUP_DIR/"

#!/usr/bin/env bash
# scan_camera.sh — Phase 2: discover and probe a camera on the LAN
# Usage: ./scan_camera.sh <camera-ip>
# Or leave blank to scan the whole subnet (requires nmap).

set -e

IP="${1:-}"
SUBNET="${2:-192.168.1.0/24}"

if ! command -v nmap &>/dev/null; then
    echo "nmap not found. Install: brew install nmap"
    exit 1
fi

if [ -z "$IP" ]; then
    echo "No IP provided — scanning subnet $SUBNET for hosts …"
    echo "(This may take 30–60 seconds)"
    nmap -sn "$SUBNET" | grep -E "Nmap scan|report for"
    echo ""
    echo "Re-run with a specific IP:  $0 <ip>"
    exit 0
fi

echo "=== Scanning camera at $IP ==="
echo ""

echo "--- Port scan (common camera ports) ---"
nmap -p 21,23,80,554,8080,8899,34567 "$IP" 2>&1
echo ""

echo "--- HTTP banner (port 80) ---"
curl -s --max-time 5 "http://$IP/" | head -30 2>/dev/null || echo "(no HTTP response)"
echo ""

echo "--- HTTP banner (port 8080) ---"
curl -s --max-time 5 "http://$IP:8080/" | head -30 2>/dev/null || echo "(no HTTP on 8080)"
echo ""

echo "--- ONVIF device info probe ---"
curl -s --max-time 5 -X POST \
    -H 'Content-Type: application/soap+xml' \
    -d '<?xml version="1.0"?><s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"><s:Body><tds:GetDeviceInformation xmlns:tds="http://www.onvif.org/ver10/device/wsdl"/></s:Body></s:Envelope>' \
    "http://$IP:80/onvif/device_service" 2>/dev/null | head -40 || echo "(no ONVIF on :80)"
echo ""

echo "--- Try common RTSP stream URLs ---"
RTSP_PATHS=(
    "rtsp://$IP:554/stream"
    "rtsp://$IP:554/live/ch0"
    "rtsp://$IP:554/ch01.264"
    "rtsp://$IP:554/video1"
    "rtsp://$IP:554/h264/ch1/main/av_stream"
    "rtsp://admin:@$IP:554/stream"
    "rtsp://admin:admin@$IP:554/stream"
)

for url in "${RTSP_PATHS[@]}"; do
    echo -n "  $url … "
    result=$(ffprobe -v quiet -print_format json -show_streams \
        -rtsp_transport tcp "$url" 2>&1 | head -5)
    if echo "$result" | grep -q '"codec_type"'; then
        echo "WORKING ✓"
        echo "    Stream info:"
        ffprobe -v quiet -print_format json -show_streams -rtsp_transport tcp "$url" 2>/dev/null \
            | python3 -c "
import sys, json
d = json.load(sys.stdin)
for s in d.get('streams', []):
    print(f\"    [{s.get('index')}] {s.get('codec_type')} {s.get('codec_name')} {s.get('width','?')}x{s.get('height','?')} @ {s.get('avg_frame_rate','?')}\")
"
    else
        echo "no response"
    fi
done

echo ""
echo "=== Scan complete ==="

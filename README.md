# Kitonga — Local-Only AI Camera System

De-cloud 4x AK3918EV300 Wi-Fi cameras. Local RTSP stream → local AI inference on MacBook CPU. No cloud. No API cost.

## Quick start (Phase 1 — webcam test)

```bash
# On the MacBook:
chmod +x setup_phase1.sh
./setup_phase1.sh

# Run against built-in webcam:
python3 watcher_local.py

# If webcam index is wrong, list devices first:
ffmpeg -f avfoundation -list_devices true -i ""
# Then:
SOURCE=1 python3 watcher_local.py
```

## Configuration (environment variables)

| Variable | Default | Description |
|----------|---------|-------------|
| `SOURCE` | `0` | Webcam index or RTSP URL |
| `INTERVAL` | `2.0` | Seconds between frames |
| `MOTION_THRESHOLD` | `0.02` | Fraction of pixels that must change |
| `MODEL_PROTOTXT` | `models/MobileNetSSD_deploy.prototxt` | Tier 1 model config |
| `MODEL_WEIGHTS` | `models/MobileNetSSD_deploy.caffemodel` | Tier 1 model weights |
| `DETECTION_CONFIDENCE` | `0.5` | Min confidence for object alerts |
| `ALERT_CLASSES` | `person` | Comma-separated classes to alert on |
| `SAVE_FRAMES` | `true` | Save JPEG captures on events |
| `SAVE_DIR` | `captures/` | Where to save frames |
| `CAMERA_LABEL` | `cam0` | Label prefix for filenames |

## Point at a real camera (Phase 4)

```bash
SOURCE="rtsp://192.168.1.100:554/stream" CAMERA_LABEL=cam1 python3 watcher_local.py
```

## Tier summary

| Tier | Tech | What it does | Requirement |
|------|------|--------------|-------------|
| 0 | Pillow + numpy | Motion detection | `pip install pillow numpy` + ffmpeg |
| 1 | OpenCV DNN + MobileNet-SSD | Person / object labels | opencv-python + model files in `models/` |
| 2 | llama.cpp + multimodal model | Natural-language descriptions | Built llama.cpp (optional, slow) |

Tier 2 is intentionally not wired in yet — it requires building llama.cpp from source, which is a separate phase.

## Files

```
watcher_local.py    Primary watcher (extend this)
watcher.py          Legacy API version (reference only)
setup_phase1.sh     Bootstrap script for macOS Catalina
scan_camera.sh      Phase 2: LAN camera discovery & RTSP probe
sd_prep/            Phase 3: SD card liberation contents
models/             MobileNet-SSD model files (downloaded by setup script)
captures/           Saved event frames (created at runtime)
```

## Phase log

- [ ] Phase 1: Local pipeline on webcam (Tier 0 + Tier 1)
- [ ] Phase 2: Discover camera on LAN, identify stock stream
- [ ] Phase 3: SD liberation (if stock has no local stream)
- [ ] Phase 4: Connect watcher to all 4 cameras

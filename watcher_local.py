#!/usr/bin/env python3
"""
watcher_local.py — fully-local AI camera watcher
Tier 0: motion detection (Pillow + numpy) — always active
Tier 1: object detection (OpenCV DNN + MobileNet-SSD) — enabled when model files are present
No cloud, no API, no per-use cost.
"""

import os
import sys
import time
import datetime
import subprocess
import tempfile
import logging

# ---------------------------------------------------------------------------
# USER CONFIG — edit these for your setup
# ---------------------------------------------------------------------------

# Video source: webcam index for testing, RTSP URL for real cameras
# Examples:
#   SOURCE = "0"                           # built-in Mac webcam (avfoundation index)
#   SOURCE = "rtsp://192.168.1.100:554/stream"  # camera RTSP URL
SOURCE = os.environ.get("CAMERA_SOURCE", "0")

# How often to grab a frame (seconds)
INTERVAL = float(os.environ.get("INTERVAL", "2.0"))

# Motion sensitivity: fraction of pixels that must change to count as motion
# Lower = more sensitive (0.01 = 1% of pixels)
MOTION_THRESHOLD = float(os.environ.get("MOTION_THRESHOLD", "0.02"))

# Tier 1 — MobileNet-SSD model paths (leave empty to disable)
# Download from: https://github.com/chuanqi305/MobileNet-SSD
# Place files in models/ directory
MODEL_PROTOTXT = os.environ.get(
    "MODEL_PROTOTXT",
    os.path.join(os.path.dirname(__file__), "models", "MobileNetSSD_deploy.prototxt")
)
MODEL_WEIGHTS = os.environ.get(
    "MODEL_WEIGHTS",
    os.path.join(os.path.dirname(__file__), "models", "MobileNetSSD_deploy.caffemodel")
)

# Minimum confidence for Tier 1 detections (0.0–1.0)
DETECTION_CONFIDENCE = float(os.environ.get("DETECTION_CONFIDENCE", "0.5"))

# Classes to alert on (empty list = all classes)
# Common classes: "person", "car", "dog", "cat", "bicycle", "motorbike"
ALERT_CLASSES = [c.strip() for c in os.environ.get("ALERT_CLASSES", "person").split(",") if c.strip()]

# Save captured frames to disk on motion/detection events
SAVE_FRAMES = os.environ.get("SAVE_FRAMES", "true").lower() in ("1", "true", "yes")
SAVE_DIR = os.environ.get("SAVE_DIR", os.path.join(os.path.dirname(__file__), "captures"))

# Camera label (for logs / filenames)
CAMERA_LABEL = os.environ.get("CAMERA_LABEL", "cam0")

# ---------------------------------------------------------------------------
# MobileNet-SSD class labels (COCO-adjacent, 21 classes)
# ---------------------------------------------------------------------------
MOBILENET_CLASSES = [
    "background", "aeroplane", "bicycle", "bird", "boat",
    "bottle", "bus", "car", "cat", "chair", "cow",
    "diningtable", "dog", "horse", "motorbike", "person",
    "pottedplant", "sheep", "sofa", "train", "tvmonitor",
]

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-7s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("watcher")

# ---------------------------------------------------------------------------
# Lazy imports (fail gracefully so Tier 0 still works without opencv)
# ---------------------------------------------------------------------------
try:
    from PIL import Image
    import numpy as np
    PILLOW_OK = True
except ImportError:
    log.error("Pillow/numpy not found. Run:  pip install pillow numpy")
    sys.exit(1)

try:
    import cv2
    CV2_OK = True
except ImportError:
    CV2_OK = False
    log.info("opencv-python not installed — Tier 1 object detection disabled.")
    log.info("  Install: pip install opencv-python==4.8.1.78")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
prev_frame_arr = None   # numpy array of previous frame (greyscale)
net = None              # cv2 DNN network (loaded once)
tier1_enabled = False


def load_model():
    """Load MobileNet-SSD if model files exist and cv2 is available."""
    global net, tier1_enabled
    if not CV2_OK:
        return
    if not os.path.isfile(MODEL_PROTOTXT) or not os.path.isfile(MODEL_WEIGHTS):
        log.info("Tier 1 model files not found — running Tier 0 only.")
        log.info("  Expected: %s", MODEL_PROTOTXT)
        log.info("  Expected: %s", MODEL_WEIGHTS)
        return
    log.info("Loading MobileNet-SSD model …")
    net = cv2.dnn.readNetFromCaffe(MODEL_PROTOTXT, MODEL_WEIGHTS)
    tier1_enabled = True
    log.info("Tier 1 object detection ENABLED (confidence ≥ %.0f%%)", DETECTION_CONFIDENCE * 100)
    if ALERT_CLASSES:
        log.info("Alerting on classes: %s", ", ".join(ALERT_CLASSES))
    else:
        log.info("Alerting on ALL detected classes")


def grab_frame(source: str) -> "Image.Image | None":
    """Use ffmpeg to grab a single frame from the source. Returns PIL Image or None."""
    is_webcam = source.isdigit()

    if is_webcam:
        cmd = [
            "ffmpeg", "-loglevel", "quiet",
            "-f", "avfoundation",
            "-framerate", "30",
            "-i", source,
            "-vframes", "1",
            "-f", "image2pipe",
            "-vcodec", "mjpeg",
            "pipe:1",
        ]
    else:
        cmd = [
            "ffmpeg", "-loglevel", "quiet",
            "-rtsp_transport", "tcp",
            "-i", source,
            "-vframes", "1",
            "-f", "image2pipe",
            "-vcodec", "mjpeg",
            "pipe:1",
        ]

    try:
        result = subprocess.run(cmd, capture_output=True, timeout=10)
        if result.returncode != 0 or not result.stdout:
            return None
        import io
        return Image.open(io.BytesIO(result.stdout)).convert("RGB")
    except subprocess.TimeoutExpired:
        log.warning("ffmpeg timed out grabbing frame")
        return None
    except Exception as exc:
        log.warning("Frame grab error: %s", exc)
        return None


def detect_motion(img: "Image.Image") -> "tuple[bool, float]":
    """
    Compare current frame to previous. Returns (motion_detected, changed_fraction).
    Updates global prev_frame_arr.
    """
    global prev_frame_arr

    grey = img.convert("L").resize((320, 240), Image.LANCZOS)
    arr = np.array(grey, dtype=np.float32)

    if prev_frame_arr is None:
        prev_frame_arr = arr
        return False, 0.0

    diff = np.abs(arr - prev_frame_arr)
    changed = float(np.mean(diff > 25))   # pixels that shifted by >25 intensity levels
    prev_frame_arr = arr
    return changed >= MOTION_THRESHOLD, changed


def detect_objects(img: "Image.Image") -> "list[tuple[str, float]]":
    """
    Run MobileNet-SSD on the image. Returns list of (label, confidence) for
    detections above DETECTION_CONFIDENCE.
    """
    if not tier1_enabled or net is None:
        return []

    # Convert PIL → numpy BGR for cv2
    img_cv = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
    h, w = img_cv.shape[:2]

    blob = cv2.dnn.blobFromImage(
        cv2.resize(img_cv, (300, 300)),
        0.007843, (300, 300), 127.5
    )
    net.setInput(blob)
    detections = net.forward()

    results = []
    for i in range(detections.shape[2]):
        conf = float(detections[0, 0, i, 2])
        if conf < DETECTION_CONFIDENCE:
            continue
        class_id = int(detections[0, 0, i, 1])
        if class_id < len(MOBILENET_CLASSES):
            label = MOBILENET_CLASSES[class_id]
            results.append((label, conf))

    return results


def save_frame(img: "Image.Image", tag: str = "") -> str:
    """Save frame to SAVE_DIR. Returns filepath."""
    os.makedirs(SAVE_DIR, exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    fname = f"{CAMERA_LABEL}_{ts}{('_' + tag) if tag else ''}.jpg"
    path = os.path.join(SAVE_DIR, fname)
    img.save(path, "JPEG", quality=85)
    return path


def should_alert(detections: "list[tuple[str, float]]") -> "list[tuple[str, float]]":
    """Filter detections to only those matching ALERT_CLASSES (or all if list is empty)."""
    if not ALERT_CLASSES:
        return detections
    return [(label, conf) for label, conf in detections if label in ALERT_CLASSES]


def main():
    log.info("=" * 60)
    log.info("watcher_local.py starting")
    log.info("Source  : %s", SOURCE)
    log.info("Interval: %.1fs  |  Motion threshold: %.1f%%", INTERVAL, MOTION_THRESHOLD * 100)
    log.info("=" * 60)

    load_model()

    if SAVE_FRAMES:
        os.makedirs(SAVE_DIR, exist_ok=True)
        log.info("Saving captures to: %s", SAVE_DIR)

    consecutive_errors = 0

    while True:
        try:
            img = grab_frame(SOURCE)

            if img is None:
                consecutive_errors += 1
                log.warning("Could not grab frame (attempt %d). Source: %s", consecutive_errors, SOURCE)
                if consecutive_errors == 3:
                    log.warning(
                        "Tip — list available devices with:\n"
                        "  ffmpeg -f avfoundation -list_devices true -i \"\""
                    )
                time.sleep(INTERVAL)
                continue

            consecutive_errors = 0
            motion, changed_pct = detect_motion(img)

            if not motion:
                time.sleep(INTERVAL)
                continue

            # --- Motion detected ---
            log.info("MOTION  %.1f%% pixels changed", changed_pct * 100)

            detections = detect_objects(img)
            alerts = should_alert(detections)

            if detections:
                labels_str = ", ".join(f"{lbl} ({conf:.2f})" for lbl, conf in detections)
                log.info("OBJECTS %s", labels_str)

            if alerts:
                tag_parts = [lbl for lbl, _ in alerts]
                tag = "_".join(tag_parts[:3])
                log.info("ALERT   %s", ", ".join(f"{lbl} ({conf:.2f})" for lbl, conf in alerts))
                if SAVE_FRAMES:
                    path = save_frame(img, tag)
                    log.info("SAVED   %s", path)
            elif SAVE_FRAMES and not tier1_enabled:
                # Tier 0 only — save all motion frames
                path = save_frame(img, "motion")
                log.info("SAVED   %s", path)

        except KeyboardInterrupt:
            log.info("Stopped by user.")
            break
        except Exception as exc:
            log.error("Unexpected error: %s", exc, exc_info=True)
            time.sleep(INTERVAL)

        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()

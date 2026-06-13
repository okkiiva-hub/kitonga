#!/usr/bin/env bash
# setup_phase1.sh — Phase 1 bootstrap for macOS Catalina (10.15), Intel CPU
# Run this on the MacBook. Safe to re-run.
set -e

echo "=== Phase 1: Local pipeline setup ==="

# --- 1. Check Homebrew ---
if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Install it from https://brew.sh then re-run this script."
    exit 1
fi
echo "[OK] Homebrew: $(brew --version | head -1)"

# --- 2. ffmpeg ---
if ! command -v ffmpeg &>/dev/null; then
    echo "Installing ffmpeg via Homebrew …"
    brew install ffmpeg
fi
echo "[OK] ffmpeg: $(ffmpeg -version 2>&1 | head -1)"

# --- 3. Python 3 ---
if ! command -v python3 &>/dev/null; then
    echo "python3 not found. Installing via Homebrew …"
    brew install python@3.11
fi
PYTHON=$(command -v python3.11 || command -v python3)
echo "[OK] Python: $($PYTHON --version)"

# --- 4. pip packages ---
echo "Installing Python packages …"
$PYTHON -m pip install --upgrade pip --quiet
$PYTHON -m pip install pillow numpy --quiet
echo "[OK] pillow + numpy installed"

# Try opencv; pin 4.8.1.78 which has Catalina wheels
if ! $PYTHON -c "import cv2" 2>/dev/null; then
    echo "Installing opencv-python (pinning 4.8.1.78 for Catalina compatibility) …"
    $PYTHON -m pip install "opencv-python==4.8.1.78" --quiet || \
        $PYTHON -m pip install "opencv-python==4.5.5.64" --quiet || \
        echo "WARNING: opencv install failed — Tier 1 detection will be disabled."
fi

if $PYTHON -c "import cv2" 2>/dev/null; then
    echo "[OK] opencv-python: $($PYTHON -c 'import cv2; print(cv2.__version__)')"
else
    echo "[WARN] opencv not available — only Tier 0 motion detection will run."
fi

# --- 5. Download MobileNet-SSD model files ---
MODELS_DIR="$(dirname "$0")/models"
mkdir -p "$MODELS_DIR"

PROTOTXT="$MODELS_DIR/MobileNetSSD_deploy.prototxt"
CAFFEMODEL="$MODELS_DIR/MobileNetSSD_deploy.caffemodel"

if [ ! -f "$PROTOTXT" ]; then
    echo "Downloading MobileNetSSD_deploy.prototxt …"
    curl -fsSL \
        "https://raw.githubusercontent.com/chuanqi305/MobileNet-SSD/master/MobileNetSSD_deploy.prototxt" \
        -o "$PROTOTXT" || echo "WARNING: prototxt download failed — check your internet connection."
fi

if [ ! -f "$CAFFEMODEL" ]; then
    echo "Downloading MobileNetSSD_deploy.caffemodel (~23 MB) …"
    curl -fsSL \
        "https://github.com/chuanqi305/MobileNet-SSD/raw/master/MobileNetSSD_deploy.caffemodel" \
        -o "$CAFFEMODEL" || echo "WARNING: caffemodel download failed — Tier 1 will be disabled."
fi

if [ -f "$PROTOTXT" ] && [ -f "$CAFFEMODEL" ]; then
    echo "[OK] MobileNet-SSD model files present in models/"
else
    echo "[WARN] Model files missing — Tier 1 disabled until they're downloaded."
fi

echo ""
echo "=== Setup complete. Next steps: ==="
echo ""
echo "1. Grant macOS camera permission:"
echo "   Run:  python3 watcher_local.py"
echo "   macOS will prompt for camera access — click Allow."
echo ""
echo "2. If frames are black or you get errors, list devices:"
echo "   ffmpeg -f avfoundation -list_devices true -i \"\""
echo "   Then set SOURCE=<index> in watcher_local.py or via env:"
echo "   SOURCE=1 python3 watcher_local.py"
echo ""
echo "3. Watch for output like:"
echo "   MOTION  3.2% pixels changed"
echo "   OBJECTS person (0.87), chair (0.61)"
echo "   ALERT   person (0.87)"
echo ""

"""
EcoSight Server Configuration
"""

# ─── Server ──────────────────────────────────────────────────────
WEBSOCKET_HOST = "0.0.0.0"
WEBSOCKET_PORT = 8765

# ─── Camera ──────────────────────────────────────────────────────
CAMERA_INDEX = 0          # Default webcam
FRAME_WIDTH = 640
FRAME_HEIGHT = 480

# ─── Phase 1: Reflex Layer ───────────────────────────────────────
YOLO_MODEL = "yolov8n.pt"            # Nano model for speed
YOLO_CONFIDENCE_THRESHOLD = 0.60      # 60% — filters "ghost" detections
PHASE1_TARGET_FPS = 10                # 10 FPS target

# Frame Skipping — process every Nth frame.
# Camera runs at ~30fps; skip=3 → ~10 processed frames/sec.
# Skipped frames are still grabbed to keep the buffer fresh.
FRAME_SKIP = 3

# Debounce / Anti‑Spam — prevents TTS from talking over itself
DEBOUNCE_COOLDOWN_SEC = 3.0           # seconds before re-alerting same hazard
DEBOUNCE_GLOBAL_MIN_SEC = 1.0         # minimum gap between ANY two alerts
DEBOUNCE_DISTANCE_CHANGE = 0.5        # re-alert if distance changes by >0.5m

# Hazard classes we care about (COCO class names + custom)
# COCO IDs: person=0, bicycle=1, car=2, ...
# We'll map COCO detections to our hazard categories
HAZARD_CLASSES = {
    0: "person",
    56: "chair",        # potential obstacle
    60: "dining table",  # potential obstacle
    39: "bottle",        # potential obstacle
    13: "bench",         # potential obstacle
    10: "fire hydrant",  # potential obstacle
    11: "stop sign",     # navigation aid
    9:  "traffic light",  # navigation aid
}

# Monocular depth estimation calibration
# Focal_Constant = Known_Distance * Pixel_Height_at_Known_Distance
# Calibrated at 1 meter with a reference object ~200px tall
FOCAL_CONSTANT = 200.0

# Directionality zones (percentage of frame width)
LEFT_ZONE_END = 0.33
RIGHT_ZONE_START = 0.66

# ─── Phase 2: Context Layer ──────────────────────────────────────
FLORENCE2_MODEL_ID = "microsoft/Florence-2-base"
FLORENCE2_TASKS = {
    "caption": "<DETAILED_CAPTION>",
    "vqa": "<VQA>",
    "ocr": "<OCR>",
    "od": "<OD>",
}

"""
EcoSight Phase 1 — Reflex Layer
Real-time hazard detection, depth estimation, and directionality.
"""

import cv2
import numpy as np
from ultralytics import YOLO
import config


class ReflexLayer:
    """Continuous real-time hazard detection engine."""

    def __init__(self):
        print("[Phase1] Loading YOLOv8 model...")
        self.model = YOLO(config.YOLO_MODEL)
        self.focal_constant = config.FOCAL_CONSTANT
        self.confidence_threshold = config.YOLO_CONFIDENCE_THRESHOLD
        self.hazard_classes = config.HAZARD_CLASSES
        print("[Phase1] YOLOv8 model loaded ✓")

    # ── Public API ─────────────────────────────────────────────
    def process_frame(self, frame: np.ndarray) -> list[dict]:
        """
        Process a single frame and return a list of detected hazards.
        Each hazard dict:
            { "hazard": str, "direction": str, "distance": float, "confidence": float }
        """
        results = self.model(frame, verbose=False, conf=self.confidence_threshold)
        detections = []

        for result in results:
            boxes = result.boxes
            if boxes is None:
                continue
            for box in boxes:
                cls_id = int(box.cls[0])
                if cls_id not in self.hazard_classes:
                    continue

                conf = float(box.conf[0])
                x1, y1, x2, y2 = box.xyxy[0].tolist()

                hazard_name = self.hazard_classes[cls_id]
                direction = self._get_direction(x1, x2, frame.shape[1])
                distance = self._estimate_distance(y1, y2)

                detections.append({
                    "hazard": hazard_name,
                    "direction": direction,
                    "distance": round(distance, 1),
                    "confidence": round(conf, 2),
                })

        # Sort by distance — closest hazard first
        detections.sort(key=lambda d: d["distance"])
        return detections

    # ── Private Helpers ────────────────────────────────────────
    def _get_direction(self, x1: float, x2: float, frame_width: int) -> str:
        """Map bounding box centre x to Left / Center / Right."""
        center_x = (x1 + x2) / 2
        ratio = center_x / frame_width
        if ratio < config.LEFT_ZONE_END:
            return "left"
        elif ratio > config.RIGHT_ZONE_START:
            return "right"
        else:
            return "center"

    def _estimate_distance(self, y1: float, y2: float) -> float:
        """Monocular depth via bounding‐box height heuristic."""
        pixel_height = max(y2 - y1, 1)  # avoid div-by-zero
        distance = self.focal_constant / pixel_height
        return max(distance, 0.3)  # clamp minimum 0.3 m

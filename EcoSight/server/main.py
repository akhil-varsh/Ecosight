"""
EcoSight — Main Server
WebSocket server that streams Phase 1 hazard data in real time
and handles Phase 2 on-demand scene description requests.

Architecture:
    camera.py      → Frame capture + skip logic
    phase1_reflex  → YOLOv8 detection + depth + direction
    debounce.py    → Anti-spam cooldown per hazard
    schema.py      → JSON message builders
    phase2_context → Florence-2 captioning (on-demand)
    config.py      → All tuneable constants
"""

import asyncio
import json
import time
import numpy as np
import websockets

import config
from camera import CameraManager
from phase1_reflex import ReflexLayer
from phase2_context import ContextLayer
from debounce import HazardDebouncer
from schema import build_phase1_payload, build_phase2_payload, build_pong


# ─── Shared State ────────────────────────────────────────────────
class ServerState:
    """Mutable shared state across the event loop."""
    def __init__(self):
        self.clients: set = set()
        self.current_frame: np.ndarray | None = None
        self.phase2_requested = False
        self.running = True


state = ServerState()
camera = CameraManager()
reflex = ReflexLayer()
context = ContextLayer()
debouncer = HazardDebouncer()


# ─── WebSocket Handler ───────────────────────────────────────────
async def ws_handler(websocket):
    """Handle a new client connection."""
    state.clients.add(websocket)
    client_addr = websocket.remote_address
    print(f"[WS] Client connected: {client_addr}")

    try:
        async for message in websocket:
            data = json.loads(message)
            msg_type = data.get("type", "")

            if msg_type == "trigger_phase2":
                print("[WS] Phase 2 trigger received from client")
                state.phase2_requested = True

            elif msg_type == "ping":
                await websocket.send(json.dumps(build_pong()))

    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        state.clients.discard(websocket)
        print(f"[WS] Client disconnected: {client_addr}")


async def broadcast(payload: dict):
    """Send a JSON payload to all connected clients."""
    if not state.clients:
        return
    message = json.dumps(payload)
    await asyncio.gather(
        *(client.send(message) for client in state.clients),
        return_exceptions=True,
    )


# ─── Phase 1 Loop ────────────────────────────────────────────────
async def phase1_loop():
    """Continuously capture frames, run detection, and broadcast."""
    target_interval = 1.0 / config.PHASE1_TARGET_FPS
    frames_processed = 0
    start_time = time.perf_counter()

    while state.running:
        loop_start = time.perf_counter()

        # ── Read frame (with skip logic inside CameraManager) ─
        should_process, frame = camera.read()

        if frame is None:
            await asyncio.sleep(0.01)
            continue

        state.current_frame = frame

        # Skipped frame — just yield control and move on
        if not should_process:
            await asyncio.sleep(0.001)
            continue

        # ── Handle Phase 2 request (interrupts Phase 1 briefly) ─
        if state.phase2_requested:
            state.phase2_requested = False
            debouncer.reset()          # clear cooldowns on mode switch
            await handle_phase2(frame)
            continue

        # ── Run Phase 1 detection ────────────────────────────────
        detections = reflex.process_frame(frame)
        frames_processed += 1

        if detections:
            # Find the closest hazard that passes the debounce filter
            payload = None
            for det in detections:
                if debouncer.should_alert(det["hazard"], det["distance"]):
                    payload = build_phase1_payload(
                        hazard=det["hazard"],
                        direction=det["direction"],
                        distance=det["distance"],
                        confidence=det["confidence"],
                        total_hazards=len(detections),
                    )
                    break  # only send the most urgent non-debounced hazard

            if payload is None:
                # All hazards were debounced — send a "clear" heartbeat
                payload = build_phase1_payload(
                    hazard=None, direction=None,
                    distance=None, confidence=None,
                    total_hazards=len(detections),
                )
        else:
            payload = build_phase1_payload(
                hazard=None, direction=None,
                distance=None, confidence=None,
                total_hazards=0,
            )

        await broadcast(payload)

        # ── FPS counter (every 30 processed frames) ──────────────
        if frames_processed % 30 == 0:
            elapsed = time.perf_counter() - start_time
            fps = frames_processed / elapsed if elapsed > 0 else 0
            print(f"[Phase1] Processing at {fps:.1f} FPS")

        # ── Frame‑rate throttle ──────────────────────────────────
        elapsed = time.perf_counter() - loop_start
        sleep_time = target_interval - elapsed
        if sleep_time > 0:
            await asyncio.sleep(sleep_time)


# ─── Phase 2 Handler ─────────────────────────────────────────────
async def handle_phase2(frame: np.ndarray):
    """Run Florence-2 scene description on the current frame."""
    print("[Phase2] Processing scene description...")

    await broadcast(build_phase2_payload(status="processing"))

    # Run heavy model in a thread to avoid blocking the event loop
    loop = asyncio.get_event_loop()
    description = await loop.run_in_executor(
        None, context.describe_scene, frame
    )

    print(f"[Phase2] Description: {description[:80]}...")
    await broadcast(build_phase2_payload(status="done", description=description))


# ─── Main Entry ──────────────────────────────────────────────────
async def main():
    print("=" * 55)
    print("  EcoSight Server — Starting Up")
    print("=" * 55)

    # Open camera (with frame skip configured)
    camera.open()

    # Pre-load Florence-2 in background thread
    loop = asyncio.get_event_loop()
    asyncio.ensure_future(
        loop.run_in_executor(None, context.load_model)
    )

    # Start WebSocket server
    server = await websockets.serve(
        ws_handler,
        config.WEBSOCKET_HOST,
        config.WEBSOCKET_PORT,
    )
    print(f"[WS] Server listening on ws://{config.WEBSOCKET_HOST}:{config.WEBSOCKET_PORT}")

    # Start Phase 1 loop
    try:
        await phase1_loop()
    except KeyboardInterrupt:
        print("\n[Server] Shutting down...")
    finally:
        camera.release()
        server.close()
        await server.wait_closed()
        print("[Server] Stopped.")


if __name__ == "__main__":
    asyncio.run(main())

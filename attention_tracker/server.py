import asyncio
import time
import argparse
from typing import Dict, Any

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, JSONResponse

from engine import AttentionTrackerEngine

app = FastAPI(title="NeuroLearn OpenCV Attention Tracker API")

# Allow CORS for Flutter web / desktop
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

tracker_engine = AttentionTrackerEngine(camera_index=0, look_away_threshold_seconds=4.5)

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "NeuroLearn OpenCV Attention Tracker",
        "is_tracking": tracker_engine.is_running
    }

@app.get("/status")
async def get_status():
    return tracker_engine.get_status()

@app.post("/start")
async def start_session():
    success = tracker_engine.start_session()
    return {
        "success": success,
        "is_tracking": tracker_engine.is_running,
        "status": tracker_engine.get_status()
    }

@app.post("/stop")
async def stop_session():
    summary = tracker_engine.stop_session()
    return {
        "success": True,
        "summary": summary
    }

@app.post("/reset_alert")
async def reset_alert():
    tracker_engine.reset_alert()
    return {"success": True}

def _video_stream_generator():
    """Generates MJPEG multipart frames for live preview."""
    while True:
        if not tracker_engine.is_running:
            time.sleep(0.1)
            continue
        frame_bytes = tracker_engine.get_annotated_frame_bytes()
        if frame_bytes is None:
            time.sleep(0.03)
            continue
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
        time.sleep(0.033)  # ~30 FPS

@app.get("/video_feed")
async def video_feed():
    return StreamingResponse(
        _video_stream_generator(),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            status = tracker_engine.get_status()
            await websocket.send_json(status)
            await asyncio.sleep(0.1)  # 10 Hz streaming
    except (WebSocketDisconnect, asyncio.CancelledError):
        pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="NeuroLearn OpenCV Attention Tracker Server")
    parser.add_argument("--host", type=str, default="127.0.0.1", help="Host address (default 127.0.0.1)")
    parser.add_argument("--port", type=int, default=8008, help="Port number (default 8008)")
    parser.add_argument("--camera", type=int, default=0, help="Camera device index (default 0)")
    parser.add_argument("--threshold", type=float, default=4.5, help="Look-away alert threshold seconds (default 4.5)")
    parser.add_argument("--no-window", action="store_true", help="Disable the visible OpenCV preview window")
    args = parser.parse_args()

    tracker_engine.camera_index = args.camera
    tracker_engine.look_away_threshold_seconds = args.threshold
    tracker_engine.show_window = not args.no_window

    print(f"Starting NeuroLearn Attention Tracker Server on http://{args.host}:{args.port}")
    print(f"Live Camera Window: {'ENABLED' if tracker_engine.show_window else 'DISABLED'}")
    uvicorn.run(app, host=args.host, port=args.port, log_level="info")

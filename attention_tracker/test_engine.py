import time
import numpy as np
import cv2
from engine import AttentionTrackerEngine

def test_engine_init():
    engine = AttentionTrackerEngine(camera_index=0)
    assert engine.face_cascade is not None
    assert not engine.face_cascade.empty()
    assert engine.eye_cascade is not None
    assert not engine.eye_cascade.empty()
    status = engine.get_status()
    assert status["status"] == "idle"
    assert status["attention_percentage"] == 100.0
    print("[PASS] test_engine_init")

def test_gaze_synthetic():
    engine = AttentionTrackerEngine()
    # Create test synthetic frame
    frame = np.ones((480, 640, 3), dtype=np.uint8) * 220
    # Center face
    cv2.ellipse(frame, (320, 240), (100, 140), 0, 0, 360, (180, 210, 240), -1)
    # Eyes
    cv2.ellipse(frame, (280, 210), (22, 14), 0, 0, 360, (255, 255, 255), -1)
    cv2.ellipse(frame, (360, 210), (22, 14), 0, 0, 360, (255, 255, 255), -1)
    # Pupils
    cv2.circle(frame, (280, 210), 6, (20, 20, 20), -1)
    cv2.circle(frame, (360, 210), 6, (20, 20, 20), -1)

    gaze_dir, is_looking, face_box, eye_boxes, pupils = engine._analyze_gaze(frame)
    print(f"Gaze result: dir={gaze_dir}, is_looking={is_looking}, face={face_box}")
    assert isinstance(is_looking, bool)
    print("[PASS] test_gaze_synthetic")

def test_summary_calculation():
    engine = AttentionTrackerEngine()
    engine.total_tracked_time = 100.0
    engine.attentive_time = 85.0
    engine.distracted_time = 15.0
    engine.distraction_count = 3
    summary = engine.get_summary()
    assert summary["attention_percentage"] == 85.0
    assert summary["distraction_count"] == 3
    print("[PASS] test_summary_calculation")

if __name__ == "__main__":
    test_engine_init()
    test_gaze_synthetic()
    test_summary_calculation()
    print("All engine tests passed successfully!")

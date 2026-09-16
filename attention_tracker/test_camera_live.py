import cv2
import time
from engine import AttentionTrackerEngine

def main():
    print("==================================================")
    print("  NeuroLearn OpenCV Live Camera Attention Test   ")
    print("==================================================")
    print("Opening webcam... Look at the screen!")
    print("Turn your head away for 2 seconds to test the alert.")
    print("Press 'q' or 'ESC' in the camera window to exit.")
    print("==================================================")

    engine = AttentionTrackerEngine(camera_index=0, look_away_threshold_seconds=2.0)
    success = engine.start_session()

    if not success:
        print("[ERROR] Could not open camera. Make sure another app isn't using it.")
        return

    window_name = "NeuroLearn - OpenCV Live Attention & Gaze Tracker (Press Q to quit)"
    cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(window_name, 800, 600)

    try:
        while True:
            frame_bytes = engine.get_annotated_frame_bytes()
            if engine.latest_annotated_frame is not None:
                with engine.latest_frame_lock:
                    display_frame = engine.latest_annotated_frame.copy()

                cv2.imshow(window_name, display_frame)

            status = engine.get_status()
            # Check for quit key
            key = cv2.waitKey(20) & 0xFF
            if key == ord('q') or key == 27:
                break

    finally:
        summary = engine.stop_session()
        cv2.destroyAllWindows()
        print("\n==================================================")
        print("  Session Completed! Final Summary:              ")
        print("==================================================")
        print(f"Total Tracked Time:  {summary['total_seconds']} seconds")
        print(f"Attentive Time:      {summary['attentive_seconds']} seconds")
        print(f"Distracted Time:     {summary['distracted_seconds']} seconds")
        print(f"Look-Away Alerts:    {summary['distraction_count']}")
        print(f"Attention Score:     {summary['attention_percentage']}%")
        print("==================================================")

if __name__ == "__main__":
    main()

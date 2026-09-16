import time
import os
import cv2
import numpy as np
import threading
from typing import Dict, Any, Optional, Tuple

class AttentionTrackerEngine:
    def __init__(self, camera_index: int = 0, look_away_threshold_seconds: float = 2.0, show_window: bool = True):
        self.camera_index = camera_index
        self.look_away_threshold_seconds = look_away_threshold_seconds
        self.show_window = show_window

        # Load OpenCV Haar Cascades
        cascade_dir = cv2.data.haarcascades
        self.face_cascade = cv2.CascadeClassifier(os.path.join(cascade_dir, 'haarcascade_frontalface_default.xml'))
        self.profile_cascade = cv2.CascadeClassifier(os.path.join(cascade_dir, 'haarcascade_profileface.xml'))
        self.eye_cascade = cv2.CascadeClassifier(os.path.join(cascade_dir, 'haarcascade_eye.xml'))
        
        # State variables
        self.cap: Optional[cv2.VideoCapture] = None
        self.is_running = False
        self.thread: Optional[threading.Thread] = None
        self.lock = threading.Lock()
        
        # Session metrics
        self.session_start_time: Optional[float] = None
        self.session_end_time: Optional[float] = None
        self.total_tracked_time = 0.0
        self.attentive_time = 0.0
        self.distracted_time = 0.0
        self.distraction_count = 0
        
        # Real-time state
        self.is_attentive = True
        self.alert_needed = False
        self.current_gaze_direction = "CENTER"
        self.face_detected = False
        self.eyes_detected = False
        self.look_away_start_time: Optional[float] = None
        self.last_eye_seen_time: float = time.time()
        
        # Latest processed frame (with computer vision annotations) for live preview stream
        self.latest_annotated_frame: Optional[np.ndarray] = None
        self.latest_frame_lock = threading.Lock()

    def start_session(self) -> bool:
        """Starts or resets a new tracking session and webcam capture."""
        with self.lock:
            if self.is_running:
                self._reset_session_stats()
                return True

            # Open webcam (try DirectShow on Windows, then default)
            self.cap = cv2.VideoCapture(self.camera_index, cv2.CAP_DSHOW)
            if not self.cap or not self.cap.isOpened():
                self.cap = cv2.VideoCapture(self.camera_index)
            
            if not self.cap or not self.cap.isOpened():
                print(f"[TrackerEngine] Warning: Could not open camera {self.camera_index}")
                return False

            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            self.cap.set(cv2.CAP_PROP_FPS, 30)

            self._reset_session_stats()
            self.is_running = True
            self.thread = threading.Thread(target=self._capture_loop, daemon=True)
            self.thread.start()
            print("[TrackerEngine] Session started successfully.")
            return True

    def _reset_session_stats(self):
        now = time.time()
        self.session_start_time = now
        self.session_end_time = None
        self.total_tracked_time = 0.0
        self.attentive_time = 0.0
        self.distracted_time = 0.0
        self.distraction_count = 0
        self.is_attentive = True
        self.alert_needed = False
        self.current_gaze_direction = "CENTER"
        self.look_away_start_time = None
        self.last_eye_seen_time = now

    def stop_session(self) -> Dict[str, Any]:
        """Stops the tracking session and returns the final statistics."""
        with self.lock:
            self.is_running = False
            self.session_end_time = time.time()

        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=1.5)

        if self.cap:
            self.cap.release()
            self.cap = None

        if self.show_window:
            try:
                cv2.destroyAllWindows()
            except Exception:
                pass

        return self.get_summary()

    def reset_alert(self):
        """Allows front-end to clear the current look-away alert manually."""
        with self.lock:
            self.alert_needed = False
            self.look_away_start_time = None

    def get_status(self) -> Dict[str, Any]:
        """Returns the current real-time telemetry."""
        with self.lock:
            total = self.total_tracked_time
            attention_pct = round((self.attentive_time / total * 100.0), 1) if total > 0.5 else 100.0
            return {
                "status": "running" if self.is_running else "idle",
                "is_tracking": self.is_running,
                "is_attentive": self.is_attentive,
                "alert_needed": self.alert_needed,
                "attention_percentage": max(0.0, min(100.0, attention_pct)),
                "gaze_direction": self.current_gaze_direction,
                "face_detected": self.face_detected,
                "eyes_detected": self.eyes_detected,
                "attentive_seconds": round(self.attentive_time, 1),
                "distracted_seconds": round(self.distracted_time, 1),
                "total_seconds": round(total, 1),
                "distraction_count": self.distraction_count,
            }

    def get_summary(self) -> Dict[str, Any]:
        """Returns the final session attention metrics."""
        with self.lock:
            total = self.total_tracked_time
            attention_pct = round((self.attentive_time / total * 100.0), 1) if total > 0.5 else 100.0
            return {
                "attention_percentage": max(0.0, min(100.0, attention_pct)),
                "attentive_seconds": round(self.attentive_time, 1),
                "distracted_seconds": round(self.distracted_time, 1),
                "total_seconds": round(total, 1),
                "distraction_count": self.distraction_count,
            }

    def get_annotated_frame_bytes(self) -> Optional[bytes]:
        """Returns the latest annotated frame encoded as JPEG for MJPEG stream."""
        with self.latest_frame_lock:
            if self.latest_annotated_frame is None:
                return None
            ret, jpeg = cv2.imencode('.jpg', self.latest_annotated_frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
            if ret:
                return jpeg.tobytes()
            return None

    def _capture_loop(self):
        last_time = time.time()
        
        while self.is_running:
            if not self.cap or not self.cap.isOpened():
                time.sleep(0.05)
                continue

            ret, frame = self.cap.read()
            if not ret or frame is None:
                time.sleep(0.02)
                continue

            current_time = time.time()
            dt = current_time - last_time
            last_time = current_time

            # Flip horizontally for natural mirror feel
            frame = cv2.flip(frame, 1)
            h, w, _ = frame.shape

            # Process frame for gaze & attention
            gaze_dir, is_looking_screen, face_box, eye_boxes, pupils = self._analyze_gaze(frame)

            with self.lock:
                self.face_detected = (face_box is not None)
                self.eyes_detected = len(eye_boxes) > 0
                self.current_gaze_direction = gaze_dir

                # Update timers
                self.total_tracked_time += dt
                if is_looking_screen:
                    self.attentive_time += dt
                    self.is_attentive = True
                    # Gaze is back on screen -> clear active alert
                    self.look_away_start_time = None
                    self.alert_needed = False
                else:
                    self.distracted_time += dt
                    self.is_attentive = False
                    
                    if self.look_away_start_time is None:
                        self.look_away_start_time = current_time
                    else:
                        away_elapsed = current_time - self.look_away_start_time
                        if away_elapsed >= self.look_away_threshold_seconds and not self.alert_needed:
                            self.alert_needed = True
                            self.distraction_count += 1
                            print(f"[TrackerEngine] Alert triggered! Child looked away for {away_elapsed:.1f}s. Distractions: {self.distraction_count}")

            # Draw visual overlays for preview stream
            annotated = self._draw_visual_feedback(
                frame=frame.copy(),
                face_box=face_box,
                eye_boxes=eye_boxes,
                pupils=pupils,
                gaze_dir=gaze_dir,
                is_attentive=self.is_attentive,
                alert_needed=self.alert_needed
            )

            with self.latest_frame_lock:
                self.latest_annotated_frame = annotated

            if self.show_window and annotated is not None:
                try:
                    cv2.imshow("NeuroLearn - Live Attention & Gaze Tracker", annotated)
                    cv2.waitKey(1)
                except Exception:
                    pass

            # Target ~25-30 FPS loop rate
            time.sleep(0.01)

    def _analyze_gaze(self, frame: np.ndarray) -> Tuple[str, bool, Optional[Tuple[int, int, int, int]], list, list]:
        """
        Analyzes face orientation and eye pupils.
        Returns:
            (gaze_direction_str, is_looking_at_screen_bool, face_rect, eye_rects, pupil_points)
        """
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        h, w = gray.shape

        # 1. Detect frontal face
        faces = self.face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.2,
            minNeighbors=5,
            minSize=(80, 80)
        )

        # If no frontal face detected, check for profile face (head turned sideways)
        if len(faces) == 0:
            profiles = self.profile_cascade.detectMultiScale(
                gray,
                scaleFactor=1.2,
                minNeighbors=4,
                minSize=(80, 80)
            )
            if len(profiles) > 0:
                # Face is clearly turned away in profile
                return "TURNED_AWAY", False, profiles[0], [], []
            
            # No face detected at all
            return "NO_FACE", False, None, [], []

        # Select the largest face (most likely the child)
        face = max(faces, key=lambda r: r[2] * r[3])
        fx, fy, fw, fh = face

        # Check if face is too close to border or severely tilted
        face_center_x = fx + fw / 2.0
        if face_center_x < w * 0.08 or face_center_x > w * 0.92:
            return "HEAD_OFF_CENTER", False, face, [], []

        # 2. Detect eyes in upper 55% of the face region
        eye_region_y = fy + int(fh * 0.18)
        eye_region_h = int(fh * 0.40)
        eye_region_gray = gray[eye_region_y:eye_region_y + eye_region_h, fx:fx + fw]

        eyes = self.eye_cascade.detectMultiScale(
            eye_region_gray,
            scaleFactor=1.15,
            minNeighbors=4,
            minSize=(20, 20),
            maxSize=(int(fw * 0.45), int(eye_region_h * 0.9))
        )

        eye_boxes = []
        pupil_points = []
        gaze_votes = []

        now = time.time()
        if len(eyes) > 0:
            self.last_eye_seen_time = now

        for (ex, ey, ew, eh) in eyes:
            abs_ex = fx + ex
            abs_ey = eye_region_y + ey
            eye_boxes.append((abs_ex, abs_ey, ew, eh))

            # Crop individual eye
            eye_roi = eye_region_gray[ey:ey + eh, ex:ex + ew]
            
            # Find pupil position inside eye
            pupil = self._detect_pupil_in_eye(eye_roi)
            if pupil is not None:
                px, py = pupil
                pupil_points.append((abs_ex + px, abs_ey + py))

                # Gaze ratio: horizontal position of pupil in eye (0 = far left, 1 = far right)
                norm_x = px / float(ew)
                norm_y = py / float(eh)

                # Center zone calibration (between 0.28 and 0.72 horizontally, <= 0.78 vertically)
                if norm_x < 0.28:
                    gaze_votes.append("LEFT")
                elif norm_x > 0.72:
                    gaze_votes.append("RIGHT")
                elif norm_y > 0.78:
                    gaze_votes.append("DOWN")
                elif norm_y < 0.22:
                    gaze_votes.append("UP")
                else:
                    gaze_votes.append("CENTER")

        # Decision logic
        if len(eyes) == 0:
            # Face is present, but eyes not detected
            # If eyes were seen within the last 0.4 seconds, treat as normal blink!
            if (now - self.last_eye_seen_time) < 0.4:
                return "CENTER (BLINK)", True, face, [], []
            else:
                return "EYES_CLOSED_OR_AWAY", False, face, [], []

        if "CENTER" in gaze_votes or len(gaze_votes) == 0:
            return "CENTER", True, face, eye_boxes, pupil_points
        else:
            # Gaze drifted away
            primary_direction = gaze_votes[0]
            return f"LOOKING_{primary_direction}", False, face, eye_boxes, pupil_points

    def _detect_pupil_in_eye(self, eye_roi: np.ndarray) -> Optional[Tuple[int, int]]:
        """Finds the darkest region/centroid in the eye corresponding to the pupil/iris."""
        if eye_roi.shape[0] < 10 or eye_roi.shape[1] < 10:
            return None

        blurred = cv2.GaussianBlur(eye_roi, (7, 7), 0)
        
        # Pupil is the darkest spot in the eye; find the minimum intensity
        min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(blurred)

        # Use thresholding to find pupil contour centroid for smoother positioning
        thresh_val = min_val + 25
        _, thresh = cv2.threshold(blurred, thresh_val, 255, cv2.THRESH_BINARY_INV)

        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if contours:
            largest = max(contours, key=cv2.contourArea)
            m = cv2.moments(largest)
            if m["m00"] > 0:
                cx = int(m["m10"] / m["m00"])
                cy = int(m["m01"] / m["m00"])
                return (cx, cy)

        return min_loc

    def _draw_visual_feedback(
        self,
        frame: np.ndarray,
        face_box: Optional[Tuple[int, int, int, int]],
        eye_boxes: list,
        pupils: list,
        gaze_dir: str,
        is_attentive: bool,
        alert_needed: bool
    ) -> np.ndarray:
        """Renders bounding boxes, indicators, and attention metrics on the preview frame."""
        h, w, _ = frame.shape

        # Draw Face Box
        if face_box is not None:
            fx, fy, fw, fh = face_box
            color = (0, 220, 0) if is_attentive else (0, 70, 255)
            cv2.rectangle(frame, (fx, fy), (fx + fw, fy + fh), color, 2)
            cv2.putText(
                frame,
                "Child Face",
                (fx, max(20, fy - 8)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.55,
                color,
                2
            )

        # Draw Eye Boxes & Pupils
        for (ex, ey, ew, eh) in eye_boxes:
            cv2.rectangle(frame, (ex, ey), (ex + ew, ey + eh), (255, 200, 0), 1)

        for (px, py) in pupils:
            cv2.circle(frame, (px, py), 4, (0, 0, 255), -1)
            cv2.circle(frame, (px, py), 7, (0, 255, 255), 1)

        # Overlay Top Status HUD Bar
        overlay = frame.copy()
        cv2.rectangle(overlay, (0, 0), (w, 54), (20, 20, 25), -1)
        cv2.addWeighted(overlay, 0.75, frame, 0.25, 0, frame)

        # Current Attention %
        total = self.total_tracked_time
        pct = round((self.attentive_time / total * 100.0), 1) if total > 0.5 else 100.0
        pct_color = (0, 255, 120) if pct >= 75 else ((0, 200, 255) if pct >= 50 else (50, 50, 255))
        
        cv2.putText(
            frame,
            f"Attention: {pct:.0f}%",
            (15, 34),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.75,
            pct_color,
            2
        )

        # Gaze Direction status
        cv2.putText(
            frame,
            f"Gaze: {gaze_dir}",
            (230, 34),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (240, 240, 240),
            1
        )

        # Distraction count
        cv2.putText(
            frame,
            f"Alerts: {self.distraction_count}",
            (480, 34),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (200, 200, 255),
            1
        )

        # Alert Banner if child is looking away
        if alert_needed:
            banner_overlay = frame.copy()
            cv2.rectangle(banner_overlay, (0, h - 70), (w, h), (0, 0, 200), -1)
            cv2.addWeighted(banner_overlay, 0.85, frame, 0.15, 0, frame)
            cv2.putText(
                frame,
                "LOOK AT THE SCREEN!",
                (int(w * 0.18), h - 25),
                cv2.FONT_HERSHEY_SIMPLEX,
                1.0,
                (255, 255, 255),
                3
            )

        return frame

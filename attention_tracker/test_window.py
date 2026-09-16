import cv2
import time

print("Testing cv2.imshow...")
cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
if not cap.isOpened():
    cap = cv2.VideoCapture(0)

print("Camera isOpened:", cap.isOpened())
if cap.isOpened():
    ret, frame = cap.read()
    if ret:
        cv2.putText(frame, "Camera Test - Press any key to close", (30, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        cv2.imshow("Test Window", frame)
        cv2.waitKey(1000)
        cv2.destroyAllWindows()
        print("Window opened and closed successfully!")
    cap.release()

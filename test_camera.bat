@echo off
echo =================================================================
echo   NeuroLearn - Live Camera & Gaze Tracking Immediate Test
echo =================================================================
echo   Opening webcam window...
echo   Turn your head away for 2 seconds to trigger the alert banner!
echo   Press 'q' in the camera window to exit.
echo =================================================================
cd /d "%~dp0\attention_tracker"
python test_camera_live.py
pause

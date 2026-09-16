@echo off
echo =================================================================
echo   NeuroLearn - OpenCV Child Attention Tracker Service
echo =================================================================
echo   Starting camera tracker on http://127.0.0.1:8008 ...
echo   (A live camera window will pop up when assessment starts)
echo =================================================================
cd /d "%~dp0\attention_tracker"
python server.py --host 127.0.0.1 --port 8008
pause

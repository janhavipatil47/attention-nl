@echo off
echo ===================================================
echo   Starting NeuroLearn OpenCV Attention Tracker...
echo ===================================================
cd /d "%~dp0"
python server.py --host 127.0.0.1 --port 8008
pause

@echo off
echo =================================================================
echo   NeuroLearn - Handwriting Screening Service
echo =================================================================
echo   Starting handwriting API on http://127.0.0.1:8000 ...
echo =================================================================
cd /d "%~dp0"
set "PYTHON=..\venv\Scripts\python.exe"
if not exist "%PYTHON%" set "PYTHON=python"
"%PYTHON%" -m pip install -r requirements.txt
"%PYTHON%" api.py
pause

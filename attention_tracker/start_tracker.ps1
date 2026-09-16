Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Starting NeuroLearn OpenCV Attention Tracker...  " -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Cyan
Set-Location -Path $PSScriptRoot
python server.py --host 127.0.0.1 --port 8008

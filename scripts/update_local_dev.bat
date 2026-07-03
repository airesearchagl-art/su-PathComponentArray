@echo off
setlocal

cd /d "C:\Users\shuns\.claude\projects\su-PathComponentArray"

powershell -ExecutionPolicy Bypass -File ".\scripts\update_local_dev.ps1" -Branch "main"

echo.
echo If the update completed successfully, restart SketchUp 2025 to load the latest plugin code.
echo.
pause

endlocal

@echo off
REM === Create OSD folder and download script ===
mkdir %SystemDrive%\OSD
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/dlynch34/test/main/OSD/OOBEFinalize.ps1' -OutFile '%SystemDrive%\OSD\OOBEFinalize.ps1'"

REM === Run the script with Bypass (ignore execution policy) ===
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SystemDrive%\OSD\OOBEFinalize.ps1"

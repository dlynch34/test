@echo off
REM === Allow PowerShell scripts to run ===
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force"

REM === Run OOBEFinalization script from GitHub ===
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -NoProfile -Command \"iwr -useb https://raw.githubusercontent.com/dlynch34/test/main/OSD/OOBEFinalize.ps1 | iex\"' -WindowStyle Hidden"

# Allow script to run without interactive confirmation 
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Host "Installing required PowerShell modules for OOBE tasks..." -ForegroundColor Cyan
# Install the OSD module (provides Start-OOBEDeploy). This pulls from PowerShell Gallery.
Install-Module -Name OSD -Force -Verbose
# (If Autopilot integration is needed in OOBE, install AutopilotOOBE module as well)
# Install-Module -Name AutopilotOOBE -Force -Verbose

Write-Host "Running OOBE deployment tasks..." -ForegroundColor Cyan
# If using AutopilotOOBE, run it first to register device, etc:
# Start-AutopilotOOBE
# Run the OOBEDeploy tasks (reads OSDeploy.OOBEDeploy.json from C:\ProgramData\OSDeploy)
Start-OOBEDeploy

Write-Host "OOBE tasks completed. Restarting device..." -ForegroundColor Cyan
Restart-Computer -Force

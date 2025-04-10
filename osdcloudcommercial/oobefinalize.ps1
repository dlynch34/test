# Allow script to run without interactive confirmation 
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Host "Installing required PowerShell modules for OOBE tasks..." -ForegroundColor Cyan
Install-Module -Name OSD -Force -Verbose

# Install Autopilot Info script if needed
if (-not (Get-Command Get-WindowsAutopilotInfo.ps1 -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Get-WindowsAutopilotInfo script..." -ForegroundColor Cyan
    Install-Script -Name Get-WindowsAutopilotInfo -Force
}

# Automatically register this device with Autopilot (Commercial only)
try {
    Write-Host "Registering device with Autopilot (Commercial tenant)..." -ForegroundColor Green
    Get-WindowsAutopilotInfo.ps1 -Online -Assign
    Write-Log "Device registered to Autopilot with GroupTag Serco-OOBE"
} catch {
    Write-Log "Autopilot registration failed: $($_.Exception.Message)"
}

# Enable FIPS policy
$FipsRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy"
if (-not (Test-Path $FipsRegistryPath)) {
    New-Item -Path $FipsRegistryPath -Force | Out-Null
}
Set-ItemProperty -Path $FipsRegistryPath -Name "Enabled" -Value 1
Write-Log "FIPS Algorithm Policy enabled"

# Set Data Execution Prevention to OptOut
try {
    Start-Process -FilePath "bcdedit.exe" -ArgumentList "/set nx optout" -NoNewWindow -Wait
    Write-Log "Successfully executed: bcdedit /set nx optout"
} catch {
    Write-Log "Failed to execute bcdedit: $($_.Exception.Message)"
}

# Run OOBEDeploy
Write-Host "Running OOBEDeploy tasks..." -ForegroundColor Cyan
Start-OOBEDeploy
Write-Log "Start-OOBEDeploy executed"


# Allow script to run without interactive confirmation 
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Host "Installing required PowerShell modules for OOBE tasks..." -ForegroundColor Cyan
Install-Module -Name OSD -Force -Verbose

# Create log file
$LogFile = "C:\ProgramData\RenameComputer.log"
Function Write-Log {
    param ([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$TimeStamp - $Message"
}
Write-Log "Starting OOBE Finalize Script"


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

# Reboot
Write-Host "OOBE Finalization complete. Restarting..." -ForegroundColor Cyan
Write-Log "Rebooting device"
Restart-Computer -Force

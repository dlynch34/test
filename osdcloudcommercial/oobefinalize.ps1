# Allow script to run without interactive confirmation 
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Host "Installing required PowerShell modules for OOBE tasks..." -ForegroundColor Cyan
Install-Module -Name OSD -Force -Verbose


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

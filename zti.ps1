Write-Host -ForegroundColor Cyan "Starting Serco's OSDCloud Provisioning ..."
Start-Sleep -Seconds 3

# Set Display Resolution for VMs
if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host -ForegroundColor Cyan "Detected Virtual Machine. Setting Display Resolution to 1600x"
    Set-DisRes 1600
}

# Ensure latest OSD module
Write-Host -ForegroundColor Cyan "Updating OSD PowerShell Module..."
Install-Module OSD -Force

Write-Host -ForegroundColor Cyan "Importing OSD PowerShell Module..."
Import-Module OSD -Force

# Optional: Custom logging or setup steps can go here

# Begin Zero Touch Deployment
Write-Host -ForegroundColor Cyan "Launching OSDCloud ZTI for Serco"
Start-OSDCloud -OSLanguage en-us -OSBuild 24H2 -OSEdition Enterprise -ZTI

# Optional Post Actions
Write-Host -ForegroundColor Cyan "Running PostAction (placeholder)"
# e.g. Set registry keys, prepare for Intune, log status, etc.

# Restart after completion
Write-Host -ForegroundColor Yellow "Deployment Complete. Rebooting in 20 seconds..."
Start-Sleep -Seconds 20
wpeutil reboot

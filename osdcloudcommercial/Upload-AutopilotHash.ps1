$hashPath = "C:\ProgramData\Autopilot\DeviceHash.csv"
$logPath  = "C:\ProgramData\Autopilot\UploadLog.txt"

function Write-Log {
    param([string]$msg)
    Add-Content -Path $logPath -Value "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') - $msg"
}

Write-Log "Starting Autopilot hash upload script..."

if (-not (Test-Path $hashPath)) {
    Write-Log "❌ Hash file not found. Exiting."
    exit 1
}

try {
    Write-Log "Installing Get-WindowsAutopilotInfo if needed..."
    Install-Script -Name Get-WindowsAutopilotInfo -Force -Scope CurrentUser

    Write-Log "Connecting to Microsoft Graph..."
    Connect-MSGraph -Scopes "DeviceManagementServiceConfig.ReadWrite.All"

    Write-Log "Uploading hash..."
    Get-WindowsAutopilotInfo.ps1 -Online -Assign -InputFile $hashPath
    Write-Log "✅ Autopilot hash uploaded successfully."

    # Optional: Cleanup
    Remove-Item $hashPath -Force
    Unregister-ScheduledTask -TaskName "UploadAutopilotHash" -Confirm:$false
    Write-Log "Cleanup complete. Task removed."

} catch {
    Write-Log "❌ Error occurred: $($_.Exception.Message)"
}

# Allow script to run without interactive confirmation
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Create working directory
$autopilotPath = "C:\ProgramData\Autopilot"
New-Item -ItemType Directory -Path $autopilotPath -Force | Out-Null
$hashPath = Join-Path $autopilotPath "DeviceHash.csv"
$uploadScriptPath = Join-Path $autopilotPath "Upload-AutopilotHash.ps1"

# Install Get-WindowsAutopilotInfo script if needed
if (-not (Get-Command Get-WindowsAutopilotInfo.ps1 -ErrorAction SilentlyContinue)) {
    Install-Script -Name Get-WindowsAutopilotInfo -Force -Scope AllUsers
}

# Generate the hash and save it locally
try {
    Write-Host "Generating Autopilot hardware hash..."
    Get-WindowsAutopilotInfo.ps1 -OutputFile $hashPath
    Write-Host "✅ Hardware hash saved to $hashPath"
} catch {
    Write-Host "❌ Failed to generate hardware hash: $($_.Exception.Message)"
}

# Download the Upload-AutopilotHash.ps1 script from GitHub (or another blob)
$uploadScriptUrl = "https://raw.githubusercontent.com/dlynch34/test/main/osdcloudcommercial/Upload-AutopilotHash.ps1"
try {
    Invoke-WebRequest -Uri $uploadScriptUrl -OutFile $uploadScriptPath -UseBasicParsing
    Write-Host "✅ Upload script saved to $uploadScriptPath"
} catch {
    Write-Host "❌ Failed to download upload script: $($_.Exception.Message)"
}

# Create the scheduled task to upload hash at first user logon
try {
    $taskName = "UploadAutopilotHash"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$uploadScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "BUILTIN\Users" -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
    Write-Host "✅ Scheduled task '$taskName' created"
} catch {
    Write-Host "❌ Failed to create scheduled task: $($_.Exception.Message)"
}

# Enable FIPS policy
$FipsRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy"
if (-not (Test-Path $FipsRegistryPath)) {
    New-Item -Path $FipsRegistryPath -Force | Out-Null
}
Set-ItemProperty -Path $FipsRegistryPath -Name "Enabled" -Value 1

# Set Data Execution Prevention to OptOut
try {
    Start-Process -FilePath "bcdedit.exe" -ArgumentList "/set nx optout" -NoNewWindow -Wait
} catch {
    Write-Host "Failed to execute bcdedit: $($_.Exception.Message)"
}

# Run OOBEDeploy
Write-Host "Running OOBEDeploy tasks..." -ForegroundColor Cyan
Start-OOBEDeploy

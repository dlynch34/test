# Allow script to run without interactive confirmation
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Host "Installing required PowerShell modules for OOBE tasks..." -ForegroundColor Cyan
Install-Module -Name OSD -Force -Verbose

# Define the directory and file path for storing the hardware hash
$hashDir = "C:\ProgramData\Autopilot"
$hashPath = Join-Path -Path $hashDir -ChildPath "DeviceHash.csv"

# Create the directory if it doesn't exist
if (-not (Test-Path -Path $hashDir)) {
    New-Item -ItemType Directory -Path $hashDir -Force | Out-Null
}

# Install Get-WindowsAutopilotInfo if needed
if (-not (Get-Command Get-WindowsAutopilotInfo.ps1 -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Get-WindowsAutopilotInfo script..." -ForegroundColor Cyan
    Install-Script -Name Get-WindowsAutopilotInfo -Force -Scope AllUsers
}

# Generate and save the hardware hash
try {
    Write-Host "Generating hardware hash and saving to $hashPath"
    Get-WindowsAutopilotInfo.ps1 -OutputFile $hashPath
    Write-Host "✅ Hardware hash saved"
} catch {
    Write-Host "❌ Failed to generate hardware hash: $($_.Exception.Message)"
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


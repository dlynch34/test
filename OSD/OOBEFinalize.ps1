# Allow script to run without interactive confirmation
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Setup log path
$logPath = "C:\ProgramData\OOBEFinalize.log"

function Write-Log {
    param([string]$msg)
    Add-Content -Path $logPath -Value "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') - $msg"
}

Write-Log "===== Starting OOBE Finalization ====="

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

# Remove any existing KMS activation (allow Intune to apply MAK)
try {
    Write-Log "Removing KMS activation keys..."
    cscript.exe //nologo $env:SystemRoot\System32\slmgr.vbs /upk | Out-Null
    cscript.exe //nologo $env:SystemRoot\System32\slmgr.vbs /cpky | Out-Null
    cscript.exe //nologo $env:SystemRoot\System32\slmgr.vbs /ckms | Out-Null
    Write-Log "✅ KMS key removed"
} catch {
    Write-Log "❌ Failed to remove KMS key: $($_.Exception.Message)"
}

# Run OOBEDeploy
Write-Host "Running OOBEDeploy tasks..." -ForegroundColor Cyan
try {
    Start-OOBEDeploy
    Write-Log "Start-OOBEDeploy executed successfully"
} catch {
    Write-Log "❌ Failed to run Start-OOBEDeploy: $($_.Exception.Message)"
}

Write-Log "===== OOBE Finalization Complete ====="




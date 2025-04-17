# Allow script to run without interactive confirmation
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Setup log path
$logPath = "C:\ProgramData\OOBEFinalize.log"
function Write-Log {
    param([string]$msg)
    Add-Content -Path $logPath -Value "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') - $msg"
}
Write-Log "===== Starting OOBE Finalization ====="

# Prevent Windows 11 automatic device encryption
try {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "PreventDeviceEncryption" -Value 1 -Type DWord -Force
    Write-Log "✅ PreventDeviceEncryption registry key set"
} catch {
    Write-Log "❌ Failed to set PreventDeviceEncryption key: $($_.Exception.Message)"
}

# Install and import OSD module
try {
    if (-not (Get-Module -ListAvailable -Name OSD)) {
        Install-Module -Name OSD -Force -Verbose
        Write-Log "✅ OSD module installed"
    }
    Import-Module OSD -Force -Verbose
    Write-Log "✅ OSD module imported successfully"
} catch {
    Write-Log "❌ Failed to install/import OSD module: $($_.Exception.Message)"
}

# Enable FIPS policy
try {
    $FipsRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy"
    if (-not (Test-Path $FipsRegistryPath)) {
        New-Item -Path $FipsRegistryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $FipsRegistryPath -Name "Enabled" -Value 1
    Write-Log "✅ FIPS Algorithm Policy enabled"
} catch {
    Write-Log "❌ Failed to set FIPS policy: $($_.Exception.Message)"
}

# Set Data Execution Prevention to OptOut
try {
    Start-Process -FilePath "bcdedit.exe" -ArgumentList "/set nx optout" -NoNewWindow -Wait
    Write-Log "✅ Successfully executed: bcdedit /set nx optout"
} catch {
    Write-Log "❌ Failed to execute bcdedit: $($_.Exception.Message)"
}




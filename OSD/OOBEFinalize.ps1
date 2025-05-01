# Allow script to run without interactive confirmation
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Setup log path
$logPath = "C:\ProgramData\OOBEFinalize.log"
function Write-Log {
    param([string]$msg)
    Add-Content -Path $logPath -Value "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') - $msg"
}
Write-Log "===== Starting OOBE Finalization ====="

# Block automatic BitLocker provisioning (Windows 11 Home/Pro)
try {
    $bitlockerControlKey = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
    if (-not (Test-Path $bitlockerControlKey)) {
        New-Item -Path $bitlockerControlKey -Force | Out-Null
    }
    Set-ItemProperty -Path $bitlockerControlKey -Name "PreventDeviceEncryption" -Value 1 -Type DWord -Force
    Write-Log "PreventDeviceEncryption key set successfully."
} catch {
    Write-Log "Failed to set PreventDeviceEncryption: $_"
}

# Set BitLocker GPO policies to disable auto provision
try {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithNoTPM" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithAutoProvisioning" /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "BitLocker GPO provisioning policies applied."
} catch {
    Write-Log "Failed to apply BitLocker policy settings: $_"
}

# Suspend BitLocker if it already started
try {
    $osDrive = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
    if ($osDrive.ProtectionStatus -eq 'On') {
        Write-Log "BitLocker already enabled. Suspending temporarily..."
        Suspend-BitLocker -MountPoint "C:" -RebootCount 0
    } else {
        Write-Log "BitLocker not active at this stage."
    }
} catch {
    Write-Log "Could not query BitLocker status: $_"
}

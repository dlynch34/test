# Allow script to run without interactive confirmation
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Setup log path
$logPath = "C:\ProgramData\OOBEFinalize.log"
function Write-Log {
    param([string]$msg)
    Add-Content -Path $logPath -Value "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') - $msg"
}
Write-Log "===== Starting OOBE Finalization ====="

# Check and suspend BitLocker if already enabled
try {
    $osDrive = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
    if ($osDrive.ProtectionStatus -eq 'On') {
        Write-Log "BitLocker detected as enabled. Suspending..."
        Suspend-BitLocker -MountPoint "C:" -RebootCount 0
    } else {
        Write-Log "BitLocker not yet enabled."
    }
} catch {
    Write-Log "BitLocker volume not found or failed to query: $_"
}

# Disable automatic BitLocker provisioning
Write-Log "Disabling BitLocker auto-provisioning..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithNoTPM" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithAutoProvisioning" /t REG_DWORD /d 0 /f | Out-Null
Write-Log "BitLocker provisioning policies applied."

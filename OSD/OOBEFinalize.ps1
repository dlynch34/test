# Allow script to run without interactive confirmation
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Setup log path
$logPath = "C:\ProgramData\OOBEFinalize.log"
function Write-Log {
    param([string]$msg)
    Add-Content -Path $logPath -Value "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') - $msg"
}
Write-Log "===== Starting OOBE Finalization ====="

# Disable BitLocker temporarily on OS volume if auto-enabled
$osDrive = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
if ($osDrive.ProtectionStatus -eq 'On') {
    Suspend-BitLocker -MountPoint "C:" -RebootCount 0
}

# Disable automatic BitLocker provisioning for the session
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithNoTPM" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithAutoProvisioning" /t REG_DWORD /d 0 /f

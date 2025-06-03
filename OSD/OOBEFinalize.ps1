# ======================================================================
# OOBE.ps1 – Defer Windows auto-encryption, update OS, keep Intune free
# ======================================================================

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# ----- logging helper -------------------------------------------------
$logPath = "C:\ProgramData\OOBEFinalize.log"
function Write-Log {
    param([string]$msg)
    Add-Content -Path $logPath -Value "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')  $msg"
}
Write-Log "===== Starting OOBE Finalization ====="

# ----------------------------------------------------------------------
# 1. Defer built-in XTS-AES-128 device-encryption during OOBE
# ----------------------------------------------------------------------
try {
    $provKey = 'HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\Config'
    if (-not (Test-Path $provKey)) { New-Item -Path $provKey -Force | Out-Null }
    Set-ItemProperty -Path $provKey -Name 'DisableRuntimeProvisioning' -Value 1 -Type DWord -Force
    Write-Log "Set DisableRuntimeProvisioning = 1 (device-encryption will not run in OOBE)."
} catch { Write-Log "Failed to set DisableRuntimeProvisioning: $_" }

# ----------------------------------------------------------------------
# 2. Remove PreventDeviceEncryption if present (unblocks Intune BitLocker)
# ----------------------------------------------------------------------
try {
    $blCtrl = 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker'
    if (Get-ItemProperty -Path $blCtrl -Name 'PreventDeviceEncryption' -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $blCtrl -Name 'PreventDeviceEncryption' -Force
        Write-Log "Removed legacy PreventDeviceEncryption flag."
    } else {
        Write-Log "PreventDeviceEncryption not present – nothing to remove."
    }
} catch { Write-Log "Error checking/removing PreventDeviceEncryption: $_" }

# ----------------------------------------------------------------------
# 3. Keep FVE policies that disable TPM-less + auto-provision
# ----------------------------------------------------------------------
try {
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithNoTPM"          /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithAutoProvisioning" /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "BitLocker auto-provisioning policies applied (NoTPM=0, AutoProvision=0)."
} catch { Write-Log "Failed to apply FVE policies: $_" }

# ----------------------------------------------------------------------
# 4. If BitLocker already active, suspend until staging is done
# ----------------------------------------------------------------------
try {
    $os = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction Stop
    if ($os.ProtectionStatus -eq 'On') {
        Write-Log "BitLocker already active – suspending for remainder of OOBE."
        Suspend-BitLocker -MountPoint 'C:' -RebootCount 0
    } else {
        Write-Log "BitLocker not active (as expected)."
    }
} catch { Write-Log "Could not query BitLocker status: $_" }

# ----------------------------------------------------------------------
# 5. OPTIONAL – Force Windows Update scan / download / install
# ----------------------------------------------------------------------
try {
    Write-Log "Windows Update: starting ScanInstallWait sequence…"
    $uso = "$env:SystemRoot\System32\UsoClient.exe"

    Start-Process -FilePath $uso -ArgumentList "ScanInstallWait" -Wait
    Write-Log "Windows Update: ScanInstallWait completed."

    # second quick pass
    Start-Process -FilePath $uso -ArgumentList "StartScan"     -Wait
    Start-Process -FilePath $uso -ArgumentList "StartDownload" -Wait
    Start-Process -FilePath $uso -ArgumentList "StartInstall"  -Wait
    Write-Log "Windows Update: second-pass Scan/Download/Install completed."
} catch {
    Write-Log "Windows Update: error during update sequence: $_"
}

Write-Log "===== OOBE Finalization complete – device ready for Intune BitLocker enforcement ====="

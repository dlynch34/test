# ======================================================================
# OOBE.ps1  –  Defer Windows auto-encryption but keep Intune BitLocker free
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
# 1.  *Defer* the built-in device-encryption (XTS-AES-128) during OOBE
#     by enabling the OEM flag  DisableRuntimeProvisioning = 1
# ----------------------------------------------------------------------
try {
    $provKey = 'HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\Config'
    if (-not (Test-Path $provKey)) { New-Item -Path $provKey -Force | Out-Null }
    Set-ItemProperty -Path $provKey -Name 'DisableRuntimeProvisioning' -Value 1 -Type DWord -Force
    Write-Log "Set DisableRuntimeProvisioning = 1 (device-encryption will not run in OOBE)."
} catch { Write-Log "Failed to set DisableRuntimeProvisioning: $_" }

# ----------------------------------------------------------------------
# 2.  Remove the stricter PreventDeviceEncryption flag if an older image
#     had set it.  (Keeping it would block Intune’s BitLocker policy.)
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
# 3.  Keep the two FVE policies that disable TPM-less + auto-provisioning
# ----------------------------------------------------------------------
try {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithNoTPM" ^
            /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithAutoProvisioning" ^
            /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "BitLocker auto-provisioning policies applied (NoTPM=0, AutoProvision=0)."
} catch { Write-Log "Failed to apply FVE policies: $_" }

# ----------------------------------------------------------------------
# 4.  If BitLocker somehow began (rare), suspend so Autopilot can finish
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
# OPTIONAL: Force Windows Update scan / download / install  (Win 10/11)
# ----------------------------------------------------------------------
try {
    Log "Windows Update: starting ScanInstallWait sequence…"

    $uso = "$env:SystemRoot\System32\UsoClient.exe"

    # Combined command that scans, downloads and installs, then waits
    Start-Process -FilePath $uso -ArgumentList "ScanInstallWait" -Wait
    Log "Windows Update: ScanInstallWait completed."

    # Second pass (rare) – some cumulative updates only install after reboot,
    # so kick off a fresh scan to catch any remaining patches.
    Start-Process -FilePath $uso -ArgumentList "StartScan"      -Wait
    Start-Process -FilePath $uso -ArgumentList "StartDownload"  -Wait
    Start-Process -FilePath $uso -ArgumentList "StartInstall"   -Wait
    Log "Windows Update: second-pass StartScan/Download/Install completed."

} catch {
    Log "Windows Update: error during update sequence: $_"
}


Write-Log "===== OOBE Finalization complete – device ready for Intune BitLocker enforcement ====="


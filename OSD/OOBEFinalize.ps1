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
# 1. Disable OOBE device encryption runtime provisioning
# ----------------------------------------------------------------------
try {
    $provKey = 'HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\Config'
    if (-not (Test-Path $provKey)) {
        New-Item -Path $provKey -Force | Out-Null
    }
    Set-ItemProperty -Path $provKey -Name 'DisableRuntimeProvisioning' -Value 1 -Type DWord -Force
    Write-Log "Set DisableRuntimeProvisioning = 1 (blocks auto-encryption during OOBE)"
} catch {
    Write-Log "Failed to set DisableRuntimeProvisioning: $_"
}

# ----------------------------------------------------------------------
# 2. Optional: Remove PreventDeviceEncryption if present
# ----------------------------------------------------------------------
try {
    $blCtrl = 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker'
    if (Get-ItemProperty -Path $blCtrl -Name 'PreventDeviceEncryption' -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $blCtrl -Name 'PreventDeviceEncryption' -Force
        Write-Log "Removed PreventDeviceEncryption legacy value"
    }
} catch {
    Write-Log "Error removing PreventDeviceEncryption: $_"
}

# ----------------------------------------------------------------------
# 3. Trigger Windows Updates using COM (works during OOBE)
# ----------------------------------------------------------------------
try {
    Write-Log "Starting Windows Update COM process..."

    $wu = Get-Service -Name wuauserv -ErrorAction Stop
    if ($wu.Status -ne 'Running') {
        Set-Service -Name wuauserv -StartupType Automatic
        Start-Service -Name wuauserv
        Write-Log "Windows Update service started"
    } else {
        Write-Log "Windows Update service already running"
    }

    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")

    if ($searchResult.Updates.Count -eq 0) {
        Write-Log "No applicable updates found"
    } else {
        Write-Log "$($searchResult.Updates.Count) update(s) found"

        $updates = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($u in $searchResult.Updates) {
            $updates.Add($u) | Out-Null
            Write-Log "Queued: $($u.Title)"
        }

        $downloader = $updateSession.CreateUpdateDownloader()
        $downloader.Updates = $updates
        $downloader.Download()

        $installer = $updateSession.CreateUpdateInstaller()
        $installer.Updates = $updates
        $result = $installer.Install()

        Write-Log "Windows Updates installed: $($result.Updates.Count)"
    }
} catch {
    Write-Log "Windows Update COM error: $_"
}

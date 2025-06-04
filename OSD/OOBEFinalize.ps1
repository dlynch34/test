# ======================================================================
# OOBE.ps1 – Block auto-encryption, trigger Windows Updates
# ======================================================================

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# ----- Logging helper -------------------------------------------------
$logPath = "C:\ProgramData\OOBEFinalize.log"
function Write-Log {
    param([string]$msg)
    Add-Content -Path $logPath -Value "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')  $msg"
}
Write-Log "===== Starting OOBE Finalization ====="

# ----------------------------------------------------------------------
# 1. Ensure PreventDeviceEncryption is set = 1 (block device encryption)
# ----------------------------------------------------------------------
try {
    $blCtrl = 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker'
    if (-not (Test-Path $blCtrl)) {
        New-Item -Path $blCtrl -Force | Out-Null
    }
    Set-ItemProperty -Path $blCtrl -Name 'PreventDeviceEncryption' -Value 1 -Type DWord -Force
    Write-Log "Set PreventDeviceEncryption = 1 to block auto-encryption"
} catch {
    Write-Log "Failed to set PreventDeviceEncryption: $_"
}

# ----------------------------------------------------------------------
# 2. Ensure Windows Update Agent (wuauserv) is running and responsive
# ----------------------------------------------------------------------
try {
    Write-Log "Ensuring Windows Update Agent (wuauserv) is running..."

    $wuAttempts = 0
    do {
        $wuAttempts++
        $wu = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
        if ($wu -and $wu.Status -eq 'Running') {
            Write-Log "wuauserv is running"
            break
        } else {
            Write-Log "Waiting for wuauserv to start... attempt $wuAttempts"
            Set-Service -Name wuauserv -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 10
        }
    } while ($wuAttempts -lt 6)

    if ($wu.Status -ne 'Running') {
        throw "wuauserv did not start in time"
    }
} catch {
    Write-Log "Failed to ensure Windows Update service is running: $_"
}

# ----------------------------------------------------------------------
# 3. Trigger Windows Updates using COM (works during OOBE)
# ----------------------------------------------------------------------
try {
    Write-Log "Starting Windows Update COM process..."

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
        Write-Log "Install result code: $($result.ResultCode), RebootRequired: $($result.RebootRequired)"
    }
} catch {
    Write-Log "Windows Update COM error: $_"
}

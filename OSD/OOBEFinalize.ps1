# ======================================================================
# OOBE.ps1 – Block BitLocker auto-encryption and apply Windows Updates
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
# 1. Block automatic device encryption via PreventDeviceEncryption
# ----------------------------------------------------------------------
try {
    $bitlockerControlKey = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
    if (-not (Test-Path $bitlockerControlKey)) {
        New-Item -Path $bitlockerControlKey -Force | Out-Null
    }
    Set-ItemProperty -Path $bitlockerControlKey -Name "PreventDeviceEncryption" -Value 1 -Type DWord -Force
    Write-Log "PreventDeviceEncryption = 1 applied successfully."
} catch {
    Write-Log "Failed to set PreventDeviceEncryption: $_"
}

# ----------------------------------------------------------------------
# 2. Apply BitLocker GPO policies to block auto-provisioning
# ----------------------------------------------------------------------
try {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithNoTPM" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithAutoProvisioning" /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "BitLocker GPO policies applied (NoTPM=0, AutoProvisioning=0)."
} catch {
    Write-Log "Failed to apply BitLocker GPO policies: $_"
}

# ----------------------------------------------------------------------
# 3. Suspend BitLocker if already active
# ----------------------------------------------------------------------
try {
    $osDrive = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
    if ($osDrive.ProtectionStatus -eq 'On') {
        Write-Log "BitLocker already enabled – suspending..."
        Suspend-BitLocker -MountPoint "C:" -RebootCount 0
        Write-Log "BitLocker suspended successfully."
    } else {
        Write-Log "BitLocker not active at this stage."
    }
} catch {
    Write-Log "Could not query or suspend BitLocker: $_"
}

# ----------------------------------------------------------------------
# 4. Ensure Windows Update Agent (wuauserv) is running and responsive
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

    Write-Log "Searching for available updates using COM..."
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")

    if ($searchResult.Updates.Count -eq 0) {
        Write-Log "No applicable updates found."
    } else {
        Write-Log "Found $($searchResult.Updates.Count) update(s) to install."

        $updates = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($u in $searchResult.Updates) {
            $updates.Add($u) | Out-Null
            Write-Log "Queued: $($u.Title)"
        }

        $downloader = $updateSession.CreateUpdateDownloader()
        $downloader.Updates = $updates
        $downloader.Download()
        Write-Log "All updates downloaded."

        $installer = $updateSession.CreateUpdateInstaller()
        $installer.Updates = $updates
        $result = $installer.Install()
        Write-Log "Windows Updates installed: $($result.Updates.Count)"
    }
} catch {
    Write-Log "Windows Update COM error: $_"
}

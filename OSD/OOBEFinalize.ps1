# ======================================================================
# OOBEFinalize.ps1 – Block BitLocker auto-encryption, install updates,
# validate Intune agent, and trigger MDM sync (delayed-safe logic)
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
# 1. Block automatic device encryption
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
# 2. Apply GPO registry for BitLocker behavior
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
# 4. Ensure Windows Update service is running and install updates
# ----------------------------------------------------------------------
try {
    Write-Log "Waiting 30 seconds to ensure Windows Update engine is stable..."
    Start-Sleep -Seconds 30

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

    if ($wu.Status -ne 'Running') { throw "wuauserv did not start in time" }

    # Search & install quality updates
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0 and AutoSelectOnWebSites=1")

    if ($searchResult.Updates.Count -eq 0) {
        Write-Log "No applicable quality updates found."
    } else {
        $updates = New-Object -ComObject Microsoft.Update.UpdateColl
        $installedLog = "C:\ProgramData\OOBE_InstalledUpdates.txt"
        foreach ($u in $searchResult.Updates) {
            if ($u.Title -match "Cumulative|Security|OOBE|Recovery|Servicing Stack") {
                $updates.Add($u) | Out-Null
                Write-Log "Queued for install: $($u.Title)"
            } else {
                Write-Log "Skipped (non-quality): $($u.Title)"
            }
        }

        if ($updates.Count -gt 0) {
            Write-Log "Downloading $($updates.Count) quality update(s)..."
            $downloader = $updateSession.CreateUpdateDownloader()
            $downloader.Updates = $updates
            $downloader.Download()
            Write-Log "All quality updates downloaded."

            $installer = $updateSession.CreateUpdateInstaller()
            $installer.Updates = $updates
            $result = $installer.Install()

            Write-Log "Install result code: $($result.ResultCode)"
            Write-Log "Updates installed: $($result.Updates.Count)"
        } else {
            Write-Log "No matching quality updates queued."
        }
    }
} catch {
    Write-Log "Windows Update COM error: $_"
}

# ----------------------------------------------------------------------
# 5. Check Intune Management Extension and MDM sync
# ----------------------------------------------------------------------
try {
    $ime = Get-Service -Name IntuneManagementExtension -ErrorAction SilentlyContinue
    if ($ime -and $ime.Status -ne 'Running') {
        Set-Service -Name IntuneManagementExtension -StartupType Automatic
        Start-Service -Name IntuneManagementExtension
        Write-Log "Started Intune Management Extension service."
    } else {
        Write-Log "Intune Management Extension is already running."
    }
} catch {
    Write-Log "Failed to verify/start Intune agent: $_"
}

# ----------------------------------------------------------------------
# 6. Trigger MDM sync
# ----------------------------------------------------------------------
try {
    $null = Invoke-CimMethod -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_Policy_Config01_Account01" -MethodName "ScheduleSync"
    Write-Log "MDM ScheduleSync triggered."
} catch {
    Write-Log "ScheduleSync failed: $_"
}

# ----------------------------------------------------------------------
# 7. Dump dsregcmd output
# ----------------------------------------------------------------------
try {
    dsregcmd /status | Out-File "C:\ProgramData\DSREG_Status.txt" -Encoding UTF8
    Write-Log "Captured dsregcmd status."
} catch {
    Write-Log "Failed to run dsregcmd."
}

Write-Log "===== OOBE Finalization Complete ====="

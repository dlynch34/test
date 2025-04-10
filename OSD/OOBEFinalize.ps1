# Allow script to run without interactive confirmation
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Setup log path
$logPath = "C:\ProgramData\OOBEFinalize.log"
function Write-Log {
    param([string]$msg)
    Add-Content -Path $logPath -Value "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') - $msg"
}
Write-Log "===== Starting OOBE Finalization ====="

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

# Ensure Software Protection Service is running
try {
    $service = Get-Service -Name sppsvc -ErrorAction Stop
    if ($service.Status -ne 'Running') {
        Start-Service -Name sppsvc
        Start-Sleep -Seconds 5
        Write-Log "✅ sppsvc (Software Protection Service) started"
    } else {
        Write-Log "sppsvc already running"
    }
} catch {
    Write-Log "❌ Failed to check/start sppsvc: $($_.Exception.Message)"
}

# Remove any existing KMS activation key (upk + cpky only)
Write-Log "Removing KMS client activation keys..."
try {
    $exit1 = (Start-Process -FilePath "cscript.exe" -ArgumentList "//nologo $env:SystemRoot\System32\slmgr.vbs /upk" -NoNewWindow -Wait -PassThru).ExitCode
    $exit2 = (Start-Process -FilePath "cscript.exe" -ArgumentList "//nologo $env:SystemRoot\System32\slmgr.vbs /cpky" -NoNewWindow -Wait -PassThru).ExitCode

    if ($exit1 -eq 0 -and $exit2 -eq 0) {
        Write-Log "✅ KMS keys removed successfully (/upk, /cpky)"
    } else {
        Write-Log "⚠️ One or more KMS removal steps may have failed:"
        Write-Log "  /upk exit code: $exit1"
        Write-Log "  /cpky exit code: $exit2"
    }
} catch {
    Write-Log "❌ Exception occurred during KMS cleanup: $($_.Exception.Message)"
}

# Run OOBEDeploy (optional)
try {
    Start-OOBEDeploy
    Write-Log "✅ Start-OOBEDeploy executed successfully"
} catch {
    Write-Log "❌ Failed to run Start-OOBEDeploy: $($_.Exception.Message)"
}

# Call MAK activation script directly
$makScript = "C:\OSDCloud\Config\Scripts\startup\Set-WindowsActivation.ps1"
if (Test-Path $makScript) {
    Write-Log "▶️ Running MAK activation script..."
    try {
        & $makScript
        Write-Log "✅ MAK activation script executed"
    } catch {
        Write-Log "❌ MAK activation script failed: $($_.Exception.Message)"
    }
} else {
    Write-Log "⚠️ MAK activation script not found at: $makScript"
}

# Reboot to finalize activation and policy
Write-Log "🔁 Rebooting to complete MAK activation..."
Start-Sleep -Seconds 10
Restart-Computer -Force

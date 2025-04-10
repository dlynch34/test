# Allow script to run without interactive confirmation
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Setup log path
$logPath = "C:\ProgramData\OOBEFinalize.log"

function Write-Log {
    param([string]$msg)
    Add-Content -Path $logPath -Value "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') - $msg"
}

Write-Log "===== Starting OOBE Finalization ====="

Write-Host "Installing required PowerShell modules for OOBE tasks..." -ForegroundColor Cyan
try {
    if (-not (Get-Module -ListAvailable -Name OSD)) {
        Install-Module -Name OSD -Force -Verbose
        Write-Log "✅ OSD module installed"
    } else {
        Write-Log "OSD module already available"
    }

    Import-Module OSD -Force -Verbose
    Write-Log "✅ OSD module imported successfully"
} catch {
    Write-Log "❌ Failed to install/import OSD module: $($_.Exception.Message)"
}

# Dot-source helper functions from Start-OOBEDeploy.ps1 to expose Invoke-OOBE* functions
try {
    $osdPath = (Get-Module -Name OSD).ModuleBase
    $deployScript = Join-Path $osdPath "Public\Functions\Start-OOBEDeploy.ps1"
    if (Test-Path $deployScript) {
        . $deployScript
        Write-Log "✅ Dot-sourced Start-OOBEDeploy.ps1 to expose internal functions"
    } else {
        Write-Log "❌ Could not find Start-OOBEDeploy.ps1 at $deployScript"
    }
} catch {
    Write-Log "❌ Failed to dot-source Start-OOBEDeploy.ps1: $($_.Exception.Message)"
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

# Run OOBEDeploy
Write-Host "Running OOBEDeploy tasks..." -ForegroundColor Cyan
try {
    Start-OOBEDeploy
    Write-Log "✅ Start-OOBEDeploy executed successfully"
} catch {
    Write-Log "❌ Failed to run Start-OOBEDeploy: $($_.Exception.Message)"
}

Write-Log "===== OOBE Finalization Complete ====="

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
Install-Module -Name OSD -Force -Verbose

# Enable FIPS policy
$FipsRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy"
if (-not (Test-Path $FipsRegistryPath)) {
    New-Item -Path $FipsRegistryPath -Force | Out-Null
}
Set-ItemProperty -Path $FipsRegistryPath -Name "Enabled" -Value 1
Write-Log "FIPS Algorithm Policy enabled"

# Set Data Execution Prevention to OptOut
try {
    Start-Process -FilePath "bcdedit.exe" -ArgumentList "/set nx optout" -NoNewWindow -Wait
    Write-Log "Successfully executed: bcdedit /set nx optout"
} catch {
    Write-Log "Failed to execute bcdedit: $($_.Exception.Message)"
}

# Ensure Software Protection Service is running
try {
    $service = Get-Service -Name sppsvc -ErrorAction Stop
    if ($service.Status -ne 'Running') {
        Write-Log "Starting sppsvc (Software Protection Service)..."
        Start-Service -Name sppsvc
        Start-Sleep -Seconds 5
        Write-Log "✅ sppsvc started"
    } else {
        Write-Log "sppsvc is already running"
    }
} catch {
    Write-Log "❌ Failed to check or start sppsvc: $($_.Exception.Message)"
}

# Remove any existing KMS activation key (upk + cpky only)
Write-Log "Removing KMS client activation keys..."
$exit1 = (Start-Process -FilePath "cscript.exe" -ArgumentList "//nologo $env:SystemRoot\System32\slmgr.vbs /upk" -NoNewWindow -Wait -PassThru).ExitCode
$exit2 = (Start-Process -FilePath "cscript.exe" -ArgumentList "//nologo $env:SystemRoot\System32\slmgr.vbs /cpky" -NoNewWindow -Wait -PassThru).ExitCode

if ($exit1 -eq 0 -and $exit2 -eq 0) {
    Write-Log "✅ KMS keys removed successfully (/upk, /cpky)"
} else {
    Write-Log "⚠️ One or more KMS removal steps may have failed:"
    Write-Log "  /upk exit code: $exit1"
    Write-Log "  /cpky exit code: $exit2"
}

# Run OOBEDeploy
Write-Host "Running OOBEDeploy tasks..." -ForegroundColor Cyan
try {
    Start-OOBEDeploy
    Write-Log "Start-OOBEDeploy executed successfully"
} catch {
    Write-Log "❌ Failed to run Start-OOBEDeploy: $($_.Exception.Message)"
}

Write-Log "===== OOBE Finalization Complete ====="

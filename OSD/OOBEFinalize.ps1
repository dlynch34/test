# Allow script to run without interactive confirmation 
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Host "Installing required PowerShell modules for OOBE tasks..." -ForegroundColor Cyan
# Install the OSD module (provides Start-OOBEDeploy)
Install-Module -Name OSD -Force -Verbose

Write-Host "Running OOBE deployment tasks..." -ForegroundColor Cyan

# =====================================
# Add custom rename logic: DSG/LPG+Serial
# =====================================
$Battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
$Prefix = if ($Battery) { "LPG" } else { "DSG" }
$Serial = (Get-CimInstance Win32_BIOS).SerialNumber.Trim()
$MaxLen = 15 - $Prefix.Length
$Serial = if ($Serial.Length -gt $MaxLen) { $Serial.Substring(0, $MaxLen) } else { $Serial }
$NewName = "$Prefix$Serial"

$currentName = (Get-CimInstance Win32_ComputerSystem).Name
if ($currentName -ne $NewName) {
    Rename-Computer -NewName $NewName -Force
    Write-Host "Computer renamed to $NewName" -ForegroundColor Green

    $RegPath = "HKLM:\SOFTWARE\Serco\ComputerRename"
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }
    Set-ItemProperty -Path $RegPath -Name "Renamed" -Value "True"
    Set-ItemProperty -Path $RegPath -Name "NewName" -Value $NewName
    Write-Host "Registry updated with rename info." -ForegroundColor Green
} else {
    Write-Host "Computer already named correctly as $NewName" -ForegroundColor Yellow
}

# Run OOBEDeploy (reads JSON config from C:\ProgramData\OSDeploy)
Start-OOBEDeploy

Write-Host "OOBE tasks completed. Restarting device..." -ForegroundColor Cyan
Restart-Computer -Force


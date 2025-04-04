# Allow script to run without interactive confirmation 
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Host "Installing required PowerShell modules for OOBE tasks..." -ForegroundColor Cyan
Install-Module -Name OSD -Force -Verbose

# Create log file
$LogFile = "C:\ProgramData\RenameComputer.log"
Function Write-Log {
    param ([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$TimeStamp - $Message"
}
Write-Log "Starting OOBE Finalize Script"

# Set Computer Name Logic: LPG (Laptop) / DSG (Desktop) + Serial
Write-Host "Determining device type for naming..." -ForegroundColor Cyan
if (Get-CimInstance Win32_Battery) {
    $Prefix = "LPG"
    Write-Host "Device identified as LAPTOP. Prefix set to 'LPG'."
    Write-Log "Device identified as LAPTOP. Prefix = LPG"
} else {
    $Prefix = "DSG"
    Write-Host "Device identified as DESKTOP. Prefix set to 'DSG'."
    Write-Log "Device identified as DESKTOP. Prefix = DSG"
}

$Serial = (Get-WmiObject -Class Win32_BIOS).SerialNumber.Trim()
$MaxLen = 15 - $Prefix.Length
if ($Serial.Length -gt $MaxLen) {
    $Serial = $Serial.Substring(0, $MaxLen)
}
$NewComputerName = "$Prefix$Serial"

$currentName = (Get-CimInstance Win32_ComputerSystem).Name
if ($currentName -ne $NewComputerName) {
    Rename-Computer -NewName $NewComputerName -Force
    Write-Log "Renamed computer to $NewComputerName"
} else {
    Write-Log "Computer already named $NewComputerName"
}

# Registry Key for Intune Detection
$RegistryPath = "HKLM:\SOFTWARE\Serco\ComputerRename"
if (-not (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
Set-ItemProperty -Path $RegistryPath -Name "Renamed" -Value "True"
Set-ItemProperty -Path $RegistryPath -Name "NewName" -Value $NewComputerName
Write-Log "Registry key set for rename detection"

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

# Run OOBEDeploy
Write-Host "Running OOBEDeploy tasks..." -ForegroundColor Cyan
Start-OOBEDeploy
Write-Log "Start-OOBEDeploy executed"

# Reboot
Write-Host "OOBE Finalization complete. Restarting..." -ForegroundColor Cyan
Write-Log "Rebooting device"
Restart-Computer -Force

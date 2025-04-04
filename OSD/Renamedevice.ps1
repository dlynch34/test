# Define log file path
$LogFile = "C:\ProgramData\RenameComputer.log"

# Function to write logs
Function Write-Log {
    param ([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$TimeStamp - $Message"
}

Write-Log "Starting Rename Script"

# Determine device type
if (Get-CimInstance Win32_Battery) {
    $Prefix = "LPG"
    Write-Log "Device identified as LAPTOP. Prefix: $Prefix"
} else {
    $Prefix = "DSG"
    Write-Log "Device identified as DESKTOP. Prefix: $Prefix"
}

# Get serial number and trim if needed
$Serial = (Get-WmiObject -Class Win32_BIOS).SerialNumber.Trim()
$MaxSerialLength = 15 - $Prefix.Length
if ($Serial.Length -gt $MaxSerialLength) {
    $Serial = $Serial.Substring(0, $MaxSerialLength)
}
$NewName = "$Prefix$Serial"
Write-Log "Generated Computer Name: $NewName"

# Get current name
$CurrentName = (Get-CimInstance Win32_ComputerSystem).Name
if ($CurrentName -eq $NewName) {
    Write-Log "Computer name is already correct."
    exit 0
}

# Try renaming the computer
Try {
    Rename-Computer -NewName $NewName -Force -ErrorAction Stop
    Write-Log "Rename successful. Will apply after reboot."

    # Set registry for reference or Intune detection
    $RegistryPath = "HKLM:\SOFTWARE\Serco\ComputerRename"
    if (-not (Test-Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $RegistryPath -Name "Renamed" -Value "True"
    Set-ItemProperty -Path $RegistryPath -Name "NewName" -Value $NewName
    Write-Log "Registry keys set successfully."
}
Catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}

[CmdletBinding()]
param()

$ScriptName = 'sandbox.osdcloud.com'
$ScriptVersion = '25.3.1.1'

#region Initialize
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-$ScriptName.log"
$null = Start-Transcript -Path (Join-Path "$env:SystemRoot\Temp" $Transcript) -ErrorAction Ignore

if ($env:SystemDrive -eq 'X:') {
    $WindowsPhase = 'WinPE'
}
else {
    $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
    if ($env:UserName -eq 'defaultuser0') {$WindowsPhase = 'OOBE'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') {$WindowsPhase = 'Specialize'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') {$WindowsPhase = 'AuditMode'}
    else {$WindowsPhase = 'Windows'}
}

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion ($WindowsPhase Phase)"
#endregion

#region Admin Elevation
$whoiam = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$isElevated = ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isElevated) {
    Write-Host -ForegroundColor Green "[+] Running as $whoiam (Admin Elevated)"
} else {
    Write-Host -ForegroundColor Red "[!] Running as $whoiam (NOT Admin Elevated)"
    break
}
#endregion

#region TLS 1.2
Write-Host -ForegroundColor Green "[+] Enabling TLS 1.2"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
#endregion

#region WinPE Phase
if ($WindowsPhase -eq 'WinPE') {
    Write-Host -ForegroundColor Cyan "[Test] Starting OSDCloud..."
    Start-OSDCloud -ZTI -OSLanguage en-us -OSBuild 24H2 -OSEdition Enterprise -Verbose

    Write-Host -ForegroundColor Cyan "[Test] Injecting OOBE files..."
    $OSDrive = "C:"
    $ProgramDataPath = Join-Path $OSDrive "ProgramData\OSDeploy"
    $PantherPath     = Join-Path $OSDrive "Windows\Panther"
    $ScriptsPath     = Join-Path $OSDrive "Windows\Setup\Scripts"

    New-Item -Path $ProgramDataPath -ItemType Directory -Force | Out-Null
    New-Item -Path $PantherPath -ItemType Directory -Force | Out-Null
    New-Item -Path $ScriptsPath -ItemType Directory -Force | Out-Null

    $OOBEDeployUrl    = "https://raw.githubusercontent.com/dlynch34/test/main/OSD/OSDeploy.OOBEDeploy.json"
    $UnattendUrl      = "https://raw.githubusercontent.com/dlynch34/test/main/OSD/Unattend.xml"
    $SetupCompleteUrl = "https://raw.githubusercontent.com/dlynch34/test/main/OSD/setupcomplete.cmd"

    try {
        Write-Host "[Test] Downloading OOBEDeploy JSON..."
        Invoke-WebRequest -Uri $OOBEDeployUrl -OutFile (Join-Path $ProgramDataPath "OSDeploy.OOBEDeploy.json") -UseBasicParsing
        Write-Host -ForegroundColor Green "✅ OSDeploy.OOBEDeploy.json downloaded"
    } catch {
        Write-Warning "⚠️ Failed to download OOBEDeploy JSON: $_"
    }

    try {
        Write-Host "[Test] Downloading Unattend.xml..."
        Invoke-WebRequest -Uri $UnattendUrl -OutFile (Join-Path $PantherPath "Unattend.xml") -UseBasicParsing
        Write-Host -ForegroundColor Green "✅ Unattend.xml downloaded"
    } catch {
        Write-Warning "⚠️ Failed to download Unattend.xml: $_"
    }

    try {
        Write-Host "[Test] Downloading SetupComplete.cmd..."
        Invoke-WebRequest -Uri $SetupCompleteUrl -OutFile (Join-Path $ScriptsPath "SetupComplete.cmd") -UseBasicParsing
        Write-Host -ForegroundColor Green "✅ SetupComplete.cmd downloaded"
    } catch {
        Write-Warning "⚠️ Failed to download SetupComplete.cmd: $_"
    }
# Download RemoveBitlockerblock.ps1 (for post-OOBE scheduled task)
$BitLockerBlockUrl = "https://raw.githubusercontent.com/dlynch34/test/main/OSD/RemoveBitlockerblock.ps1"
$BitLockerBlockPath = "C:\ProgramData\Remove-BitLockerBlock.ps1"

try {
    Write-Host "[Test] Downloading RemoveBitlockerblock.ps1..."
    Invoke-WebRequest -Uri $BitLockerBlockUrl -OutFile $BitLockerBlockPath -UseBasicParsing
    Write-Host -ForegroundColor Green "✅ RemoveBitlockerblock.ps1 downloaded to C:\ProgramData"
} catch {
    Write-Warning "⚠️ Failed to download RemoveBitlockerblock.ps1: $_"
}

    $null = Stop-Transcript -ErrorAction Ignore

    if (-not (Test-Path "C:\Windows")) {
        Write-Host -ForegroundColor Red "[!] WARNING: C:\\Windows not found. OS may have failed to stage."
    } else {
        Write-Host -ForegroundColor Green "[+] Detected C:\\Windows - OS appears staged successfully."
    }

    Read-Host "Press Enter to reboot..."
    Write-Host -ForegroundColor Green "Restarting..."
    wpeutil reboot
}
#endregion

#region Specialize Phase
if ($WindowsPhase -eq 'Specialize') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region AuditMode Phase
if ($WindowsPhase -eq 'AuditMode') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region OOBE Phase
if ($WindowsPhase -eq 'OOBE') {
    Write-Host -ForegroundColor Yellow "OOBE Phase - no config written here, it was injected in WinPE"
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region Full Windows Phase
if ($WindowsPhase -eq 'Windows') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

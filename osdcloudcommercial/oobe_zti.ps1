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

Write-Host "[+] $ScriptName $ScriptVersion ($WindowsPhase Phase)"
#endregion

#region Admin Elevation
$whoiam = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$isElevated = ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isElevated) {
    Write-Host "[+] Running as $whoiam (Admin Elevated)"
} else {
    Write-Host "[!] Running as $whoiam (NOT Admin Elevated)"
    break
}
#endregion

#region TLS 1.2
Write-Host "[+] Enabling TLS 1.2"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
#endregion

#region WinPE Phase
if ($WindowsPhase -eq 'WinPE') {
    Write-Host "[*] Starting OSDCloud..."
    Start-OSDCloud -ZTI -OSLanguage en-us -OSBuild 24H2 -OSEdition Pro -Verbose

    Write-Host "[*] Injecting OOBE files..."
    $OSDrive = "C:"
    $ProgramDataPath = Join-Path $OSDrive "ProgramData"
    $PantherPath     = Join-Path $OSDrive "Windows\Panther"
    $ScriptsPath     = Join-Path $OSDrive "Windows\Setup\Scripts"
    $OOBECloudPath   = Join-Path $OSDrive "OSD"

    New-Item -Path $ProgramDataPath -ItemType Directory -Force | Out-Null
    New-Item -Path $PantherPath -ItemType Directory -Force | Out-Null
    New-Item -Path $ScriptsPath -ItemType Directory -Force | Out-Null
    New-Item -Path $OOBECloudPath -ItemType Directory -Force | Out-Null

    # Define URLs
    $OOBEDeployUrl    = "https://raw.githubusercontent.com/dlynch34/test/main/OSD/OSDeploy.OOBEDeploy.json"
    $UnattendUrl      = "https://raw.githubusercontent.com/dlynch34/test/main/OSD/Unattend.xml"
    $OOBEFinalizeUrl  = "https://raw.githubusercontent.com/dlynch34/test/main/OSD/OOBEFinalize.ps1"

    # Download OSDeploy JSON
    try {
        $OOBEDeployPath = Join-Path $ProgramDataPath "OSDeploy"
        New-Item -Path $OOBEDeployPath -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $OOBEDeployUrl -OutFile (Join-Path $OOBEDeployPath "OSDeploy.OOBEDeploy.json") -UseBasicParsing
        Write-Host "[+] OSDeploy.OOBEDeploy.json downloaded"
    } catch {
        Write-Host "[!] Failed to download OSDeploy.OOBEDeploy.json: $_"
    }

    # Download Unattend.xml
    try {
        Invoke-WebRequest -Uri $UnattendUrl -OutFile (Join-Path $PantherPath "Unattend.xml") -UseBasicParsing
        Write-Host "[+] Unattend.xml downloaded"
    } catch {
        Write-Host "[!] Failed to download Unattend.xml: $_"
    }

    # Download and prepare OOBEFinalize.ps1 and SetupComplete.cmd
    try {
        $OOBEFinalizeDst = Join-Path $ScriptsPath "OOBEFinalize.ps1"
        $SetupCompletePath = Join-Path $ScriptsPath "SetupComplete.cmd"

        # Clean-download OOBEFinalize.ps1 without BOM
        $rawScript = Invoke-WebRequest -Uri $OOBEFinalizeUrl -UseBasicParsing
        $rawScript.Content | Set-Content -Path $OOBEFinalizeDst -Encoding UTF8
        Write-Host "[+] OOBEFinalize.ps1 downloaded and cleaned (no BOM)"

        # Write SetupComplete.cmd that runs OOBEFinalize.ps1
        @"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""%SystemRoot%\Setup\Scripts\OOBEFinalize.ps1""
exit /b 0
"@ | Set-Content -Path $SetupCompletePath -Encoding ASCII -Force

        Write-Host "[+] SetupComplete.cmd written to launch OOBEFinalize.ps1"
    } catch {
        Write-Host "[!] Failed to prepare OOBE finalization script: $_"
    }

    # Wrap-up and reboot
    $null = Stop-Transcript -ErrorAction Ignore

    if (-not (Test-Path "C:\Windows")) {
        Write-Host "[!] WARNING: C:\Windows not found. OS may have failed to stage."
    } else {
        Write-Host "[+] Detected C:\Windows - OS appears staged successfully."
    }

    Write-Host "[+] Restarting..."
    wpeutil reboot
}
#endregion

#region Other Phases
$null = Stop-Transcript -ErrorAction Ignore
#endregion

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
    $ProgramDataPath = Join-Path $OSDrive "ProgramData"
    $PantherPath     = Join-Path $OSDrive "Windows\Panther"
    $ScriptsPath     = Join-Path $OSDrive "Windows\Setup\Scripts"
    $OOBECloudPath   = Join-Path $OSDrive "OSD"

    New-Item -Path $ProgramDataPath -ItemType Directory -Force | Out-Null
    New-Item -Path $PantherPath -ItemType Directory -Force | Out-Null
    New-Item -Path $ScriptsPath -ItemType Directory -Force | Out-Null
    New-Item -Path $OOBECloudPath -ItemType Directory -Force | Out-Null

    $OOBEDeployUrl      = "https://raw.githubusercontent.com/dlynch34/test/main/OSD/OSDeploy.OOBEDeploy.json"
    $UnattendUrl        = "https://raw.githubusercontent.com/dlynch34/test/main/OSD/Unattend.xml"
    $SetupCompleteUrl   = "https://raw.githubusercontent.com/dlynch34/test/main/OSD/setupcomplete.cmd"
    $OOBEFinalizeUrl    = "https://raw.githubusercontent.com/dlynch34/test/main/OSD/OOBEFinalize.ps1"

    try {
        Invoke-WebRequest -Uri $SetupCompleteUrl -OutFile (Join-Path $ScriptsPath "SetupComplete.cmd") -UseBasicParsing
        Write-Host -ForegroundColor Green "✅ setupcomplete.cmd downloaded"
    } catch {
        Write-Warning "⚠️ Failed to download setupcomplete.cmd: $_"
    }

    try {
        $OOBEDeployPath = Join-Path $ProgramDataPath "OSDeploy"
        New-Item -Path $OOBEDeployPath -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $OOBEDeployUrl -OutFile (Join-Path $OOBEDeployPath "OSDeploy.OOBEDeploy.json") -UseBasicParsing
        Write-Host -ForegroundColor Green "✅ OSDeploy.OOBEDeploy.json downloaded"
    } catch {
        Write-Warning "⚠️ Failed to download OSDeploy.OOBEDeploy.json: $_"
    }

    try {
        Invoke-WebRequest -Uri $UnattendUrl -OutFile (Join-Path $PantherPath "Unattend.xml") -UseBasicParsing
        Write-Host -ForegroundColor Green "✅ Unattend.xml downloaded"
    } catch {
        Write-Warning "⚠️ Failed to download Unattend.xml: $_"
    }

    try {
        Invoke-WebRequest -Uri $OOBEFinalizeUrl -OutFile (Join-Path $OOBECloudPath "OOBEFinalize.ps1") -UseBasicParsing
        Write-Host -ForegroundColor Green "✅ OOBEFinalize.ps1 downloaded to C:\OSD"
    } catch {
        Write-Warning "⚠️ Failed to download OOBEFinalize.ps1: $_"
    }

    $null = Stop-Transcript -ErrorAction Ignore

    if (-not (Test-Path "C:\Windows")) {
        Write-Host -ForegroundColor Red "[!] WARNING: C:\Windows not found. OS may have failed to stage."
    } else {
        Write-Host -ForegroundColor Green "[+] Detected C:\Windows - OS appears staged successfully."
    }

    Write-Host -ForegroundColor Green "Restarting..."
    wpeutil reboot
}
#endregion

#region Other Phases
$null = Stop-Transcript -ErrorAction Ignore
#endregion


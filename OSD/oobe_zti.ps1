[CmdletBinding()]
param()

$ScriptName = 'sandbox.osdcloud.com'
$ScriptVersion = '23.6.10.1'

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
Invoke-Expression -Command (Invoke-RestMethod -Uri https://functions.osdcloud.com)
#endregion

#region Admin Elevation
$whoiam = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
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
    osdcloud-StartWinPE -OSDCloud
    Start-OSDCloud -ZTI -OSLanguage en-us -OSBuild 24H2 -OSEdition Enterprise -Verbose

    # Create SetupComplete.cmd for post-install OOBE execution
    $setupScript = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/dlynch34/test/main/OSD/oobe_zti.ps1 | iex\"' -WindowStyle Hidden"
'@
    New-Item -ItemType Directory -Force -Path "C:\Windows\Setup\Scripts" | Out-Null
    $setupScript | Set-Content -Path "C:\Windows\Setup\Scripts\SetupComplete.cmd" -Encoding Ascii

    $null = Stop-Transcript -ErrorAction Ignore
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
    Write-Host -ForegroundColor Green "Creating OSDeploy.OOBEDeploy.json with language and regional settings..."
    $OOBEDeployJson = @'
{
    "AddNetFX3": { "IsPresent": true },
    "Autopilot": { "IsPresent": false },
    "SetLanguage": {
        "GeoID": 244,
        "InputLocale": "en-US",
        "SystemLocale": "en-US",
        "UILanguage": "en-US",
        "UserLocale": "en-US",
        "TimeZone": "Eastern Standard Time"
    },
    "RemoveAppx": [
        "MicrosoftTeams",
        "Microsoft.BingWeather",
        "Microsoft.BingNews",
        "Microsoft.GamingApp",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.Messaging",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.MicrosoftStickyNotes",
        "Microsoft.MSPaint",
        "Microsoft.People",
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.StorePurchaseApp",
        "Microsoft.Todos",
        "microsoft.windowscommunicationsapps",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.YourPhone",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo"
    ],
    "UpdateDrivers": { "IsPresent": true },
    "UpdateWindows": { "IsPresent": true }
}
'@

    if (!(Test-Path "C:\ProgramData\OSDeploy")) {
        New-Item "C:\ProgramData\OSDeploy" -ItemType Directory -Force | Out-Null
    }
    $OOBEDeployJson | Out-File -FilePath "C:\ProgramData\OSDeploy\OSDeploy.OOBEDeploy.json" -Encoding ascii -Force

    osdcloud-StartOOBE -Display -Language -DateTime -Autopilot -InstallWinGet -WinGetUpgrade -WinGetPwsh
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region Full Windows Phase
if ($WindowsPhase -eq 'Windows') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

# Final Reboot
Write-Host -ForegroundColor Green "Restarting in 20 seconds!"
Start-Sleep -Seconds 20
wpeutil reboot

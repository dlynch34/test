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
$isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")
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

    # Start OSDCloud installation
    Start-OSDCloud -ZTI -OSLanguage en-us -OSBuild 24H2 -OSEdition Enterprise -Verbose

    # Create OOBE.cmd to run GitHub-hosted oobe_zti.ps1 script
    $OOBECmd = @'
PowerShell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "iwr -useb https://raw.githubusercontent.com/dlynch34/test/main/OSD/oobe_zti.ps1 | iex"
'@
    $OOBECmd | Out-File -FilePath 'C:\Windows\System32\OOBE.cmd' -Encoding ascii -Force

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
    Write-Host -ForegroundColor Green "[+] OOBE phase reached, nothing further handled in sandbox script."
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region Full Windows Phase
if ($WindowsPhase -eq 'Windows') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#=======================================================================
#   Optional: Restart WinPE
#=======================================================================
if ($WindowsPhase -eq 'WinPE') {
    Write-Host -ForegroundColor Green "Restarting in 20 seconds..."
    Start-Sleep -Seconds 20
    wpeutil reboot
}

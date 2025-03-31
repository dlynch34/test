# Set PowerShell Window Title
$host.UI.RawUI.WindowTitle = "Set-KeyboardLanguage"

# Ensure TLS 1.2 for secure communications
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

# Set system profile paths for compatibility with Intune/MDT
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$env:PSModulePath += ";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"

# Start transcript logging
$logName = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-Set-KeyboardLanguage.log"
$logPath = Join-Path "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD" $logName
Start-Transcript -Path $logPath -ErrorAction Ignore

# Clear existing languages and set only en-US
Write-Host -ForegroundColor Cyan "Configuring keyboard layout to use ONLY en-US..."
$LanguageList = New-WinUserLanguageList -Language "en-US"
Set-WinUserLanguageList -LanguageList $LanguageList -Force

# End logging
Stop-Transcript

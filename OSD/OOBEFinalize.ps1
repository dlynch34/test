# Allow script to run without interactive confirmation
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Setup log path
$logPath = "C:\ProgramData\OOBEFinalize.log"
function Write-Log {
    param([string]$msg)
    Add-Content -Path $logPath -Value "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') - $msg"
}
Write-Log "===== Starting OOBE Finalization ====="

# Prevent Windows 11 automatic device encryption
try {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "PreventDeviceEncryption" -Value 1 -Type DWord -Force
    Write-Log "✅ PreventDeviceEncryption registry key set"
} catch {
    Write-Log "❌ Failed to set PreventDeviceEncryption key: $($_.Exception.Message)"
}

# Install and import OSD module
try {
    if (-not (Get-Module -ListAvailable -Name OSD)) {
        Install-Module -Name OSD -Force -Verbose
        Write-Log "✅ OSD module installed"
    }
    Import-Module OSD -Force -Verbose
    Write-Log "✅ OSD module imported successfully"
} catch {
    Write-Log "❌ Failed to install/import OSD module: $($_.Exception.Message)"
}

# Enable FIPS policy
try {
    $FipsRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy"
    if (-not (Test-Path $FipsRegistryPath)) {
        New-Item -Path $FipsRegistryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $FipsRegistryPath -Name "Enabled" -Value 1
    Write-Log "✅ FIPS Algorithm Policy enabled"
} catch {
    Write-Log "❌ Failed to set FIPS policy: $($_.Exception.Message)"
}

# Set Data Execution Prevention to OptOut
try {
    Start-Process -FilePath "bcdedit.exe" -ArgumentList "/set nx optout" -NoNewWindow -Wait
    Write-Log "✅ Successfully executed: bcdedit /set nx optout"
} catch {
    Write-Log "❌ Failed to execute bcdedit: $($_.Exception.Message)"
}

# Remove built-in apps (Windows 11 bloatware)
Write-Log "📦 Starting removal of built-in apps and provisioned packages..."

$AppsToRemove = @(
    "MicrosoftTeams",
    "Microsoft.BingWeather",
    "Microsoft.BingNews",
    "Microsoft.GamingApp",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
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
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.OutlookForWindows",
    "5319275A.WhatsAppDesktop",
    "Facebook.InstagramBeta",
    "Facebook.Facebook",
    "TikTok.TikTok",
    "AmazonVideo.PrimeVideo",
    "Microsoft.Microsoft365"
)

foreach ($app in $AppsToRemove) {
    try {
        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Stop
        Write-Log "✅ Removed installed package: $app"
    } catch {
        Write-Log "⚠️ Could not remove installed package $app: $($_.Exception.Message)"
    }

    try {
        Get-AppxProvisionedPackage -Online | Where-Object DisplayName -EQ $app |
            Remove-AppxProvisionedPackage -Online -ErrorAction Stop
        Write-Log "🗑️ Removed provisioned package: $app"
    } catch {
        Write-Log "⚠️ Could not remove provisioned package $app: $($_.Exception.Message)"
    }
}

Write-Log "✅ OOBE Finalization complete."

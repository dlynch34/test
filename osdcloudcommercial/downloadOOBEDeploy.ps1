$OOBEDeployUrl = "https://raw.githubusercontent.com/dlynch34/test/main/osdcloudcommercial/OSDeploy.OOBEDeploy.json"
$OOBEDeployPath = "C:\ProgramData\OSDeploy"

try {
    Write-Host "⏳ Downloading OSDeploy.OOBEDeploy.json..." -ForegroundColor Cyan

    if (-not (Test-Path $OOBEDeployPath)) {
        New-Item -Path $OOBEDeployPath -ItemType Directory -Force | Out-Null
    }

    Invoke-WebRequest -Uri $OOBEDeployUrl -OutFile "$OOBEDeployPath\OSDeploy.OOBEDeploy.json" -UseBasicParsing

    if (Test-Path "$OOBEDeployPath\OSDeploy.OOBEDeploy.json") {
        Write-Host "✅ OOBEDeploy config downloaded successfully to $OOBEDeployPath" -ForegroundColor Green
    } else {
        Write-Warning "❌ Failed to download OOBEDeploy config"
    }
}
catch {
    Write-Warning "⚠️ Error downloading OOBEDeploy config: $_"
}

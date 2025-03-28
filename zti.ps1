# Load WinForms support
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Serco OSDCloud Deployment"
$form.Size = New-Object System.Drawing.Size(600,400)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

# Create Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Starting Serco's OSDCloud Provisioning..."
$statusLabel.AutoSize = $false
$statusLabel.Size = New-Object System.Drawing.Size(560, 30)
$statusLabel.Location = New-Object System.Drawing.Point(10, 10)
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# Create TextBox for Logging
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.Size = New-Object System.Drawing.Size(560, 270)
$logBox.Location = New-Object System.Drawing.Point(10, 50)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)

# Create Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Style = 'Marquee'
$progressBar.MarqueeAnimationSpeed = 30
$progressBar.Size = New-Object System.Drawing.Size(560, 20)
$progressBar.Location = New-Object System.Drawing.Point(10, 330)

# Add controls
$form.Controls.Add($statusLabel)
$form.Controls.Add($logBox)
$form.Controls.Add($progressBar)

# Show the form non-modally
$form.Show()
[System.Windows.Forms.Application]::DoEvents()

# Utility to write both to log and status
function Update-Status {
    param ([string]$msg)
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $logBox.AppendText("[$timestamp] $msg`r`n")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
    $statusLabel.Text = $msg
    [System.Windows.Forms.Application]::DoEvents()
}

# BEGIN DEPLOYMENT WORKFLOW

Update-Status "Setting display resolution for Virtual Machines (if detected)..."
Start-Sleep -Seconds 2
if ((Get-MyComputerModel) -match 'Virtual') {
    Update-Status "Detected Virtual Machine. Setting display resolution to 1600x"
    Set-DisRes 1600
    Start-Sleep -Seconds 1
}

#Update-Status "Updating OSD PowerShell Module..."
#Install-Module OSD -Force
#Start-Sleep -Seconds 1

#Update-Status "Importing OSD PowerShell Module..."
#Import-Module OSD -Force
#Start-Sleep -Seconds 1

Update-Status "Launching OSDCloud ZTI for Serco..."
Start-Sleep -Seconds 2
Start-OSDCloud -OSLanguage en-us -OSBuild 24H2 -OSEdition Enterprise -ZTI

Update-Status "Running post-actions (placeholder)..."
Start-Sleep -Seconds 1
# Add post-deployment logic here if needed

Update-Status "Deployment Complete. Rebooting in 20 seconds..."
Start-Sleep -Seconds 20

# Close form and reboot
$form.Close()
wpeutil reboot

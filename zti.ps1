# Hide the PowerShell window
Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
'
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) # 0 = Hide

# Load WinForms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# GUI Setup
$form = New-Object System.Windows.Forms.Form
$form.Text = "Serco OSDCloud Deployment"
$form.Size = New-Object System.Drawing.Size(800, 500)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Initializing..."
$statusLabel.Size = New-Object System.Drawing.Size(760, 30)
$statusLabel.Location = New-Object System.Drawing.Point(20, 10)
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.WordWrap = $false
$logBox.Size = New-Object System.Drawing.Size(760, 370)
$logBox.Location = New-Object System.Drawing.Point(20, 50)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Style = 'Marquee'
$progressBar.MarqueeAnimationSpeed = 30
$progressBar.Size = New-Object System.Drawing.Size(760, 20)
$progressBar.Location = New-Object System.Drawing.Point(20, 430)

$form.Controls.AddRange(@($statusLabel, $logBox, $progressBar))
$form.Show()
[System.Windows.Forms.Application]::DoEvents()

# Function to write to log and label
function Update-Log {
    param([string]$Message)
    $timestamp = (Get-Date -Format "HH:mm:ss")
    $logBox.AppendText("[$timestamp] $Message`r`n")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
    $statusLabel.Text = $Message
    [System.Windows.Forms.Application]::DoEvents()
}

# Set resolution for VMs
Update-Log "Checking if running in VM..."
Start-Sleep -Milliseconds 500
if ((Get-MyComputerModel) -match 'Virtual') {
    Update-Log "Virtual Machine detected. Setting display resolution to 1600x..."
    Set-DisRes 1600
    Start-Sleep -Milliseconds 500
}

# Run OSDCloud and capture its output
Update-Log "Launching OSDCloud ZTI for Serco..."

$job = Start-Job {
    Start-OSDCloud -OSLanguage en-us -OSBuild 24H2 -OSEdition Enterprise -ZTI -Verbose 4>&1
}

# Poll job output and push to GUI
while ($job.State -eq 'Running') {
    $lines = Receive-Job -Job $job -OutVariable +null
    if ($lines) {
        foreach ($line in $lines) {
            $script:logBox.Invoke([Action]{
                $logBox.AppendText("$line`r`n")
                $logBox.SelectionStart = $logBox.Text.Length
                $logBox.ScrollToCaret()
            })
        }
    }
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 300
}

# Final output after job completes
$finalLines = Receive-Job -Job $job
if ($finalLines) {
    foreach ($line in $finalLines) {
        $logBox.AppendText("$line`r`n")
    }
}
Remove-Job $job

Update-Log "Post-action steps (placeholder)..."
Start-Sleep -Seconds 2

Update-Log "Deployment complete. Rebooting in 15 seconds..."
Start-Sleep -Seconds 15
$form.Close()

# Reboot system
wpeutil reboot

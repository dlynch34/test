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

# Build Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Serco OSDCloud Deployment"
$form.Size = New-Object System.Drawing.Size(800, 500)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

# Controls
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

# Logging Function
function Update-Log {
    param([string]$Message)
    $timestamp = (Get-Date -Format "HH:mm:ss")
    $logBox.AppendText("[$timestamp] $Message`r`n")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
    $statusLabel.Text = $Message
    [System.Windows.Forms.Application]::DoEvents()
}

# Set resolution for VM
Update-Log "Checking for virtual machine environment..."
Start-Sleep -Milliseconds 500
if ((Get-MyComputerModel) -match 'Virtual') {
    Update-Log "Virtual Machine detected. Setting resolution to 1600x..."
    Set-DisRes 1600
    Start-Sleep -Milliseconds 500
}

# Build script block to run OSDCloud
$tempScriptPath = "$env:TEMP\osd_run.ps1"
@"
Start-OSDCloud -OSLanguage en-us -OSBuild 24H2 -OSEdition Enterprise -ZTI -Verbose
"@ | Out-File -FilePath $tempScriptPath -Encoding UTF8 -Force

Update-Log "Launching OSDCloud ZTI for Serco..."

# Start the external PowerShell process
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = "powershell.exe"
$startInfo.Arguments = "-ExecutionPolicy Bypass -NoProfile -File `"$tempScriptPath`""
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $startInfo
$process.Start() | Out-Null

# Read and display output in real time
while (!$process.HasExited) {
    while (!$process.StandardOutput.EndOfStream) {
        $line = $process.StandardOutput.ReadLine()
        Update-Log $line
    }
    while (!$process.StandardError.EndOfStream) {
        $err = $process.StandardError.ReadLine()
        Update-Log "ERROR: $err"
    }
    Start-Sleep -Milliseconds 100
    [System.Windows.Forms.Application]::DoEvents()
}

Update-Log "OSDCloud process completed."

# Delay and reboot
Update-Log "Deployment complete. Rebooting in 15 seconds..."
Start-Sleep -Seconds 15
$form.Close()
wpeutil reboot

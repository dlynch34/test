# Wait 15 minutes to allow Intune sync and BitLocker policy to apply
Start-Sleep -Seconds 900

# Attempt to remove the PreventDeviceEncryption key
Try {
    Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker' -Name 'PreventDeviceEncryption' -Force
    "`$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') - ✅ Removed PreventDeviceEncryption key for BitLocker policy" | Out-File -Append -FilePath 'C:\ProgramData\OOBEFinalize.log'
} Catch {
    "`$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') - ❌ Failed to remove PreventDeviceEncryption key: $($_.Exception.Message)" | Out-File -Append -FilePath 'C:\ProgramData\OOBEFinalize.log'
}

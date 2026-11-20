# Enables Developer Mode (needed for symlinks without elevation). Run as administrator (PowerShell 7).
Write-Host "► Enabling Developer Mode" -ForegroundColor Cyan

$path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
if (-not (Test-Path $path)) {
    New-Item -Path $path | Out-Null
}
Set-ItemProperty -Path $path -Name 'AllowDevelopmentWithoutDevLicense' -Value 1 -Type DWord

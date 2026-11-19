# Enables Developer Mode (needed for symlinks without elevation). Run as administrator.
Write-Host "► Enabling Developer Mode" -ForegroundColor Cyan

$path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
$name = 'AllowDevelopmentWithoutDevLicense'

if (-not (Test-Path $path)) {
    New-Item -Path $path -Force | Out-Null
}

$current = (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name
if ($current -ne 1) {
    Set-ItemProperty -Path $path -Name $name -Value 1 -Type DWord
}

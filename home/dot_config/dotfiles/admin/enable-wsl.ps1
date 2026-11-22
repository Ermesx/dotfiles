# Installs the WSL platform without a distro and updates it. Run as administrator (PowerShell 7).
# The distro is per user, so the user installs it after the restart (printed below).
Write-Host "► Enabling WSL" -ForegroundColor Cyan

wsl --install --no-distribution
wsl --update

Write-Host "► Next steps" -ForegroundColor Yellow
Write-Host "  1. Restart the computer."
Write-Host "  2. As the user, not as administrator, in a new PowerShell window: Complete-UserSetup"

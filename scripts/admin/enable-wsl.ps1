# Installs the WSL platform without a distro and updates it. Run as administrator.
Write-Host "► Enabling WSL" -ForegroundColor Cyan

wsl.exe --install --no-distribution
wsl.exe --update

Write-Host "A reboot may be needed before WSL works." -ForegroundColor Yellow

# Sets the ssh-agent service to start automatically and starts it. Run as administrator (PowerShell 7).
# The agent keeps keys per user, so the user loads the key (printed below).
Write-Host "► Enabling ssh-agent" -ForegroundColor Cyan

Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent

Write-Host "► Next step" -ForegroundColor Yellow
Write-Host '  As the user, not as administrator, load the key: ssh-add $HOME\.ssh\id_ed25519'

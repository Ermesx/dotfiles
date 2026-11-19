# Sets the ssh-agent service to start automatically and starts it. Run as administrator.
Write-Host "► Enabling ssh-agent" -ForegroundColor Cyan

Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent

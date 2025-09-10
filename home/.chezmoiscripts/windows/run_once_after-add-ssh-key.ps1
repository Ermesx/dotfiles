# Run ssh-agent and add the private key
Write-Host "► Add ssh key" -ForegroundColor Cyan
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
ssh-add $env:USERPROFILE\.ssh\id_ed25519  

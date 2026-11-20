if ((Get-Service ssh-agent -ErrorAction SilentlyContinue).Status -ne 'Running') {
    Write-Host "► Skipping SSH key: ssh-agent is not running (needs an administrator)" -ForegroundColor Yellow
    exit 0
}

Write-Host "► Add ssh key" -ForegroundColor Cyan
ssh-add (Join-Path $HOME ".ssh" "id_ed25519")

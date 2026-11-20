if ((Get-Service ssh-agent).Status -ne 'Running') {
    Write-Host "► Skipping SSH key: ssh-agent is not running. An administrator runs:" -ForegroundColor Yellow
    Write-Host "  & `"$HOME\scoop\apps\pwsh\current\pwsh.exe`" -NoProfile -ExecutionPolicy Bypass -File `"$HOME\.config\dotfiles\admin\enable-ssh-agent.ps1`""
    exit 0
}

Write-Host "► Add ssh key" -ForegroundColor Cyan
ssh-add (Join-Path $HOME ".ssh" "id_ed25519")

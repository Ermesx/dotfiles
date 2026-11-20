$key = Join-Path $HOME ".ssh" "id_ed25519"

if ((Get-Service ssh-agent -ErrorAction SilentlyContinue).Status -ne 'Running') {
    Write-Host "► Skipping SSH key: ssh-agent is not running" -ForegroundColor Yellow
    Write-Host "  An administrator reviews and runs, in their own PowerShell 7:"
    Write-Host "    pwsh -NoProfile -ExecutionPolicy Bypass -File `"$HOME\.config\dotfiles\admin\enable-ssh-agent.ps1`""
    Write-Host "  Then you run (no admin needed):"
    Write-Host "    ssh-add `"$key`""
    exit 0
}

Write-Host "► Add ssh key" -ForegroundColor Cyan
ssh-add $key

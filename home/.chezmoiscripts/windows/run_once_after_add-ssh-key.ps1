# Run ssh-agent and add the private key
Write-Host "► Add ssh key" -ForegroundColor Cyan
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
$key = Join-Path $HOME ".ssh" "id_ed25519"
$publicKey = (Get-Content "$key.pub") -replace '^(\S+ \S+).*', '$1'
if (-not ((ssh-add -L) -match [regex]::Escape($publicKey))) {
    ssh-add $key
}

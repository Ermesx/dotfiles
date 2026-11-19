$service = Get-Service ssh-agent -ErrorAction SilentlyContinue
if (-not $service -or $service.Status -ne 'Running') {
    Write-Host "► Skipping SSH key: ssh-agent service is not running (needs an administrator)" -ForegroundColor Yellow
    exit 0
}

$key = Join-Path (Join-Path $HOME ".ssh") "id_ed25519"
$fingerprint = (ssh-keygen -lf "$key.pub").Split(' ')[1]

if (-not ((ssh-add -l) -match [regex]::Escape($fingerprint))) {
    Write-Host "► Add ssh key" -ForegroundColor Cyan
    ssh-add $key
}

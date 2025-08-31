param (
    [string]$BRANCH = 'develop'
)
$ErrorActionPreference = "Stop"

# Set environment variable to indicate we are in a Vagrant environment
[System.Environment]::SetEnvironmentVariable("VAGRANT", "1", "User")
$env:VAGRANT = "1"

Write-Host "Install dotfiles:" -ForegroundColor Cyan
$script = 'https://raw.githubusercontent.com/Ermesx/dotfiles/refs/heads/migration-to-chezmoi/install.ps1'
Invoke-Expression "&{$(Invoke-RestMethod $script)} -BRANCH '$BRANCH'"

Write-Host "🧪 Running tests..." -ForegroundColor Cyan
pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File "C:\vagrant\execute-pester.ps1" 


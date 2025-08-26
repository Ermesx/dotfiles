$ErrorActionPreference = "Stop"

Write-Host "Install dotfiles:" -ForegroundColor Cyan
$script = 'https://raw.githubusercontent.com/Ermesx/dotfiles/refs/heads/migration-to-chezmoi/install.ps1'
Invoke-Expression "&{$(Invoke-RestMethod $script)} -BRANCH 'migration-to-chezmoi'"

Write-Host "🧪 Running tests..." -ForegroundColor Cyan
& "$PSScriptRoot\execute-pester.ps1" 


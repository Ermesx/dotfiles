$ErrorActionPreference = "Stop"

Import-Module Dotfiles-Toolkit

if (Test-CommandAvailable -Command "pwsh") {
    Write-Host "🌀 pwsh is available, attempting to upgrade..." -ForegroundColor Cyan
    winget upgrade Microsoft.Powershell --accept-source-agreements --accept-package-agreements --disable-interactivity
} else {
    Write-Host "🌀 Installing pwsh..." -ForegroundColor Cyan
    winget install Microsoft.Powershell --accept-source-agreements --accept-package-agreements --disable-interactivity

    # Update the PATH environment variable to include the new PowerShell installation
    Update-Env
}
$ErrorActionPreference = "Stop"
Import-Module Dotfiles-Toolkit

# Install or upgrade PowerShell
Write-Host "🌀 Installing Powershell 7..." -ForegroundColor Cyan
winget install Microsoft.Powershell --accept-source-agreements --accept-package-agreements --disable-interactivity

# Update the PATH environment variable to include the new PowerShell installation
if (-not (Test-CommandAvailable -Command "pwsh")) {    
    Update-Env
}
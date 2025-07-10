$ErrorActionPreference = "Stop"

Import-Module Dotfiles-Toolkit

if (Test-Installed -Id "Microsoft.WindowsTerminal") {
    Write-Host "🌀 Windows Terminal is already installed, upgrading..." -ForegroundColor Cyan
    winget upgrade Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements --disable-interactivity
} else {
    Write-Host "🌀 Installing Windows Terminal..." -ForegroundColor Cyan
    winget install Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements --disable-interactivity
}


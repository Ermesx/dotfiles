$ErrorActionPreference = "Stop"
Import-Module Dotfiles-Toolkit

# Install or upgrade Windows Terminal
Write-Host "🌀 Installing Windows Terminal..." -ForegroundColor Cyan
winget install Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements --disable-interactivity

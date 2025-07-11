# Parametr z nazwą fonta
param (
    [Parameter(Mandatory = $true)]
    [string]$FontName
)

$ErrorActionPreference = "Stop"
Import-Module Dotfiles-Toolkit

# Install or upgrade oh-my-posh
Write-Host "🌀 Installing oh-my-posh..." -ForegroundColor Cyan
winget install JanDeDobbeleer.OhMyPosh --accept-source-agreements --accept-package-agreements --disable-interactivity

if (-not (Test-CommandAvailable -Command "oh-my-posh")) {
    Update-Env
}

# Enable auto upgrade for oh-my-posh
oh-my-posh enable upgrade

# Install or upgrade Hasklig font
Write-Host "🌀 Installing Hasklig font..." -ForegroundColor Cyan
oh-my-posh font install $FontName
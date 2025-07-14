# Parametr z nazwą fonta
param (
    [Parameter(Mandatory = $true)]
    [string]$FontName
)

# Install or upgrade oh-my-posh
Install-OrUpdateApp -AppId "JanDeDobbeleer.OhMyPosh" -UpdateEnv -Command "oh-my-posh"

# Enable auto upgrade for oh-my-posh
oh-my-posh enable upgrade

# Install or upgrade Hasklig font
Write-Host "🌀 Installing Hasklig font..." -ForegroundColor Cyan
oh-my-posh font install $FontName
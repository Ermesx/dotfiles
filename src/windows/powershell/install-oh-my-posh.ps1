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
Write-Host "🌀 Installing $FontName font..." -ForegroundColor Cyan -NoNewline
oh-my-posh font install $FontName | Out-Null
Write-Host "`r✅ [OK] $FontName font is installed successfully." -ForegroundColor Green

Add-ToProfile -Comment "Initialize oh-my-posh" -ScriptBlock {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/jandedobbeleer.omp.json" | Invoke-Expression
}

# TODO dodać config aby wpisywanie było od nowej linie (2 linie w całości)
 
# Install or update Terminal-Icons
Install-OrUpdateModule -ModuleName Terminal-Icons
Add-ToProfile -Comment "Import Terminal-Icons" -ScriptBlock {
    Import-Module Terminal-Icons
}
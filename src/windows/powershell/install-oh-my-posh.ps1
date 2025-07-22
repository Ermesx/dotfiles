# Parametr z nazwą fonta
param (
    [Parameter(Mandatory = $true)]
    [string]$FontName,
    [Parameter(Mandatory = $true)]
    [string]$Theme
)

# Install or upgrade oh-my-posh
Install-OrUpdateApp -AppId "JanDeDobbeleer.OhMyPosh" -UpdateEnv -Command "oh-my-posh"

# Enable auto upgrade for oh-my-posh
oh-my-posh enable upgrade

# Install or upgrade font
Write-Pretty "🌀 Installing " -ForegroundColor '0,255,255' -FallbackForegroundColor Cyan -NoNewline;
Write-Pretty "__$($FontName)__" -NoNewline
Write-Host " font..." -NoNewline;

oh-my-posh font install $FontName | Out-Null

Write-Pretty "`r✅ [OK] " -ForegroundColor '0,255,0' -FallbackForegroundColor Green -NoNewline;
Write-Pretty "__$($FontName)__" -NoNewline;
Write-Host " font is installed successfully."

$script = Update-ScriptBlock -ScriptBlockTemplate {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/{{Theme}}.omp.json" | Invoke-Expression
} -Values @{ Theme = $Theme}
Add-ToProfile -Comment "Initialize oh-my-posh" -ScriptBlock $script
 
# Install or update Terminal-Icons
Install-OrUpdateModule -ModuleName Terminal-Icons
Add-ToProfile -Comment "Import Terminal-Icons" -ScriptBlock {
    Import-Module Terminal-Icons
}
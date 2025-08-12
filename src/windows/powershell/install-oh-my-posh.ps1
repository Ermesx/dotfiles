# Parametr z nazwą fonta
param (
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Fonts,
    [Parameter(Mandatory = $true)]
    [string]$Theme
)

# Change # and $ symbols in the prompt to icons
$configFilePath = "$env:POSH_THEMES_PATH/$Theme.omp.json"
$oldPrompt = ' {{ if .Root }}#{{else}}${{end}}'
$newPrompt = '{{ if .Root }}\uf0a9{{else}}\udb85\udd98{{end}}'
(Get-Content $configFilePath -Raw).Replace($oldPrompt, $newPrompt) | Out-File "$env:POSH_THEMES_PATH/$Theme.custom.omp.json" -Encoding utf8NoBOM -NoNewline

Add-ToProfile -Comment "Initialize oh-my-posh" -ScriptBlock (
    Update-ScriptBlock -ScriptBlockTemplate {
        oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/{{Theme}}.custom.omp.json" | Invoke-Expression
    } -Values @{ Theme = $Theme }
)

# Enable auto upgrade for oh-my-posh
oh-my-posh enable upgrade

# Install or upgrade font
Add-Type -AssemblyName PresentationCore
$fontsSource = ([Windows.Media.Fonts]::SystemFontFamilies.Source)
if ($fontsSource -notcontains $Fonts.exactName) {
    Write-Cyan "🌀 Installing " -NoNewline
    Write-Pretty "__$($Fonts.name)__" -NoNewline
    Write-Host " font..." -NoNewline;

    oh-my-posh font install $Fonts.name | Out-Null

    Write-Green "`r✅ [OK] " -NoNewline
    Write-Pretty "__$($Fonts.name)__" -NoNewline;
    Write-Host " font is installed successfully."
}
else {
    Write-Yellow "👌 [Skip] " -NoNewline
    Write-Pretty "__$($Fonts.name)__" -NoNewline;
    Write-Host " font is already installed."
}
 

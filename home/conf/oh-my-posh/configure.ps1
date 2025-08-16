# Load configuration
$config = Get-Content "$PSScriptRoot\config.yaml" | Convertfrom-Yaml

# Copy theme configuration
$theme = 'quick-term.custom.omp.json'
Copy-Item -Path "$PSScriptRoot\$theme" -Destination "$env:POSH_THEMES_PATH\$theme" -Force

# Install fonts
Add-Type -AssemblyName PresentationCore
$fontsSource = ([Windows.Media.Fonts]::SystemFontFamilies.Source)

if ($fontsSource -notcontains $config.font.exactName) {
    Write-Cyan "🌀 Installing " -NoNewline
    Write-Pretty "__$($config.font.name)__" -NoNewline
    Write-Host " font..." -NoNewline;

    oh-my-posh font install $config.font.name | Out-Null

    Write-Green "`r✅ [OK] " -NoNewline
    Write-Pretty "__$($config.font.name)__" -NoNewline;
    Write-Host " font is installed successfully."
}
else {
    Write-Yellow "👌 [Skip] " -NoNewline
    Write-Pretty "__$($config.font.name)__" -NoNewline;
    Write-Host " font is already installed."
}

# Enable auto upgrade for oh-my-posh
oh-my-posh enable upgrade
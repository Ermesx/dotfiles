param (
    [Parameter(Mandatory = $false)] 
    [PScustomObject]$Fonts
)

$ErrorActionPreference = "Stop"
Import-Module Dotfiles-Toolkit

Write-Host "🎨 Installing fonts: $($Fonts.name) from: `n`t$($Fonts.sourceUrl)..." -ForegroundColor Cyan

# Install Nerd Fonts if not already installed
$fontUrl = $Fonts.sourceUrl
$zipPath = "$env:TEMP\$(Split-Path -Path $fontUrl -Leaf)"
$extractPath = "$env:TEMP\fonts"

if (-Not (Test-Path -Path $zipPath) -Or -Not (Test-Path -Path $extractPath)) {
    Invoke-WebRequest -Uri $fontUrl -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
} 

$fontFiles = Get-ChildItem -Path $extractPath -Recurse -Include *.ttf, *.otf

# Copy font files to the Windows Fonts directory
foreach ($file in $fontFiles) {
    $fontDest = "$env:WINDIR\Fonts\$($file.Name)"
    Copy-Item -Path $file.FullName -Destination $fontDest -Force
}

# Register fonts in registry 
foreach ($file in $fontFiles) {
    $fontName = $file.BaseName
    $fontFile = $file.Name
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
                     -Name "$fontName (TrueType)" `
                     -Value $fontFile
}

Write-Host "✅ Fonts $($Fonts.name) installed successfully!" -ForegroundColor Green
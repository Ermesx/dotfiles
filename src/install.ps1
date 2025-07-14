param (
    [switch]$ReRun
)

$ErrorActionPreference = "Stop"

# Default paths
$commonPath = "$PSScriptRoot\common"
$windowsPath = "$PSScriptRoot\windows"

# Load defaults configuration
$defaults = Get-Content "$commonPath\defaults.json" | ConvertFrom-Json

if (-not $ReRun){
    Clear-Host
    Write-Output "⚙️ Installing dotfiles on Windows..."

    # Install or upgrade Dotfiles-Toolkit if not already installed
    & "$windowsPath\powershell\install-dotflies-toolkit.ps1"
    
    # Trust the PSGallery repository
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

    # Install or upgrade winget client if not already installed
    & "$windowsPath\powershell\install-winget-client.ps1"

    # Install or upgrade PowerShell if not already installed
    & "$windowsPath\powershell\install-powershell.ps1"
}

# Check if the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Output "🚀 Running install script with PowerShell 7"
    pwsh -File $PSScriptRoot\install.ps1 -ReRun
    exit 0;
}

Write-Output "🔧 Keep going the installation script..."

Import-Module Dotfiles-Toolkit

# Install or upgrade oh-my-posh
& "$windowsPath\powershell\install-oh-my-posh.ps1" -FontName $defaults.fonts.name

# Install or upgrade Windows Terminal
& "$windowsPath\terminal\install-terminal.ps1"

# Install or upgrade Pester
& "$windowsPath\powershell\install-pester.ps1"



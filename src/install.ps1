param (
    [switch]$ReRun
)

$ErrorActionPreference = "Stop"

# Default paths
$commonPath = "$PSScriptRoot\common"
$windowsPath = "$PSScriptRoot\windows"

# Load defaults configuration
$defaults = Get-Content "$commonPath\defaults.json" | ConvertFrom-Json

#region Perpare Powershell environment
if (-not $ReRun) {
    Clear-Host
    Write-Host "⚙️ Installing dotfiles on Windows..."

    # Install or upgrade PowerShell if not already installed and necessary tools
    & "$windowsPath\powershell\install-powershell.ps1"
}

# Check if the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "🚀 Running install script with PowerShell 7"
    pwsh -NoLogo -NoProfile -File $PSScriptRoot\install.ps1 -ReRun
    exit 0;
}
#endregion

Write-Host "🔧 Keep going the installation script..."
Import-Module Dotfiles-Toolkit                                                  

# Install Pester testing framework for PowerShell
& "$windowsPath\powershell\install-pester.ps1"

# Install oh-my-posh 
& "$windowsPath\powershell\install-oh-my-posh.ps1" -FontName $defaults.fonts.name -Theme $defaults.shell.theme

# Install Zoxide for fast directory navigation
& "$windowsPath\powershell\install-zoxide.ps1"

# Install bat for syntax highlighting and file viewing
& "$windowsPath\powershell\install-bat.ps1" -BatConfigFile "$commonPath\bat\config"

# install PSFzf for fuzzy finding
& "$windowsPath\powershell\install-fzf.ps1" -FzfConfigFile "$commonPath\fzf\.fzfrc"

# Install or upgrade Windows Terminal
& "$windowsPath\terminal\install-terminal.ps1"

# Install or upgrade git
& "$windowsPath\git\install-git.ps1"

# Install docker
& "$windowsPath\docker\install-docker.ps1"


# TODO: add wsl install and upgrade


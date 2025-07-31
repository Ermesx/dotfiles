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

# Install dependencies for PowerShell modules and tests
& "$windowsPath\powershell\install-modules-dependencies.ps1"

# Install oh-my-posh 
& "$windowsPath\powershell\install-oh-my-posh.ps1" -FontName $defaults.fonts.name -Theme $defaults.shell.theme

# install PSFzf for fuzzy finding
& "$windowsPath\powershell\install-shell-tools.ps1" -Config @{
    fzf = @{
        configPath = "$commonPath\fzf\.fzfrc"
        defaults = $defaults.shell.fzf
    }
    bat = @{ configPath = "$commonPath\bat\config" }
    rg  = @{ configPath = "$commonPath\rg\.rgrc" }
}

# Install or upgrade Windows Terminal
& "$windowsPath\terminal\install-terminal.ps1"

# Install or upgrade git
& "$windowsPath\git\install-git.ps1"

# Install docker
& "$windowsPath\docker\install-docker.ps1"

# TODO: add wsl install and upgrade

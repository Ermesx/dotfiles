$ErrorActionPreference = "Stop"

Clear-Host

#region Prepare PowerShell 7
# Check if the script is running in PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host "🌀 Installing PowerShell 7..." --NoNewline
        winget install --id Microsoft.Powershell --accept-source-agreements --accept-package-agreements --silent
        $env:PATH += ";$env:ProgramFiles\PowerShell\7"
    }
    
    Write-Host "`r🚀 Running install script with PowerShell 7"
    pwsh -NoLogo -NoProfile -File $PSScriptRoot\install.ps1
    exit 0;
}
#endregion

# Default paths
$commonPath = "$PSScriptRoot\common"
$windowsPath = "$PSScriptRoot\windows"

# Load defaults configuration
$defaults = Get-Content "$commonPath\defaults.json" | ConvertFrom-Json

# Installing... !!
Write-Host "⚙️ Installing dotfiles on Windows..."

# Upgrade PowerShell necessary tools
& "$windowsPath\powershell\install-powershell.ps1"

# Install dependencies for PowerShell modules and tests
& "$windowsPath\powershell\install-modules-dependencies.ps1"

# Install oh-my-posh 
& "$windowsPath\powershell\install-oh-my-posh.ps1" -Fonts $defaults.fonts -Theme $defaults.shell.theme

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

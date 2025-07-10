param (
    [switch]$ReRun
)

$ErrorActionPreference = "Stop"

# Default paths
$commonPath = "$PSScriptRoot\common"
$windowsPath = "$PSScriptRoot\windows"

# Read defaults configuration
$defaults = Get-Content "$commonPath\defaults.json" | ConvertFrom-Json

if (-not $ReRun) {
    Clear-Host    
    Write-Output "⚙️ Installing dotfiles on Windows..."

    # Load the Dotfiles Toolkit module
    . "$windowsPath\powershell\dotfiles-toolkit\functions\install-LocalModule.ps1"
    Install-LocalModule -SourceModulePath "$windowsPath\powershell\Dotfiles-Toolkit" 
    Import-Module Dotfiles-Toolkit -Force

    # Install newest version of PowerShell if not installed
    & "$windowsPath\powershell\install-powershell.ps1"

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Output "🚀 Running install script with PowerShell 7"
        pwsh -File $PSScriptRoot\install.ps1 -ReRun -ErrorAction Stop
        exit 0;
    }
} 

Write-Output "🔧 Keep going the installation script..."

# Install fonts
& "$windowsPath\terminal\install-fonts.ps1" -Fonts $defaults.fonts

# Install or upgrade Windows Terminal
& "$windowsPath\terminal\install-terminal.ps1"

# Install or upgrade Pester
& "$windowsPath\powershell\install-pester.ps1"



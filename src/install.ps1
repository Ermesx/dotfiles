param (
    [switch]$ReRun
)

$ErrorActionPreference = "Stop"

if (-not $ReRun) {
    Write-Output "⚙️ Installing dotfiles on Windows..."

    # Load the Dotfiles Toolkit module
    . "$PSScriptRoot\windows\powershell\dotfiles-toolkit\functions\install-LocalModule.ps1"
    Install-LocalModule -SourceModulePath "$PSScriptRoot\windows\powershell\Dotfiles-Toolkit" -Force
    Import-Module Dotfiles-Toolkit -Force

    # Install newest version of PowerShell if not installed
    & "$PSScriptRoot\windows\powershell\install-powershell.ps1"

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Output "🚀 Running install script with PowerShell 7"
        pwsh -File $PSScriptRoot\install.ps1 -ReRun -ErrorAction Stop
        exit 0;
    }
} 

Write-Output "🔧 Running the installation script..."
  

$PSVersionTable



$ErrorActionPreference = "Stop"

#region Helper Functions
function Test-PS7 {
    # Check if the current PowerShell version is greater than 7.0.0
    return $PSVersionTable.PSVersion -gt [version] "7.0.0"
}

function Install-Dotfiles-Toolkit {
    # Install or update Dotfiles-Toolkit if not already installed
    . "$PSScriptRoot\dotfiles-toolkit\minimal-import.ps1"
    
    Install-LocalModule -SourceModulePath "$PSScriptRoot\Dotfiles-Toolkit" -Force
    Import-Module Dotfiles-Toolkit -Force
}

function Install-RequiredModules {
    param ( [string[]]$modules )
    
    foreach ($module in $modules) {
        Install-OrUpdateModule -ModuleName $module
        Import-Module $module
    }
}

function Install-RequiredApps {
    param ( [PSCustomObject[]]$apps )
    
    foreach ($app in $apps) {
        Install-OrUpdateApp -AppId $app.name -Command $app.command -AdditionalEnvPath $app.env.windows.PATH
    }
}

function Add-ImportModulesToProfile {
    param ( [string[]]$modules )
    
    $importLines = $modules | ForEach-Object { "Import-Module '$_'" }
    $importScript = [ScriptBlock]::Create(($importLines -join "`n"))

    # Omit communicating simple module import in the profile
    Add-ToProfile -Comment 'Import modules' -ScriptBlock $importScript 6> $null
}

#endregion

Clear-Host

#region Establishing PowerShell 7

# Check if the script is running in PowerShell 7
if (-not (Test-PS7)) {
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        winget install --id Microsoft.Powershell --accept-source-agreements --accept-package-agreements --silent
        $env:PATH += ";$env:ProgramFiles\PowerShell\7"
    }
    
    Write-Host "`r🚀 Running install script with PowerShell 7"
    pwsh -NoLogo -NoProfile -File $PSScriptRoot\install.ps1
    exit 0;
}

#endregion

# Installing... !!
Write-Host "⚙️ Installing dotfiles on Windows..."

#region Setup scripts
Write-Host "`n=== === === === ==>" -NoNewline
Write-Cyan "     🔧 Setup...    " -NoNewline
Write-Host "<== === === === ==="

# Install or update Dotfiles-Toolkit
Install-Dotfiles-Toolkit

# Install or update required modules for installation script
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

# Install or update required by dotfiles-toolkit module
$requiredModules = @(
    'Microsoft.WinGet.Client',
    'PSMustache',
    'PSScriptAnalyzer',
    'powershell-yaml'
)
Install-RequiredModules $requiredModules

# Update winget client
Repair-WinGetPackageManager -Latest

#endregion

#region Install scripts
Write-Host "`n=== === === === ==>" -NoNewline
Write-Cyan "    🛠️ Install...   " -NoNewline
Write-Host "<== === === === ==="

$config = Get-Content "$PSScriptRoot\config.yaml" | Convertfrom-Yaml

# Install or update apps
Install-RequiredApps $config.apps

# Install or update modules
Install-RequiredModules $config.modules

#endregion

#region Post-install scripts
Write-Host "`n=== === === === ==>" -NoNewline
Write-Cyan "   🔧 Configure...  " -NoNewline
Write-Host "<== === === === ==="

# Clear the PowerShell profile to avoid duplicates
Clear-Profile
 
# Add module imports to the PowerShell profile
Add-ImportModulesToProfile @(
    @('Dotfiles-Toolkit') +
    $requiredModules +
    $config.modules
)


# Default paths
$commonPath = "$PSScriptRoot\common"
$windowsPath = "$PSScriptRoot\windows"

# Load defaults configuration
$defaults = Get-Content "$commonPath\defaults.json" | ConvertFrom-Json

# Upgrade PowerShell necessary tools
& "$windowsPath\powershell\install-powershell.ps1"

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

# TODO: add wsl install and upgrade

#endregion
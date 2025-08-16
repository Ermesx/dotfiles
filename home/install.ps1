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
    
    $modules | Install-OrUpdateModule
    $modules | Import-Module 
}

function Install-RequiredApps {
    param ( [PSCustomObject[]]$apps )

    $apps | Install-OrUpdateApp
    Update-Env
}

function Add-ImportModulesToProfile {
    param ( [string[]]$modules )
    
    $importLines = $modules | ForEach-Object { "Import-Module '$_'" }
    $importScript = [ScriptBlock]::Create(($importLines -join "`n"))

    # Omit communicating simple module import in the profile
    Add-ToProfile -Comment 'Import modules' -ScriptBlock $importScript 6> $null
}

function Add-ConfigToProfile {
    param ( [System.IO.FileInfo[]]$files )
    
    foreach ($file in $files) {
        $featureName = Split-Path $file -Parent
        Add-ToProfile -Comment "Load configuration from $featureName" -Path $file.FullName
    }
}

function Invoke-Configurations {
    Get-ChildItem -Recurse $PSScriptRoot -Filter 'configure.ps1' | ForEach-Object { & $_.FullName }
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

# Install or update Dotfiles-Toolkit
Install-Dotfiles-Toolkit

#endregion

#region Install scripts
Write-Host "`n=== === === === ==>" -NoNewline
Write-Cyan "    🛠️ Install...   " -NoNewline
Write-Host "<== === === === ==="

$packages = Get-Content "$PSScriptRoot\packages.yaml" | Convertfrom-Yaml

# Install or update apps
Install-RequiredApps $packages.apps

# Install or update modules
Install-RequiredModules $packages.modules

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
    $packages.modules
)

Invoke-Configurations

$profiles = Get-ChildItem -Recurse $PSScriptRoot -Filter 'profile.ps1'
Add-ConfigToProfile $profiles

# TODO: add wsl install and upgrade

#endregion
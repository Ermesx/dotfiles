function Install-OrUpdateModule {
<#
.SYNOPSIS
    Installs or updates a PowerShell module.

.DESCRIPTION
    This function checks if a specified PowerShell module is installed. If not, it installs the module. 
    If the module is already installed, it checks for updates and upgrades the module to the latest version if necessary.

.PARAMETER ModuleName
    The name of the PowerShell module to install or update.

.PARAMETER Force
    Forces the reinstallation of the module even if it is already installed.

.EXAMPLE
    Install-OrUpdateModule -ModuleName 'Pester'

    This command installs or updates the 'Pester' module.

.EXAMPLE
    Install-OrUpdateModule -ModuleName 'Pester' -Force

    This command forces the reinstallation of the 'Pester' module, even if it is already installed.S
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        [switch]$Force
    )
    
    # Install Module if not present
    $module = Get-Module -ListAvailable -Name $ModuleName | Sort-Object -Property Version -Descending | Select-Object -First 1
    if (-not $module -or $Force) {
        Write-Host "🌀 Installing $ModuleName..." -ForegroundColor Cyan
        Install-Module -Name $ModuleName -SkipPublisherCheck
        Write-Host "✅ $ModuleName module is installed successfully with the latest version." -ForegroundColor Green
        return
    }

    # Upgrade Module
    $availableModule = Find-module -Name $ModuleName
    $currentVersion = $module.Version
    $latestVersion = $availableModule.Version
    if ($currentVersion -lt $latestVersion) {
        Write-Host "🌀 Upgrading $ModuleName from $currentVersion to $latestVersion version..." -ForegroundColor Yellow
        Update-Module -Name $ModuleName
        Write-Host "🔄 $ModuleName module has been upgraded to version $latestVersion." -ForegroundColor Green
    }
    else {
        Write-Host "✅ $ModuleName module is already up-to-date." -ForegroundColor Yello
    }
}
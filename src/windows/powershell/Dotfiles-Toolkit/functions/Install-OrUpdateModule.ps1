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

    if (-not ($Global:ModulesCache) -or $Global:ModulesCacheTimer -lt (Get-Date)) {
        $Global:ModulesCache = Get-InstalledModule
        $Global:ModulesCacheTimer = (Get-Date).AddDays(1)
    }

    # Install Module if not present
    $module = $Global:ModulesCache | Where-Object { $_.Name -eq $ModuleName }  | Sort-Object -Property Version -Descending | Select-Object -First 1
    if (-not $module -or $Force) {
        Write-Host "🌀 Installing $ModuleName..." -ForegroundColor Cyan -NoNewline
        Install-Module -Name $ModuleName -SkipPublisherCheck
        Write-Host "`r✅ [OK] $ModuleName module is installed successfully with the latest version." -ForegroundColor Green
        return
    }

    # Check if the module is already cached
    if (-not ($Global:ModulesFindCache) -or $Global:ModuleCacheTimer -lt (Get-Date)) {
        $Global:ModuleFindCache = @()
    }
    
    if ($Global:ModuleFindCache | Where-Object { $_.Name -ne $ModuleName }) {
        $Global:ModuleFindCache.Add(@{ Name = $ModuleName; Module = Find-Module -Name $ModuleName -ErrorAction SilentlyContinue })
    }

    # Upgrade Module
    $availableModule = $Global:ModuleFindCache | Where-Object { $_.Name -eq $ModuleName } | Select-Object -ExpandProperty Module
    $currentVersion = $module.Version
    $latestVersion = $availableModule.Version
    if ($currentVersion -lt $latestVersion) {
        Write-Host "🌀 Upgrading $ModuleName from $currentVersion to $latestVersion version..." -ForegroundColor Yellow -NoNewline
        Update-Module -Name $ModuleName
        Write-Host "`r🔄 [OK] $ModuleName module has been upgraded to version $latestVersion." -ForegroundColor Green
    }
    else {
        Write-Host "👌 [Skip] $ModuleName module is already up-to-datewith version: $currentVersion." -ForegroundColor Yellow
    }
}
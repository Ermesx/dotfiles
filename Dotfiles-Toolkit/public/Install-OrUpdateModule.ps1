function Install-OrUpdateModule {
<#
.SYNOPSIS
    Installs or updates a PowerShell module.

.DESCRIPTION
    This function checks if a specified PowerShell module is installed. If not, it installs the module. 
    If the module is already installed, it checks for updates and upgrades the module to the latest version if necessary.

.PARAMETER Name
    The name of the PowerShell module to install or update.

.PARAMETER Force
    Forces the reinstallation of the module even if it is already installed.

.EXAMPLE
    Install-OrUpdateModule -Name 'Pester'

    This command installs or updates the 'Pester' module.

.EXAMPLE
    Install-OrUpdateModule -Name 'Pester' -Force

    This command forces the reinstallation of the 'Pester' module, even if it is already installed.S
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,
        [switch]$Force
    )

    if (-not ($Global:ModulesCache) -or $Global:ModulesCacheTimer -lt (Get-Date)) {
        $Global:ModulesCache = Get-InstalledModule
        $Global:ModulesCacheTimer = (Get-Date).AddDays(1)
    }

    # Install Module if not present
    $module = $Global:ModulesCache | Where-Object { $_.Name -eq $Name }  | Sort-Object -Property Version -Descending | Select-Object -First 1
    if (-not $module -or $Force) {        
        $installModule = Find-Module -Name $Name | Select-Object -First 1
        
        $script = { Install-Module -Name $Name -SkipPublisherCheck | Out-Null }.GetNewClosure()
        Write-Install -Label $Name -Version $installModule.Version -Script $script

        # Update the cache
        $Global:ModulesCache += $installModule
        return
    }

    # Check if the module is already cached
    if (-not ($Global:ModulesFindCache) -or $Global:ModulesFindCacheTimer -lt (Get-Date)) {
        $Global:ModulesFindCache = @{}
        $Global:ModulesFindCacheTimer = (Get-Date).AddDays(1)
    }

    if (-not $Global:ModulesFindCache.ContainsKey($Name)) {
        $foundModule = Find-Module -Name $Name | Select-Object -First 1
        $Global:ModulesFindCache.Add($Name, $foundModule)
    }

    # Upgrade Module
    $availableModule = $Global:ModulesFindCache[$Name]
    $currentVersion = $module.Version
    $latestVersion = $availableModule.Version
    if ($currentVersion -lt $latestVersion) {
        $script = { Update-Module -Name $Name | Out-Null }.GetNewClosure()
        Write-Upgrade -Label $Name -FromVersion $currentVersion -ToVersion $latestVersion -Script $Script
        
        # Update the cache
        $Global:ModulesCache += $availableModule
    }
    else {
        Write-Skip -Label $Name -Version $currentVersion
    }
}
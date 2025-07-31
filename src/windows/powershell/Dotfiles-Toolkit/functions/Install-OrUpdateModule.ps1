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
        Write-Pretty "🌀 Installing " -ForegroundColor '0,255,255' -FallbackForegroundColor Cyan -NoNewline
        Write-Pretty "__$($ModuleName)__" -NoNewline
        
        Install-Module -Name $ModuleName -SkipPublisherCheck | Out-Null
        $installedModule = Get-InstalledModule -Name $ModuleName | Sort-Object -Property Version -Descending  | Select-Object -First 1
        $Global:ModulesCache += $installedModule
        
        Write-Pretty "`r✅ [OK] " -ForegroundColor '0,255,0' -FallbackForegroundColor Green -NoNewline
        Write-Pretty "__$($ModuleName)__" -NoNewline
        Write-Pretty " ($($installedModule.Version))" -ForegroundColor '255,255,0' -FallbackForegroundColor Yellow -NoNewline
        Write-Host " module is installed successfully."
        return
    }

    # Check if the module is already cached
    if (-not ($Global:ModulesFindCache) -or $Global:ModulesFindCacheTimer -lt (Get-Date)) {
        $Global:ModulesFindCache = @{}
        $Global:ModulesFindCacheTimer = (Get-Date).AddDays(1)
    }

    if (-not $Global:ModulesFindCache.ContainsKey($ModuleName)) {
        $foundModule = Find-Module -Name $ModuleName | Select-Object -First 1
        $Global:ModulesFindCache.Add($ModuleName, $foundModule)
    }

    # Upgrade Module
    $availableModule = $Global:ModulesFindCache[$ModuleName]
    $currentVersion = $module.Version
    $latestVersion = $availableModule.Version
    if ($currentVersion -lt $latestVersion) {
        Write-Pretty "🌀 Upgrading " -ForegroundColor '0,255,255' -FallbackForegroundColor Cyan -NoNewline
        Write-Pretty "__$($ModuleName)__" -NoNewline
        Write-Host "($currentVersion" -ForegroundColor Cyan -NoNewline
        Write-Host " => " -NoNewline
        Write-Pretty "$latestVersion" -ForegroundColor '255,255,0' -FallbackForegroundColor Yellow -NoNewline
        Write-Host ")" -ForegroundColor Cyan -NoNewline
        
        Update-Module -Name $ModuleName
        $Global:ModulesCache += $availableModule
        
        Write-Pretty "`r🔄 [OK] " -ForegroundColor '0,255,0' -FallbackForegroundColor Green -NoNewline
        Write-Pretty "__$($ModuleName)__" -NoNewline
        Write-Host "($currentVersion" -ForegroundColor Cyan -NoNewline
        Write-Host " => " -NoNewline;
        Write-Pretty "$latestVersion" -ForegroundColor '255,255,0' -FallbackForegroundColor Yellow -NoNewline
        Write-Host ")" -ForegroundColor Cyan -NoNewline
        Write-Host " module has been upgraded successfully." 
        
    }
    else {
        Write-Pretty "👌 [Skip] " -ForegroundColor '255,255,0' -FallbackForegroundColor Yellow -NoNewline
        Write-Pretty "__$($ModuleName)__" -NoNewline
        Write-Host " ($currentVersion)" -ForegroundColor Yellow -NoNewline
        Write-Host " module is already up-to-date."
    }
}
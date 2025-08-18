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

    $t = Get-PadLength $Name

    if (-not ($Global:ModulesCache) -or $Global:ModulesCacheTimer -lt (Get-Date)) {
        $Global:ModulesCache = Get-InstalledModule
        $Global:ModulesCacheTimer = (Get-Date).AddDays(1)
    }

    # Install Module if not present
    $module = $Global:ModulesCache | Where-Object { $_.Name -eq $Name }  | Sort-Object -Property Version -Descending | Select-Object -First 1
    if (-not $module -or $Force) {
        Write-Cyan "🌀 Installing " -NoNewline
        Write-Pretty "__$($Name)__" -NoNewline
        
        Install-Module -Name $Name -SkipPublisherCheck | Out-Null
        $installedModule = Get-InstalledModule -Name $Name | Sort-Object -Property Version -Descending  | Select-Object -First 1
        $Global:ModulesCache += $installedModule
        
        Write-Green "`r✅ [OK]   " -NoNewline
        Write-Pretty "__$($Name)__$t" -NoNewline
        Write-Yellow " ($($installedModule.Version))"
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
        Write-Cyan "🌀 Upgrading " -NoNewline
        Write-Pretty "__$($Name)__$t" -NoNewline
        Write-Host "($currentVersion" -ForegroundColor Cyan -NoNewline
        Write-Red " => " -NoNewline
        Write-Yellow "$latestVersion" -NoNewline
        Write-Host ")" -ForegroundColor Cyan -NoNewline
        
        Update-Module -Name $Name
        $Global:ModulesCache += $availableModule
        
        Write-Green "`r🔄 [OK] " -NoNewline
        Write-Pretty "__$($Name)__$t" -NoNewline
        Write-Host "($currentVersion" -ForegroundColor Cyan -NoNewline
        Write-Red " => " -NoNewline;
        Write-Yellow "$latestVersion" -NoNewline
        Write-Host ")" -ForegroundColor Cyan
        
    }
    else {
        Write-Yellow "👌 [Skip] " -NoNewline
        Write-Pretty "__$($Name)__$t" -NoNewline
        Write-Host "($currentVersion)" -ForegroundColor Yellow
    }
}
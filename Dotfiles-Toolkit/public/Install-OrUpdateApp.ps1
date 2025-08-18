#Requires -Modules Microsoft.WinGet.Client
using namespace Microsoft.WinGet.Client.PSObjects

function Install-OrUpdateApp {
<#
.SYNOPSIS
    Installs or updates an application using WinGet.

.DESCRIPTION
    This function checks if an application is installed or requires an update using WinGet. 
    If the application is not installed, it installs it. If an update is available, it upgrades the application.
    Optionally, it can update the PATH environment variable if a command is specified.

.PARAMETER Id
    The ID of the application to install or update.

.PARAMETER Command
    The command to check in the PATH environment variable. If specified and the command is not found after installation, the PATH will be updated.

.PARAMETER Mode
    The installation mode (e.g., 'Silent'). Defaults to 'Silent'.

.PARAMETER AdditionalEnvPath
    Additional paths to add to the environment PATH variable.

.PARAMETER Force
    Forces the reinstallation of the application even if it is already installed.

.EXAMPLE
    Install-OrUpdateApp -Id "Microsoft.PowerShell" -Command "pwsh"

    Installs or updates PowerShell and checks if the 'pwsh' command is available in PATH.

.EXAMPLE
    Install-OrUpdateApp -Id "Git.Git" -Command "git" -AdditionalEnvPath "C:\Program Files\Git\bin"

    Installs or updates Git and adds the specified path to environment if needed.

#>    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,
        [PSPackageInstallMode]$Mode = [PSPackageInstallMode]::Silent,
        [switch]$Force
    )

    $t = Get-PadLength $Id
    
    if (-not ($Global:AppsCache) -or $Global:AppsCacheTimer -lt (Get-Date)) {
        $Global:AppsCache = Get-WinGetPackage
        $Global:AppsCacheTimer = (Get-Date).AddDays(1)
    }

    $app = $Global:AppsCache | Where-Object { $_.Id -eq $Id } | Sort-Object -Property InstalledVersion -Descending | Select-Object -First 1
    if (-not $app -or $Force) {
        Write-Cyan "🌀 Installing " -NoNewline; 
        Write-Pretty "__$($Id)__" -NoNewline
        
        Install-WinGetPackage -Id "$Id" -Mode $Mode | Out-Null        
        $installedApp = Get-WinGetPackage -Id $Id |  Select-Object -First 1
        $Global:AppsCache += $installedApp
        
        Write-Green "`r✅ [OK]   " -NoNewline; 
        Write-Pretty "__$($Id)__$t" -NoNewline;
        Write-Yellow "($($installedApp.InstalledVersion))"
    }
    elseif ($app.IsUpdateAvailable) {
        $latestVersion = $app.AvailableVersions[0]
        Write-Cyan "🌀 Upgrading " -NoNewline
        Write-Pretty "__$($Id)__$t" -NoNewline
        Write-Host "($($app.InstalledVersion)" -ForegroundColor Cyan -NoNewline
        Write-Red " => " -NoNewline
        Write-Yellow "$latestVersion" -NoNewline
        Write-Host ")" -ForegroundColor Cyan -NoNewline
        
        Update-WinGetPackage -Id "$Id" -Mode $Mode | Out-Null
        $installedApp = Get-WinGetPackage -Id $Id | Select-Object -First 1
        $Global:AppsCache += $installedApp
        
        Write-Green "`r🔄 [OK]   " -NoNewline
        Write-Pretty "__$($Id)__$t" -NoNewline
        Write-Host "($($app.InstalledVersion)" -ForegroundColor Cyan -NoNewline
        Write-Red " => " -NoNewline;
        Write-Yellow "$latestVersion" -NoNewline
        Write-Host ")" -ForegroundColor Cyan
    }
    else {
        Write-Yellow "👌 [Skip] " -NoNewline;
        Write-Pretty "__$($Id)__$t" -NoNewline
        Write-Host "($($app.InstalledVersion))" -ForegroundColor Yellow
    }
}

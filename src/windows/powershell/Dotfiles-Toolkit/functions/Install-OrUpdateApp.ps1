using namespace Microsoft.WinGet.Client.PSObjects

function Install-OrUpdateApp {
<#
.SYNOPSIS
    Installs or updates an application using WinGet.

.DESCRIPTION
    This function checks if an application is installed or requires an update using WinGet. 
    If the application is not installed, it installs it. If an update is available, it upgrades the application.
    Optionally, it can update the PATH environment variable if a command is specified.

.PARAMETER AppId
    The ID of the application to install or update.

.PARAMETER UpdateEnv
    A switch to indicate whether the PATH environment variable should be updated.

.PARAMETER Command
    The command to check in the PATH environment variable when UpdateEnv is specified.

.PARAMETER Mode
    The installation mode (e.g., 'Silent'). Defaults to 'Silent'.

.EXAMPLE
    Install-OrUpdateApp -AppId "Microsoft.PowerShell" -UpdateEnv -Command "pwsh"

#>    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppId,
        [switch]$UpdateEnv,
        [string]$Command,
        [PSPackageInstallMode]$Mode = [PSPackageInstallMode]::Silent,
        [string]$AdditionalEnvPath = "",
        [switch]$Force
    )
    
    if ($UpdateEnv -and -not $Command) {
        Write-Host "❌ Command parameter is required when UpdateEnv is specified." -ForegroundColor Red
        return
    }

    if (-not ($Global:AppsCache) -or $Global:AppsCacheTimer -lt (Get-Date)) {
        $Global:AppsCache = Get-WinGetPackage
#        $Global:InstalledAppsCache = @()
        $Global:AppsCacheTimer = (Get-Date).AddDays(1)
    }

    $app = $Global:AppsCache | Where-Object { $_.Id -eq $AppId } | Sort-Object -Property InstalledVersion -Descending | Select-Object -First 1
    if (-not $app -or $Force) {
        Write-Pretty "🌀 Installing " -ForegroundColor '0,255,0' -FallbackForegroundColor Cyan -NoNewline; 
        Write-Pretty "__$($AppId)__" -NoNewline
        
        Install-WinGetPackage -Id "$AppId" -Mode $Mode | Out-Null        
        $installedApp = Get-WinGetPackage -Id $AppId | Select-Object -First 1
        $Global:AppsCache += $installedApp
        
        Write-Pretty "`r✅ [OK] " -ForegroundColor '0,255,0' -FallbackForegroundColor Green -NoNewline; 
        Write-Pretty "__$($AppId)__" -NoNewline;
        Write-Pretty " ($($installedApp.InstalledVersion))" -ForegroundColor '255,255,0' -FallbackForegroundColor Yellow -NoNewline
        Write-Host " app is installed successfully."
    }
    elseif ($app.IsUpdateAvailable) {
        $latestVersion = $app.AvailableVersions[0]
        Write-Pretty "🌀 Upgrading " -ForegroundColor '0,255,255' -FallbackForegroundColor Cyan -NoNewline
        Write-Pretty "__$($AppId)__" -NoNewline
        Write-Host "($($app.InstalledVersion)" -ForegroundColor Cyan -NoNewline
        Write-Host " => " -NoNewline
        Write-Pretty "$latestVersion" -ForegroundColor '255,255,0' -FallbackForegroundColor Yellow -NoNewline
        Write-Host ")" -ForegroundColor Cyan -NoNewline
        
        Update-WinGetPackage -Id "$AppId" -Mode $Mode | Out-Null
        $Global:AppsCache += $app
        
        Write-Pretty "`r🔄 [OK] " -ForegroundColor '0,255,0' -FallbackForegroundColor Green -NoNewline
        Write-Pretty "__$($AppId)__" -NoNewline
        Write-Host "($($app.InstalledVersion)" -ForegroundColor Cyan -NoNewline
        Write-Host " => " -NoNewline;
        Write-Pretty "$latestVersion" -ForegroundColor '255,255,0' -FallbackForegroundColor Yellow -NoNewline
        Write-Host ")" -ForegroundColor Cyan -NoNewline
        Write-Host " app has been upgraded successfully."
    }
    else {
        Write-Pretty "👌 [Skip] " -ForegroundColor '255,255,0' -FallbackForegroundColor Yellow -NoNewline;
        Write-Pretty "__$($AppId)__" -NoNewline
        Write-Host " ($($app.InstalledVersion))" -ForegroundColor Yellow -NoNewline
        Write-Host " app is already up-to-date."
    }

    # Update the PATH environment variable to include the new installation
    if ($UpdateEnv -and -not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Update-Env -AdditionalPath $AdditionalEnvPath
    }
}


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
        [string]$AdditionalEnvPath = ""
    )
    
    if ($UpdateEnv -and -not $Command) {
        Write-Host "❌ Command parameter is required when UpdateEnv is specified." -ForegroundColor Red
        return
    }

    if (-not ($Global:AppsCache) -or $Global:AppsCacheTimer -lt (Get-Date)) {
        $Global:AppsCache = Get-WinGetPackage
        $Global:AppsCacheTimer = (Get-Date).AddDays(1)
    }

    $app = $Global:AppsCache | Where-Object { $_.Id -eq $AppId } | Select-Object -First 1
    if (-not $app) {
        Write-Host "🌀 Installing $AppId..." -ForegroundColor Cyan -NoNewline
        Install-WinGetPackage -Id "$AppId" -Mode $Mode | Out-Null
        Write-Host "`r✅ [OK] $AppId is installed successfully with the latest version." -ForegroundColor Green
    }
    elseif ($app.IsUpdateAvailable) {
        $latestVersion = $app.AvailableVersions[0]
        Write-Host "🌀 Upgrading $AppId from $($app.InstalledVersion) to $latestVersion version..." -ForegroundColor Yellow
        Update-WinGetPackage -Id "$AppId" -Mode $Mode | Out-Null
        Write-Host "`r🔄 [OK] $AppId has been upgraded to version $latestVersion." -ForegroundColor Green
    }
    else {
        Write-Host "👌 [Skip] $AppId is already up-to-date with version: $($app.InstalledVersion)." -ForegroundColor Yellow
    }

    # Update the PATH environment variable to include the new installation
    if ($UpdateEnv -and -not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Update-Env -AdditionalPath $AdditionalEnvPath
    }
}


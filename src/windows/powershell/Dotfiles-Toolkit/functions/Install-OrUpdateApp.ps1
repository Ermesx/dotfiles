function Install-OrUpdateApp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppId,
        [switch]$UpdateEnv,
        [string]$Command,
        [string]$Mode = 'Silent'
    )
    
    if ($UpdateEnv -and -not $Command) {
        Write-Host "❌ Command parameter is required when UpdateEnv is specified." -ForegroundColor Red
        return
    }

    $app = Get-WinGetPackage -Id "$AppId"
    if (-not $app) {
        Write-Host "🌀 Installing $AppId..." -ForegroundColor Cyan
        Install-WinGetPackage -Id "$AppId" -Mode $Mode
        Write-Host "✅ $AppId is installed successfully with the latest version." -ForegroundColor Green
    }
    elseif ($app.IsUpdateAvailable) {
        $latestVersion = $app.AvailableVersions[0]
        Write-Host "🌀 Upgrading $AppId from $($app.InstalledVersion) to $latestVersion version..." -ForegroundColor Yellow
        Update-WinGetPackage -Id "$AppId" -Mode $Mode
        Write-Host "🔄 $AppId has been upgraded to version $latestVersion." -ForegroundColor Green
    }
    else {
        Write-Host "✅ $AppId is already up-to-date with version: $($app.InstalledVersion)." -ForegroundColor Yellow
    }

    # Update the PATH environment variable to include the new installation
    if ($UpdateEnv -and -not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Update-Env
    }
}


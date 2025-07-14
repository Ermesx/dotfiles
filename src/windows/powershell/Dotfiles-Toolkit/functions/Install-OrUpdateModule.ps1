function Install-OrUpdateModule {
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
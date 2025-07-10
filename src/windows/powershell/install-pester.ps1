$ErrorActionPreference = "Stop"
Import-Module Dotfiles-Toolkit

# Install or upgrade Pester
$pesterModule = Get-Module -ListAvailable -Name Pester | Sort-Object -Property Version -Descending | Select-Object -First 1
if (-not ($pesterModule) -OR $pesterModule.Version.Major -lt 4) {
    Write-Host "🧪 Installing Pester module..." -ForegroundColor Cyan
    Install-Module -Name Pester -Force -SkipPublisherCheck
    Write-Host "✅ Pester module is installed successfully." -ForegroundColor Green
} else {
    Write-Host "🧪 Pester module is available, attempting to upgrade..." -ForegroundColor Cyan
    Update-Module -Name Pester
    
    $updatedPesterModule = Get-Module -ListAvailable -Name Pester | Sort-Object -Property Version -Descending | Select-Object -First 1
    if ($updatedPesterModule.Version -eq $pesterModule.Version) {
        Write-Host "✅ Pester module is already up-to-date." -ForegroundColor Yellow
        exit 1
    }
    else {
        Write-Host "🔄 Pester module has been upgraded to version $($updatedPesterModule.Version)." -ForegroundColor Green        
    }
}


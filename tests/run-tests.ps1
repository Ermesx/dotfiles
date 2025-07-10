param (
    [Parameter(Mandatory = $true)]
    [System.IO.FileInfo]$InstallScript
)

$ErrorActionPreference = "Stop"

if (-not $InstallScript.Exists) {
    Write-Host "❌  The install script '$($InstallScript.FullName)' does not exist. Please provide a valid path." -ForegroundColor Red
    Write-Host "Usage: .\run-tests.ps1 -InstallScript <path_to_install_script>" -ForegroundColor Yellow
    exit 1
}

# Execute the installation script
try {
    Write-Host "🔧 Using installation script: $($InstallScript.FullName)" -ForegroundColor Cyan
    & $InstallScript.FullName
    Write-Host "✅  Installation script executed successfully." -ForegroundColor Green
} catch {
    Write-Host "❌  An error occurred while executing the installation script: $_" -ForegroundColor Red
    exit 1
}

# Check if Pester module is available
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "🧪 Installing Pester module..." -ForegroundColor Cyan
    Install-Module -Name Pester -Force -SkipPublisherCheck
} else {
    Write-Host "🧪 Pester module is available, try update..." -ForegroundColor Cyan
    Update-Module -Name Pester
}

# Run tests after the installation script
Write-Host "🧪 Running tests..." -ForegroundColor Cyan
Invoke-Pester -Output Detailed -Path "$PSScriptRoot\windows" 
Write-Host "✅  Tests completed successfully." -ForegroundColor Green

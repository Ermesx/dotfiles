param (
    [Parameter(Mandatory = $true)]
    [System.IO.FileInfo]$InstallScript
)

$ErrorActionPreference = "Stop"

if (-not $InstallScript.Exists) {
    Write-Host "❌  The install script '$($InstallScript.FullName)' does not exist. Please provide a valid path." -ForegroundColor Red
    exit 1
}

Write-Host "🔧 Using installation script: $($InstallScript.FullName)" -ForegroundColor Cyan

# Execute the installation script
try {
    & $InstallScript.FullName
    Write-Host "✅  Installation script executed successfully." -ForegroundColor Green
} catch {
    Write-Host "❌  An error occurred while executing the installation script: $_" -ForegroundColor Red
    exit 1
}

# Run tests after the installation script
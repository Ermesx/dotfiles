# Run tests after the installation script
Write-Host "🧪 Running tests..." -ForegroundColor Cyan
$testPath = Join-Path -Path $PSScriptRoot -ChildPath "windows"
Invoke-Pester -Path $testPath -Output Detailed
Write-Host "✅ Tests completed successfully." -ForegroundColor Green
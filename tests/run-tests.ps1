$ErrorActionPreference = "Stop"

Write-Host "🔧 Apply chezmoi:" -ForegroundColor Cyan
#chezmoi apply

Write-Host "🧪 Running tests..." -ForegroundColor Cyan
& "$PSScriptRoot\execute-pester.ps1" 


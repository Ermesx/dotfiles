$ErrorActionPreference = "Stop"

Write-Host "🔧 Apply chezmoi:" -ForegroundColor Cyan
Invoke-Expression "&{$(Invoke-RestMethod 'https://get.chezmoi.io/ps1')} init --apply"

Write-Host "🧪 Running tests..." -ForegroundColor Cyan
& "$PSScriptRoot\execute-pester.ps1" 


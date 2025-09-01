param (
    [string]$BRANCH = 'develop'
)
$ErrorActionPreference = "Stop"

# Set environment variable to indicate we are in a Vagrant environment and update PATH
[System.Environment]::SetEnvironmentVariable("VAGRANT", "1", "User")
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
$env:PATH = "$userPath;$machinePath"


Write-Host "Install dotfiles:" -ForegroundColor Cyan
$script = "https://raw.githubusercontent.com/Ermesx/dotfiles/refs/heads/$BRANCH/install.ps1"
Invoke-Expression "&{$(Invoke-RestMethod $script)}"

Write-Host "🧪 Running tests..." -ForegroundColor Cyan
pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File "C:\vagrant\execute-pester.ps1" 


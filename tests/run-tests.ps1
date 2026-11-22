param (
    [string]$BRANCH = 'develop'
)
$ErrorActionPreference = "Stop"

# Set environment variable to indicate we are in a Vagrant environment
[System.Environment]::SetEnvironmentVariable("VAGRANT", "1", "User")
$env:VAGRANT = "1"

# A standard user cannot read the share in vagrant's profile: copy the working tree from the neutral share.
# The copy keeps uncommitted changes, and chezmoi init skips the clone because the folder is a git repo.
$source = Join-Path $HOME '.local\share\chezmoi'
if (-not (Test-Path $source) -and (Test-Path 'C:\dotfiles-src')) {
    New-Item -ItemType Directory -Force (Split-Path $source) | Out-Null
    Copy-Item 'C:\dotfiles-src' $source -Recurse
}

Write-Host "Install dotfiles:" -ForegroundColor Cyan
$script = "https://raw.githubusercontent.com/Ermesx/dotfiles/refs/heads/$BRANCH/install.ps1"
Invoke-Expression (Invoke-RestMethod $script | Out-String)

Write-Host "► Running tests" -ForegroundColor Cyan
pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File "C:\vagrant\execute-pester.ps1" 


param (
    [string]$BRANCH = 'develop'
)
$ErrorActionPreference = "Stop"

# Set environment variable to indicate we are in a Vagrant environment
[System.Environment]::SetEnvironmentVariable("VAGRANT", "1", "User")
$env:VAGRANT = "1"

# A standard user cannot read the share in vagrant's profile: copy the working tree from the neutral share.
# Refreshed on every run, so a rerun tests the current host state; the copy keeps uncommitted changes, and
# chezmoi init skips the clone because the folder is a git repo (-Force: Git for Windows marks .git hidden).
# Not for the vagrant account: its chezmoi folder is the live share itself.
$source = Join-Path $HOME '.local\share\chezmoi'
if ($env:USERNAME -ne 'vagrant' -and (Test-Path 'C:\dotfiles-src')) {
    if (Test-Path $source) { Remove-Item $source -Recurse -Force }
    New-Item -ItemType Directory -Force (Split-Path $source) | Out-Null
    Copy-Item 'C:\dotfiles-src' $source -Recurse -Force
}

Write-Host "Install dotfiles:" -ForegroundColor Cyan
$script = "https://raw.githubusercontent.com/Ermesx/dotfiles/refs/heads/$BRANCH/install.ps1"
Invoke-Expression (Invoke-RestMethod $script | Out-String)

Write-Host "► Running tests" -ForegroundColor Cyan
pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File "C:\vagrant\execute-pester.ps1" 


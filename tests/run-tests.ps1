# Profile selection (docs/specs/install-profiles.md), passed to chezmoi init as process-scoped environment variables:
#   -Profiles shell,sdk,ai          -> DOTFILES_PROFILES (omit it to install every profile; 'base' alone = only base)
#   -Picks @{ ai = 'claude-code' }  -> DOTFILES_PICKS_AI (a pick profile without an entry takes all its labels)
param (
    [string]$BRANCH = 'develop',
    [string[]]$Profiles,
    [hashtable]$Picks
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

# Process scope only: the selection must not leak into the VM's user environment
if ($Profiles) { $env:DOTFILES_PROFILES = $Profiles -join ',' }
foreach ($key in $Picks.Keys) { Set-Item "env:DOTFILES_PICKS_$($key.ToUpper())" (@($Picks[$key]) -join ',') }

Write-Host "Install dotfiles:" -ForegroundColor Cyan
$script = "https://raw.githubusercontent.com/Ermesx/dotfiles/refs/heads/$BRANCH/install.ps1"
Invoke-Expression (Invoke-RestMethod $script | Out-String)

# The tests run in pwsh (modules in Documents\PowerShell), but this script may run in Windows PowerShell 5.1: check and install in pwsh
pwsh -NoProfile -Command "if (-not (Get-Module -ListAvailable Pester | Where-Object Version -ge ([version]'6.0.0'))) { Install-Module Pester -MinimumVersion 6.0.0 -Scope CurrentUser -Force -SkipPublisherCheck }"

Write-Host "► Running tests" -ForegroundColor Cyan
pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File "C:\vagrant\execute-pester.ps1" 


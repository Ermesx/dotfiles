# Profile selection (docs/specs/install-profiles.md), passed to chezmoi init as process-scoped environment variables.
# Both parameters are strings, as every argument is one under `powershell -File`:
#   -Profiles shell,sdk,ai              -> DOTFILES_PROFILES ('base' alone = only base; omitted: chezmoi init prompts,
#                                          the default being every profile, or the stored selection on a re-run)
#   -Picks 'ai=claude-code;apps=rider,postman'
#                                       -> DOTFILES_PICKS_AI, DOTFILES_PICKS_APPS: profiles separated by ';', then
#                                          profile=labels with labels separated by ','. A pick profile without an
#                                          entry takes all its labels.
# DOTFILES_* variables already in the session are removed first, so a run never inherits an earlier one.
param (
    [string]$BRANCH = 'develop',
    [string]$Profiles,
    [string]$Picks
)

# 'ai=claude-code;apps=rider,postman' -> @{ DOTFILES_PICKS_AI = 'claude-code'; DOTFILES_PICKS_APPS = 'rider,postman' }
function ConvertTo-PickEnvironment([string]$Picks) {
    $environment = @{}
    foreach ($part in $Picks -split ';' | Where-Object { $_.Trim() }) {
        $name, $labels = $part -split '=', 2
        if ($null -eq $labels -or -not $name.Trim() -or -not $labels.Trim()) {
            throw "Invalid -Picks part '$($part.Trim())': expected profile=label[,label] (parts separated by ';')"
        }
        $environment["DOTFILES_PICKS_$($name.Trim().ToUpper())"] = (($labels -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ',')
    }
    $environment
}

$ErrorActionPreference = "Stop"

# Process scope only: the selection must not leak into the VM's user environment, nor a previous run's into this one
Remove-Item env:DOTFILES_PROFILES -ErrorAction Ignore
Get-ChildItem env: | Where-Object Name -like 'DOTFILES_PICKS_*' | ForEach-Object { Remove-Item "env:$($_.Name)" }
$pickEnvironment = ConvertTo-PickEnvironment $Picks
if ($Profiles) { $env:DOTFILES_PROFILES = ($Profiles -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ',' }
foreach ($name in $pickEnvironment.Keys) { Set-Item "env:$name" $pickEnvironment[$name] }

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

# The tests run in pwsh (modules in Documents\PowerShell), but this script may run in Windows PowerShell 5.1: check and install in pwsh
pwsh -NoProfile -Command "if (-not (Get-Module -ListAvailable Pester | Where-Object Version -ge ([version]'6.0.0'))) { Install-Module Pester -MinimumVersion 6.0.0 -Scope CurrentUser -Force -SkipPublisherCheck }"

Write-Host "► Running tests" -ForegroundColor Cyan
pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File "C:\vagrant\execute-pester.ps1" 


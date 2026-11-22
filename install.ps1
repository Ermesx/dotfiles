[CmdletBinding()]
param (
    [string]$GITHUB_USERNAME = 'Ermesx'
)

# Scoop and the profile need scripts to run; a Process-scope policy (e.g. -ExecutionPolicy Bypass)
# makes this report an override, which is expected
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue

if (-not (Get-Command -Name scoop -ErrorAction SilentlyContinue)) {

    # Install Scoop (it refuses to run from an elevated shell)
    Write-Host '► Installing Scoop' -ForegroundColor Cyan
    Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
}

# Required tools to install
$apps = @('git', 'chezmoi', 'pwsh')

Write-Host "► Installing $($apps -join ', ')" -ForegroundColor Cyan
scoop install @apps

# Refresh PATH without needing to restart the shell
$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
$machinePath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
$env:PATH = "$userPath;$machinePath"

# Install chezmoi and apply dotfiles. A CI runner has no TTY: chezmoi reads prompt answers from stdin there
$initArgs = @(if ($env:CI -eq 'true') { '--no-tty' })
chezmoi init --apply $GITHUB_USERNAME @initArgs

[CmdletBinding()]
param (
    [string]$GITHUB_USERNAME = 'Ermesx'
)

# Scripts must be allowed to run for Scoop and the profile
if ((Get-ExecutionPolicy -Scope CurrentUser) -notin 'RemoteSigned', 'Unrestricted', 'Bypass') {
    Write-Host '► Setting the execution policy to RemoteSigned' -ForegroundColor Cyan
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

if (-not (Get-Command -Name scoop -ErrorAction SilentlyContinue)) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        throw 'Run install.ps1 from a non-elevated shell: Scoop installs per user and refuses to run as administrator.'
    }

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

$apps | ForEach-Object {
    if (-not (Get-Command -Name $_ -ErrorAction SilentlyContinue)) {
        throw "Installing '$_' with Scoop failed, run 'scoop install $_' to see the details"
    }
}

# Apply dotfiles
chezmoi init --apply $GITHUB_USERNAME

# Runs every admin-only setup script in this folder. Run as administrator (PowerShell 7).
# Review the three scripts it runs: they sit in a user-writable folder.
$ErrorActionPreference = 'Stop'

# Dot-sourced from this script's folder: works from any current directory, and Stop applies to them directly
. "$PSScriptRoot\enable-developer-mode.ps1"
. "$PSScriptRoot\enable-ssh-agent.ps1"
. "$PSScriptRoot\enable-wsl.ps1"

Write-Host "► Next steps (as the user, not as administrator)" -ForegroundColor Yellow
Write-Host "  1. Restart the computer."
Write-Host "  2. In a new PowerShell window: Complete-UserSetup"

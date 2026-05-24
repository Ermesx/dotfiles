[CmdletBinding()]
param (
    [string]$GITHUB_USERNAME = 'Ermesx'
)

$params = @(
    '--accept-source-agreements'
    '--accept-package-agreements'
    '--disable-interactivity'
)

if (Get-Command -Name winget -ErrorAction SilentlyContinue) {

    # Self upgrade winget
    Write-Host '► Upgrading winget' -ForegroundColor Cyan
    winget upgrade winget @params| Out-Null
}
else {
    
    # Install winget
    Write-Host '► Installing winget' -ForegroundColor Cyan
    $appInstallerPath = "$env:TEMP\Microsoft.DesktopAppInstaller.msixbundle"

    Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile $appInstallerPath -UseBasicParsing
    Add-AppxPackage -Path $appInstallerPath -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Confirm:$false
}

# Required packages to install
$wingets = @('twpayne.chezmoi', 'microsoft.dsc', 'microsoft.powershell')

$wingets | Foreach-Object {
    Write-Host "► Installing $_" -ForegroundColor Cyan
    winget install $_ @params | Out-Null
}

# Refresh PATH without needing to restart the shell
$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
$machinePath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
$env:PATH = "$userPath;$machinePath"

# Install chezmoi and apply dotfiles
chezmoi init --apply $GITHUB_USERNAME
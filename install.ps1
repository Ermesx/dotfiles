[CmdletBinding()]
param (
    [string]$GITHUB_USERNAME = 'Ermesx'
)

$params = @(
    '--accept-source-agreements'
    '--accept-package-agreements'
    '--disable-interactivity'
)

# winget codes treated as success: ok, nothing to upgrade, already installed, newer installed, reboot pending
$okCodes = @(0, 0x8A15002B, 0x8A150061, 0x8A15010D, 0x8A15010E, 0x8A150109)

if (Get-Command -Name winget -ErrorAction SilentlyContinue) {

    # Self upgrade winget
    Write-Host '► Upgrading winget' -ForegroundColor Cyan
    $out = winget upgrade --id Microsoft.AppInstaller --exact @params
    if ($LASTEXITCODE -notin $okCodes) {
        Write-Warning ("winget self-upgrade failed (exit code 0x{0:X8})`n{1}" -f $LASTEXITCODE, ($out -join "`n"))
    }
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
    $out = winget install $_ @params --no-progress
    if ($LASTEXITCODE -notin $okCodes) {
        $out | Write-Host
        throw ("winget failed to install '{0}' (exit code 0x{1:X8})" -f $_, $LASTEXITCODE)
    }
}

# Refresh PATH without needing to restart the shell
$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
$machinePath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
$env:PATH = "$userPath;$machinePath"

# Install chezmoi and apply dotfiles
chezmoi init --apply $GITHUB_USERNAME